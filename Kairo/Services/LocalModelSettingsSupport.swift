import Foundation

public struct LocalModelSettings: Codable, Equatable, Sendable {
    public var selectedModelID: String?
    public var preference: ProviderRoutePreference
    public var responseLanguage: ChatResponseLanguagePreference

    public init(
        selectedModelID: String? = nil,
        preference: ProviderRoutePreference = .automatic,
        responseLanguage: ChatResponseLanguagePreference = .system
    ) {
        self.selectedModelID = selectedModelID
        self.preference = preference
        self.responseLanguage = responseLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case selectedModelID
        case preference
        case responseLanguage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModelID = try container.decodeIfPresent(String.self, forKey: .selectedModelID)
        preference = try container.decodeIfPresent(ProviderRoutePreference.self, forKey: .preference) ?? .automatic
        responseLanguage = try container.decodeIfPresent(
            ChatResponseLanguagePreference.self,
            forKey: .responseLanguage
        ) ?? .system
    }
}

public enum ChatResponseLanguagePreference: String, Codable, CaseIterable, Equatable, Sendable {
    case system
    case english
    case traditionalChinese

    public static let settingsChoices: [ChatResponseLanguagePreference] = [.system, .english, .traditionalChinese]

    public var settingsTitle: String {
        switch self {
        case .system:
            return KairoL10n.string("settings.responseLanguage.system.title")
        case .english:
            return KairoL10n.string("settings.responseLanguage.english.title")
        case .traditionalChinese:
            return KairoL10n.string("settings.responseLanguage.traditionalChinese.title")
        }
    }

    public var settingsDetailText: String {
        switch self {
        case .system:
            return KairoL10n.string("settings.responseLanguage.system.detail")
        case .english:
            return KairoL10n.string("settings.responseLanguage.english.detail")
        case .traditionalChinese:
            return KairoL10n.string("settings.responseLanguage.traditionalChinese.detail")
        }
    }

    public var promptInstruction: String {
        switch self {
        case .system:
            return "Reply using the current iOS system language: \(Self.systemLanguageDescription())."
        case .english:
            return "Reply in English."
        case .traditionalChinese:
            return "Reply in Traditional Chinese."
        }
    }

    private static func systemLanguageDescription() -> String {
        let preferredIdentifier = Locale.preferredLanguages.first
            ?? Locale.current.identifier
        let locale = Locale.current
        let localizedName = locale.localizedString(forIdentifier: preferredIdentifier)
            ?? preferredIdentifier
        return "\(localizedName) (\(preferredIdentifier))"
    }
}

public enum LocalModelDownloadPhase: String, Codable, Equatable, Sendable {
    case preparing
    case downloading
    case verifying

    public var statusPrefix: String {
        switch self {
        case .preparing:
            return KairoL10n.string("settings.models.progress.preparing")
        case .downloading:
            return KairoL10n.string("settings.models.progress.downloading")
        case .verifying:
            return KairoL10n.string("settings.models.progress.verifying")
        }
    }
}

public struct LocalModelDownloadProgressState: Equatable, Sendable {
    public let modelID: String
    public let fractionCompleted: Double
    public let phase: LocalModelDownloadPhase

    public init(modelID: String, fractionCompleted: Double) {
        let clampedFraction = min(max(fractionCompleted, 0), 1)
        self.modelID = modelID
        self.fractionCompleted = clampedFraction
        switch clampedFraction {
        case ..<0.2:
            self.phase = .preparing
        case ..<0.9:
            self.phase = .downloading
        default:
            self.phase = .verifying
        }
    }

    public var allowsCancellation: Bool {
        true
    }

    public var displayText: String {
        let percentage = Int((fractionCompleted * 100).rounded())
        return "\(phase.statusPrefix) \(percentage)%"
    }
}

public struct LocalModelSettingsStatus: Equatable, Sendable {
    public var selectedModelID: String?
    public var selectedModel: LocalModelManifest?
    public var installedRecord: LocalModelInstallRecord?
    public var preference: ProviderRoutePreference
    public var responseLanguage: ChatResponseLanguagePreference
    public var availableModels: [LocalModelManifest]
    public var installedModels: [LocalModelInstallRecord]

    public init(
        selectedModelID: String?,
        selectedModel: LocalModelManifest?,
        installedRecord: LocalModelInstallRecord?,
        preference: ProviderRoutePreference,
        responseLanguage: ChatResponseLanguagePreference = .system,
        availableModels: [LocalModelManifest],
        installedModels: [LocalModelInstallRecord]
    ) {
        self.selectedModelID = selectedModelID
        self.selectedModel = selectedModel
        self.installedRecord = installedRecord
        self.preference = preference
        self.responseLanguage = responseLanguage
        self.availableModels = availableModels
        self.installedModels = installedModels
    }

    public var localModelInstalled: Bool {
        selectedModel != nil && installedRecord?.status == .installed
    }

