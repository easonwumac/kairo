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

public protocol LocalModelArtifactDownloadClient: Sendable {
    func downloadArtifact(from url: URL, progress: (@Sendable (Double) -> Void)?) async throws -> URL
}

public actor VerifiedLocalModelDownloader: LocalModelDownloader {
    private let httpClient: any HTTPClient
    private let artifactDownloadClient: (any LocalModelArtifactDownloadClient)?
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let modelsDirectory: URL

    public init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        artifactDownloadClient: (any LocalModelArtifactDownloadClient)? = nil,
        installRegistry: FileBackedLocalModelInstallRegistry,
        modelsDirectory: URL
    ) {
        self.httpClient = httpClient
        self.artifactDownloadClient = artifactDownloadClient
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
            let primaryArtifact = try await downloadAndInstallArtifact(
                from: manifest.downloadURL,
                expectedSHA256: manifest.sha256,
                destinationURL: destinationURL,
                progress: progress
            )

            var installedSizeBytes = primaryArtifact.sizeBytes
            for artifact in manifest.companionArtifacts {
                let companionArtifact = try await downloadAndInstallArtifact(
                    from: artifact.downloadURL,
                    expectedSHA256: artifact.sha256,
                    destinationURL: installedCompanionURL(for: manifest, artifact: artifact),
                    progress: nil
                )
                installedSizeBytes += companionArtifact.sizeBytes
            }

            let record = LocalModelInstallRecord(
                modelID: manifest.id,
                version: manifest.version,
                status: .installed,
                fileURL: destinationURL,
                installedSizeBytes: installedSizeBytes,
                sha256: primaryArtifact.sha256,
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

    private func downloadAndInstallArtifact(
        from url: URL,
        expectedSHA256: String,
        destinationURL: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> InstalledArtifact {
        if let artifactDownloadClient, !url.isFileURL {
            let downloadedFileURL = try await artifactDownloadClient.downloadArtifact(from: url) { fractionCompleted in
                progress?(0.10 + (max(0, min(1, fractionCompleted)) * 0.78))
            }
            progress?(0.9)
            return try installDownloadedArtifact(
                fileURL: downloadedFileURL,
                expectedSHA256: expectedSHA256,
                destinationURL: destinationURL
            )
        }

        let request = URLRequest(url: url)
        progress?(0.55)
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
        }

        progress?(0.9)
        return try installDownloadedArtifact(
            data,
            expectedSHA256: expectedSHA256,
            destinationURL: destinationURL
        )
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
    ) throws -> InstalledArtifact {
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
        return InstalledArtifact(sha256: actualChecksum, sizeBytes: Int64(data.count))
    }

    private func installDownloadedArtifact(
        fileURL: URL,
        expectedSHA256: String,
        destinationURL: URL
    ) throws -> InstalledArtifact {
        let actualChecksum = try Self.sha256Hex(fileURL: fileURL)
        guard actualChecksum == expectedSHA256.lowercased() else {
            try? FileManager.default.removeItem(at: fileURL)
            throw LocalModelDownloadError.checksumMismatch(expected: expectedSHA256, actual: actualChecksum)
        }

        let temporaryURL = destinationURL.appendingPathExtension("download")
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            try FileManager.default.removeItem(at: temporaryURL)
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: fileURL, to: temporaryURL)
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        try LocalModelStoragePolicy.applyBackupExclusion(to: destinationURL)
        let size = try destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return InstalledArtifact(sha256: actualChecksum, sizeBytes: Int64(size))
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

    public static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            guard !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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

public final class URLSessionLocalModelArtifactDownloader: NSObject, LocalModelArtifactDownloadClient, URLSessionDownloadDelegate, @unchecked Sendable {
    public static let defaultBackgroundIdentifier = "com.easonwumac.kairo.local-model-downloads"

    private final class DownloadState {
        let continuation: CheckedContinuation<URL, Error>
        let progress: (@Sendable (Double) -> Void)?
        var result: Result<URL, Error>?

        init(
            continuation: CheckedContinuation<URL, Error>,
            progress: (@Sendable (Double) -> Void)?
        ) {
            self.continuation = continuation
            self.progress = progress
        }
    }

    private final class TaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDownloadTask?

        func set(_ task: URLSessionDownloadTask) {
            lock.withLock { self.task = task }
        }

        func cancel() {
            lock.withLock { task?.cancel() }
        }
    }

    private static let completionHandlerLock = NSLock()
    private static var completionHandlers: [String: () -> Void] = [:]

    private let tempDirectory: URL
    private let lock = NSLock()
    private var states: [Int: DownloadState] = [:]
    private var session: URLSession!

    public init(
        configuration: URLSessionConfiguration,
        tempDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.tempDirectory = tempDirectory
        super.init()
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    public static func background(
        identifier: String = defaultBackgroundIdentifier,
        tempDirectory: URL = FileManager.default.temporaryDirectory
    ) -> URLSessionLocalModelArtifactDownloader {
        URLSessionLocalModelArtifactDownloader(
            configuration: backgroundConfiguration(identifier: identifier),
            tempDirectory: tempDirectory
        )
    }

    public static func backgroundConfiguration(identifier: String = defaultBackgroundIdentifier) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.waitsForConnectivity = true
        return configuration
    }

    public static func setBackgroundEventsCompletionHandler(
        _ completionHandler: @escaping () -> Void,
        for identifier: String
    ) {
        completionHandlerLock.withLock {
            completionHandlers[identifier] = completionHandler
        }
    }

    public func downloadArtifact(
        from url: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let taskBox = TaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.downloadTask(with: url)
                lock.withLock {
                    states[task.taskIdentifier] = DownloadState(
                        continuation: continuation,
                        progress: progress
                    )
                }
                taskBox.set(task)
                task.resume()
            }
        } onCancel: {
            taskBox.cancel()
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fractionCompleted = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let progress = lock.withLock { states[downloadTask.taskIdentifier]?.progress }
        progress?(fractionCompleted)
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let result: Result<URL, Error>
        do {
            if let response = downloadTask.response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                let bodyPreviewData = (try? Data(contentsOf: location).prefix(300)) ?? Data()
                let bodyPreview = String(data: bodyPreviewData, encoding: .utf8) ?? ""
                throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
            }

            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            let temporaryURL = tempDirectory.appendingPathComponent(
                "kairo-model-\(UUID().uuidString).download",
                isDirectory: false
            )
            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try FileManager.default.removeItem(at: temporaryURL)
            }
            try FileManager.default.moveItem(at: location, to: temporaryURL)
            result = .success(temporaryURL)
        } catch {
            result = .failure(error)
        }

        lock.withLock {
            states[downloadTask.taskIdentifier]?.result = result
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let state = lock.withLock { states.removeValue(forKey: task.taskIdentifier) }
        guard let state else { return }

        if let error {
            state.continuation.resume(throwing: error)
            return
        }

        switch state.result {
        case let .success(fileURL):
            state.continuation.resume(returning: fileURL)
        case let .failure(error):
            state.continuation.resume(throwing: error)
        case nil:
            state.continuation.resume(throwing: LocalModelDownloadError.downloadUnavailable)
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }
        let completionHandler = Self.completionHandlerLock.withLock {
            Self.completionHandlers.removeValue(forKey: identifier)
        }
        completionHandler?()
    }
}

private struct InstalledArtifact: Sendable {
    var sha256: String
    var sizeBytes: Int64
}
