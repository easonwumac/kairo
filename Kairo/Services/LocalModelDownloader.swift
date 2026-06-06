import Foundation
import CryptoKit

public enum LocalModelDownloadError: Error, Equatable {
    case checksumMismatch(expected: String, actual: String)
    case unsupportedManifest(String)
    case downloadUnavailable
    case cancelled
}

public protocol LocalModelDownloader: Sendable {
    func download(_ manifest: LocalModelManifest, progress: (@Sendable (Double) -> Void)?) async throws -> URL
}

public actor VerifiedLocalModelDownloader: LocalModelDownloader {
    private let httpClient: any HTTPClient
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let modelsDirectory: URL

    public init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        installRegistry: FileBackedLocalModelInstallRegistry,
        modelsDirectory: URL
    ) {
        self.httpClient = httpClient
        self.installRegistry = installRegistry
        self.modelsDirectory = modelsDirectory
    }

    public func download(_ manifest: LocalModelManifest, progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        try validate(manifest)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try LocalModelStoragePolicy.applyBackupExclusion(to: modelsDirectory)
        let destinationURL = installedModelURL(for: manifest)
        let temporaryURL = destinationURL.appendingPathExtension("download")

        progress?(0.05)
        try await installRegistry.upsert(LocalModelInstallRecord(
            modelID: manifest.id,
            version: manifest.version,
            status: .downloading,
            fileURL: destinationURL,
            installedSizeBytes: 0,
            sha256: manifest.sha256
        ))

        do {
            let request = URLRequest(url: manifest.downloadURL)
            progress?(0.55)
            let (data, response) = try await httpClient.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? ""
                throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
            }

            progress?(0.9)
            let actualChecksum = try installDownloadedArtifact(
                data,
                expectedSHA256: manifest.sha256,
                destinationURL: destinationURL
            )

            var installedSizeBytes = Int64(data.count)
            for artifact in manifest.companionArtifacts {
                let artifactRequest = URLRequest(url: artifact.downloadURL)
                let (artifactData, artifactResponse) = try await httpClient.data(for: artifactRequest)
                guard (200..<300).contains(artifactResponse.statusCode) else {
                    let bodyPreview = String(data: artifactData.prefix(300), encoding: .utf8) ?? ""
                    throw HTTPClientError.unacceptableStatusCode(artifactResponse.statusCode, bodyPreview)
                }
                _ = try installDownloadedArtifact(
                    artifactData,
                    expectedSHA256: artifact.sha256,
                    destinationURL: installedCompanionURL(for: manifest, artifact: artifact)
                )
                installedSizeBytes += Int64(artifactData.count)
            }

            let record = LocalModelInstallRecord(
                modelID: manifest.id,
                version: manifest.version,
                status: .installed,
                fileURL: destinationURL,
                installedSizeBytes: installedSizeBytes,
                sha256: actualChecksum,
                lastVerifiedAt: Date()
            )
            try await installRegistry.upsert(record)
            progress?(1.0)
            return destinationURL
        } catch is CancellationError {
            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            removeInstalledCompanions(for: manifest)
            try await installRegistry.delete(modelID: manifest.id)
            throw LocalModelDownloadError.cancelled
        } catch {
            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            removeInstalledCompanions(for: manifest)
            try await installRegistry.upsert(LocalModelInstallRecord(
                modelID: manifest.id,
                version: manifest.version,
                status: .failed,
                fileURL: destinationURL,
                installedSizeBytes: 0,
                sha256: failedChecksum(for: error, fallback: manifest.sha256),
                failureReason: failureReason(for: error)
            ))
            throw error
        }
    }

    private func validate(_ manifest: LocalModelManifest) throws {
        guard ["https", "file"].contains(manifest.downloadURL.scheme?.lowercased()) else {
            throw LocalModelDownloadError.unsupportedManifest("Local model downloads require HTTPS or file URLs.")
        }
        guard !manifest.sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalModelDownloadError.unsupportedManifest("Local model manifest is missing sha256.")
        }
        for artifact in manifest.companionArtifacts {
            guard ["https", "file"].contains(artifact.downloadURL.scheme?.lowercased()) else {
                throw LocalModelDownloadError.unsupportedManifest("Local model companion downloads require HTTPS or file URLs.")
            }
            guard !artifact.sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LocalModelDownloadError.unsupportedManifest("Local model companion manifest is missing sha256.")
            }
        }
    }

    private func installedModelURL(for manifest: LocalModelManifest) -> URL {
        let fileExtension = manifest.downloadURL.pathExtension.isEmpty ? "model" : manifest.downloadURL.pathExtension
        let fileName = "\(Self.sanitizedFileComponent(manifest.id))-\(Self.sanitizedFileComponent(manifest.version)).\(fileExtension)"
        return modelsDirectory.appendingPathComponent(fileName)
    }

    private func installedCompanionURL(
        for manifest: LocalModelManifest,
        artifact: LocalModelCompanionArtifact
    ) -> URL {
        let fileExtension = artifact.downloadURL.pathExtension.isEmpty ? "model" : artifact.downloadURL.pathExtension
        let fileName = [
            Self.sanitizedFileComponent(manifest.id),
            Self.sanitizedFileComponent(manifest.version),
            Self.sanitizedFileComponent(artifact.id)
        ].joined(separator: "-") + ".\(fileExtension)"
        return modelsDirectory.appendingPathComponent(fileName)
    }

    private func installDownloadedArtifact(
        _ data: Data,
        expectedSHA256: String,
        destinationURL: URL
    ) throws -> String {
        let actualChecksum = Self.sha256Hex(data)
        guard actualChecksum == expectedSHA256.lowercased() else {
            throw LocalModelDownloadError.checksumMismatch(expected: expectedSHA256, actual: actualChecksum)
        }

        let temporaryURL = destinationURL.appendingPathExtension("download")
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try FileManager.default.removeItem(at: temporaryURL)
        }
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        try LocalModelStoragePolicy.applyBackupExclusion(to: destinationURL)
        return actualChecksum
    }

    private func removeInstalledCompanions(for manifest: LocalModelManifest) {
        for artifact in manifest.companionArtifacts {
            let companionURL = installedCompanionURL(for: manifest, artifact: artifact)
            if FileManager.default.fileExists(atPath: companionURL.path) {
                try? FileManager.default.removeItem(at: companionURL)
            }
            let partialURL = companionURL.appendingPathExtension("download")
            if FileManager.default.fileExists(atPath: partialURL.path) {
                try? FileManager.default.removeItem(at: partialURL)
            }
        }
    }

    private func failedChecksum(for error: Error, fallback: String) -> String {
        if case let LocalModelDownloadError.checksumMismatch(_, actual) = error {
            return actual
        }
        return fallback
    }

    private func failureReason(for error: Error) -> String {
        switch error {
        case let LocalModelDownloadError.checksumMismatch(expected, actual):
            return KairoL10n.string("settings.models.download.failure.checksumMismatch", expected, actual)
        case LocalModelDownloadError.cancelled:
            return KairoL10n.string("settings.models.download.failure.cancelled")
        case let HTTPClientError.unacceptableStatusCode(statusCode, _):
            return KairoL10n.string("settings.models.download.failure.httpStatus", statusCode)
        default:
            return String(describing: error)
        }
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return sanitized.isEmpty ? "model" : sanitized
    }
}