    public var settingsRows: [LocalModelSettingsRow] {
        let installedByID = Dictionary(uniqueKeysWithValues: installedModels.map { ($0.modelID, $0) })
        return availableModels
            .enumerated()
            .map { index, model in
                let record = installedByID[model.id]
                let isSelected = selectedModelID == model.id && record?.status == .installed
                return (index, LocalModelSettingsRow(model: model, installRecord: record, isSelected: isSelected))
            }
            .sorted { lhs, rhs in
                if lhs.1.primaryAction == rhs.1.primaryAction {
                    return lhs.0 < rhs.0
                }
                return lhs.1.primaryAction.sortPriority < rhs.1.primaryAction.sortPriority
            }
            .map(\.1)
    }
}

public enum LocalModelSettingsPrimaryAction: String, Codable, Equatable, Sendable {
    case download
    case retryDownload
    case select
    case selected
    case unavailable

    public var title: String {
        switch self {
        case .download:
            return KairoL10n.string("settings.models.action.download")
        case .retryDownload:
            return KairoL10n.string("settings.models.action.retry")
        case .select:
            return KairoL10n.string("settings.models.action.select")
        case .selected:
            return KairoL10n.string("settings.models.action.selected")
        case .unavailable:
            return KairoL10n.string("settings.models.action.unavailable")
        }
    }

    public var accessibilitySuffix: String {
        switch self {
        case .download, .retryDownload:
            return "download"
        case .select, .selected:
            return "select"
        case .unavailable:
            return "unavailable"
        }
    }

    fileprivate var sortPriority: Int {
        switch self {
        case .selected:
            return 0
        case .select:
            return 1
        case .download, .retryDownload:
            return 2
        case .unavailable:
            return 3
        }
    }
}

public struct LocalModelSettingsRow: Identifiable, Equatable, Sendable {
    public var id: String { modelID }
    public var modelID: String
    public var displayName: String
    public var detailText: String
    public var benchmarkSummaryText: String?
    public var statusText: String
    public var primaryAction: LocalModelSettingsPrimaryAction
    public var manifest: LocalModelManifest
    public var installRecord: LocalModelInstallRecord?
    public var canDelete: Bool { installRecord != nil }

    public init(model: LocalModelManifest, installRecord: LocalModelInstallRecord?, isSelected: Bool) {
        self.modelID = model.id
        self.displayName = model.displayName
        self.detailText = model.settingsDetailText
        self.benchmarkSummaryText = model.benchmarkSummaryText
        self.manifest = model
        self.installRecord = installRecord

        if isSelected {
            self.statusText = KairoL10n.string("settings.models.status.selected")
            self.primaryAction = .selected
        } else if let installRecord {
            switch installRecord.status {
            case .installed:
                self.statusText = KairoL10n.string("settings.models.status.installed")
                self.primaryAction = .select
            case .downloading:
                self.statusText = KairoL10n.string("settings.models.status.downloading")
                self.primaryAction = .unavailable
            case .failed:
                self.statusText = KairoL10n.string("settings.models.status.failed")
                self.primaryAction = .retryDownload
            }
        } else {
            self.statusText = KairoL10n.string("settings.models.status.downloadable")
            self.primaryAction = .download
        }
    }
}

public extension LocalModelManifest {
    var settingsDetailText: String {
        [
            parameterCount,
            quantization,
            "\(Self.formattedBytes(fileSizeBytes))",
            "\(contextWindow / 1000)K ctx"
        ].joined(separator: " · ")
    }

    var recommendedBenchmarkProfile: LocalModelBenchmarkProfile? {
        benchmarkProfiles.max { lhs, rhs in
            if lhs.generationTokensPerSecond == rhs.generationTokensPerSecond {
                return lhs.promptTokensPerSecond < rhs.promptTokensPerSecond
            }
            return lhs.generationTokensPerSecond < rhs.generationTokensPerSecond
        }
    }

    var benchmarkSummaryText: String? {
        guard let benchmark = recommendedBenchmarkProfile else {
            return nil
        }

        let runtimeLabel: String
        switch benchmark.runtime {
        case .mlx:
            runtimeLabel = "MLX"
        case .gguf:
            runtimeLabel = "GGUF"
        case .coreML:
            runtimeLabel = "Core ML"
        case .unknown:
            runtimeLabel = benchmark.runtimePackage
        }

        var parts = [
            "\(runtimeLabel) ref \(Self.formattedRate(benchmark.generationTokensPerSecond)) gen tok/s",
            "\(Self.formattedRate(benchmark.promptTokensPerSecond)) prompt tok/s",
            benchmark.testPlatform
        ]
        if let peakMemoryMB = benchmark.peakMemoryMB {
            parts.append("\(Self.formattedMemoryMB(peakMemoryMB)) peak")
        }
        if benchmark.isReferenceOnlyForIOS {
            parts.append("iPhone not verified")
        }
        return parts.joined(separator: " · ")
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
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

    private static func formattedRate(_ rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))"
        }
        return String(format: "%.1f", rate)
    }

    private static func formattedMemoryMB(_ memoryMB: Int) -> String {
        if memoryMB >= 1024 {
            return String(format: "%.2f GB", Double(memoryMB) / 1024.0)
        }
        return "\(memoryMB) MB"
    }
}

