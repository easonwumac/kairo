import Foundation

public extension LocalModelSettingsRow {
    var manifestTransparencyText: String {
        manifest.manifestTransparencyText
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
