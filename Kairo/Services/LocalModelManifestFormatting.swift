import Foundation

public extension LocalModelSettingsRow {
    var manifestTransparencyText: String {
        manifest.manifestTransparencyText
    }
}

public extension LocalModelManifest {
    var manifestTransparencyText: String {
        [
            "Source: \(downloadSourceHost)",
            "Runtime: \(runtime.settingsDisplayName)",
            "License: \(licenseName)",
            "Requires: iOS \(minOSVersion), \(minDeviceClass)+, \(formattedRAMRequirement)",
            "SHA-256: \(sha256.prefix(7))...",
            "Safety: \(safetyPolicyVersion)"
        ].joined(separator: " · ")
    }

    private var downloadSourceHost: String {
        downloadURL.host() ?? "unknown"
    }

    private var formattedRAMRequirement: String {
        if minRAMGB.rounded() == minRAMGB {
            return "\(Int(minRAMGB)) GB RAM"
        }
        return String(format: "%.1f GB RAM", minRAMGB)
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
