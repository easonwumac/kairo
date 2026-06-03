import Foundation

public extension LocalModelSettingsRow {
    var manifestTransparencyText: String {
        manifest.manifestTransparencyText
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

    private var downloadSourceHost: String {
        downloadURL.host() ?? "unknown"
    }

    private var formattedRAMRequirement: String {
        if minRAMGB.rounded() == minRAMGB {
            return "\(Int(minRAMGB)) GB"
        }
        return String(format: "%.1f GB", minRAMGB)
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
