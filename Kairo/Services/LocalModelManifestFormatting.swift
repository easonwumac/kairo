import Foundation

public extension LocalModelSettingsRow {
    var manifestTransparencyText: String {
        manifest.manifestTransparencyText
    }

    var downloadApprovalText: String {
        manifest.downloadApprovalText
    }

    var licenseApprovalText: String {
        manifest.licenseApprovalText
    }

    var storagePolicyText: String {
        manifest.storagePolicyText
    }

    var purposeBoundaryText: String {
        manifest.purposeBoundaryText
    }

    var runtimeFitText: String {
        manifest.runtimeFitText
    }

    var runtimePillTexts: [String] {
        manifest.runtimePillTexts
    }
}

public extension LocalModelManifest {
    var manifestTransparencyText: String {
        [
            downloadSourceHost,
            runtime.settingsDisplayName,
            licenseName,
            "iOS \(minOSVersion)/\(minDeviceClass)+/\(formattedRAMRequirement)",
            "SHA \(sha256.prefix(7))",
            "policy \(safetyPolicyVersion)"
        ].joined(separator: " · ")
    }

    var downloadApprovalText: String {
        "User-triggered download · \(formattedDownloadSize) · \(licenseName)"
    }

    var licenseApprovalText: String {
        "License approval required · \(licenseName) · \(licenseURL.host() ?? licenseURL.absoluteString)"
    }

    var storagePolicyText: String {
        LocalModelStoragePolicy.displayText
    }

    var purposeBoundaryText: String {
        "Offline chat, drafts, summaries, and Q&A only · no tools, web, account actions, or regulated advice"
    }

    var runtimeFitText: String {
        [
            "Download: \(runtime.settingsDisplayName)",
            "Fit: \(minDeviceClass)+/\(formattedRAMRequirement)",
            mlxReferenceText
        ].joined(separator: " · ")
    }

    var runtimePillTexts: [String] {
        [
            "Download \(runtime.settingsDisplayName)",
            "\(minDeviceClass)+/\(formattedRAMRequirement)",
            mlxReferenceText
        ]
    }

    private var formattedDownloadSize: String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(fileSizeBytes)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private var downloadSourceHost: String {
        downloadURL.host() ?? "unknown"
    }

    private var formattedRAMRequirement: String {
        if minRAMGB.rounded() == minRAMGB {
            return "\(Int(minRAMGB)) GB"
        }
        return String(format: "%.1f GB", minRAMGB)
    }

    private var mlxReferenceText: String {
        let hasReferenceOnlyMLX = benchmarkProfiles.contains { profile in
            profile.runtime == .mlx && profile.isReferenceOnlyForIOS && !profile.supportsInAppDownload
        }
        return hasReferenceOnlyMLX ? "MLX ref only" : "Device test pending"
    }
}

public enum LocalModelStoragePolicy {
    public static let directoryDisplayName = "Application Support/LocalModels"
    public static let displayText = "Stored in \(directoryDisplayName) · Excluded from iCloud backup"

    public static func applyBackupExclusion(to url: URL) throws {
        try (url as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
    }
}

private extension LocalModelRuntime {
    var settingsDisplayName: String {
        switch self {
        case .gguf:
            return "GGUF"
        case .mlx:
            return "MLX"
        case .coreML:
            return "Core ML"
        case .unknown:
            return "Unknown"
        }
    }
}