public enum LocalModelSelectionError: Error, Equatable {
    case modelUnavailable(String)
    case modelNotInstalled(String)
}

public actor FileBackedLocalModelSettingsStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var currentSettings: LocalModelSettings = LocalModelSettings()

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try await loadFromDisk()
    }

    public func settings() -> LocalModelSettings {
        currentSettings
    }

    public func save(_ settings: LocalModelSettings) throws {
        currentSettings = settings
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            currentSettings = LocalModelSettings()
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            currentSettings = LocalModelSettings()
            return
        }

        currentSettings = try decoder.decode(LocalModelSettings.self, from: data)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(currentSettings)
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public actor LocalModelSettingsService {
    private var catalog: LocalModelCatalog
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let settingsStore: FileBackedLocalModelSettingsStore

    public init(
        catalog: LocalModelCatalog,
        installRegistry: FileBackedLocalModelInstallRegistry,
        settingsStore: FileBackedLocalModelSettingsStore
    ) {
        self.catalog = catalog
        self.installRegistry = installRegistry
        self.settingsStore = settingsStore
    }

    public func replaceCatalog(_ catalog: LocalModelCatalog) {
        self.catalog = catalog
    }

    public func status(minimumSafetyPolicyVersion: String = "2026.1") async -> LocalModelSettingsStatus {
        let settings = await settingsStore.settings()
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        let availableIDs = Set(availableModels.map(\.id))
        let installedModels = await installRegistry.installedRecords()
            .filter { availableIDs.contains($0.modelID) }
        let selectedModel = settings.selectedModelID.flatMap { selectedID in
            availableModels.first { $0.id == selectedID }
        }
        let installedRecord = settings.selectedModelID.flatMap { selectedID in
            installedModels.first { $0.modelID == selectedID }
        }

        return LocalModelSettingsStatus(
            selectedModelID: settings.selectedModelID,
            selectedModel: selectedModel,
            installedRecord: installedRecord,
            preference: settings.preference,
            responseLanguage: settings.responseLanguage,
            availableModels: availableModels,
            installedModels: installedModels
        )
    }

    public func selectModel(id: String, minimumSafetyPolicyVersion: String = "2026.1") async throws {
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        guard availableModels.contains(where: { $0.id == id }) else {
            throw LocalModelSelectionError.modelUnavailable(id)
        }
        guard await installRegistry.record(for: id)?.status == .installed else {
            throw LocalModelSelectionError.modelNotInstalled(id)
        }

        var settings = await settingsStore.settings()
        settings.selectedModelID = id
        try await settingsStore.save(settings)
    }

    public func clearSelectedModel() async throws {
        var settings = await settingsStore.settings()
        settings.selectedModelID = nil
        try await settingsStore.save(settings)
    }

    public func setPreference(_ preference: ProviderRoutePreference) async throws {
        var settings = await settingsStore.settings()
        settings.preference = preference
        try await settingsStore.save(settings)
    }

    public func setResponseLanguage(_ responseLanguage: ChatResponseLanguagePreference) async throws {
        var settings = await settingsStore.settings()
        settings.responseLanguage = responseLanguage
        try await settingsStore.save(settings)
    }

    @discardableResult
    public func cleanupStaleDownloadingRecords() async throws -> [String] {
        try await installRegistry.cleanupStaleDownloadingRecords()
    }

    public func deleteModel(id: String) async throws {
        let record = await installRegistry.record(for: id)
        if let record, FileManager.default.fileExists(atPath: record.fileURL.path) {
            try FileManager.default.removeItem(at: record.fileURL)
        }

        try await installRegistry.delete(modelID: id)

        var settings = await settingsStore.settings()
        if settings.selectedModelID == id {
            settings.selectedModelID = nil
            try await settingsStore.save(settings)
        }
    }

    public func routingContext(
        taskClass: ProviderTaskClass = .simpleQuestionAnswer,
        networkAvailable: Bool = true,
        privacyModeEnabled: Bool = false,
        offlineModeEnabled: Bool = false,
        requiresToolUse: Bool = false,
        requiresCurrentInfo: Bool = false,
        contextTokenEstimate: Int = 0,
        localRuntimeAvailable: Bool = false,
        minimumSafetyPolicyVersion: String = "2026.1"
    ) async -> ProviderRoutingContext {
        let modelStatus = await status(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        return ProviderRoutingContext(
            preference: modelStatus.preference,
            networkAvailable: networkAvailable,
            privacyModeEnabled: privacyModeEnabled,
            offlineModeEnabled: offlineModeEnabled,
            taskClass: taskClass,
            requiresToolUse: requiresToolUse,
            requiresCurrentInfo: requiresCurrentInfo,
            contextTokenEstimate: contextTokenEstimate,
            localModelInstalled: modelStatus.localModelInstalled,
            localRuntimeAvailable: localRuntimeAvailable,
            localContextWindow: modelStatus.selectedModel?.contextWindow ?? 2048
        )
    }
}
