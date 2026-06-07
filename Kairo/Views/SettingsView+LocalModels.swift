#if canImport(SwiftUI)
import SwiftUI

extension SettingsView {
    func setLocalModelPreference(_ preference: ProviderRoutePreference) {
        localModelStatus.preference = preference

        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.setPreference(preference)
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.preferenceSaved", preference.settingsTitle)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatus.preference = .automatic
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.preferenceFailed", error.localizedDescription)
                }
            }
        }
    }

    func setResponseLanguage(_ responseLanguage: ChatResponseLanguagePreference) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.setResponseLanguage(responseLanguage)
                await MainActor.run {
                    localModelStatus.responseLanguage = responseLanguage
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string(
                        "settings.responseLanguage.message.saved",
                        responseLanguage.settingsTitle
                    )
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string(
                        "settings.responseLanguage.message.failed",
                        error.localizedDescription
                    )
                }
            }
        }
    }

    func setLocalModelRuntimeParameters(_ parameters: LocalModelRuntimeParameters, for row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.setRuntimeParameters(
                    parameters,
                    for: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.runtimeParametersSaved", row.displayName)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.runtimeParametersFailed", error.localizedDescription)
                }
            }
        }
    }

    func setLocalModelCacheEnabled(_ isEnabled: Bool) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.setCacheEnabled(isEnabled)
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessage = KairoL10n.string("settings.models.cache.toggleFailed", error.localizedDescription)
                }
            }
        }
    }


    func downloadLocalModel(_ row: LocalModelSettingsRow) {
        guard localModelSettingsService != nil else {
            localModelStatusMessageModelID = row.modelID
            localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
            return
        }

        guard let localModelDownloader else {
            localModelStatusMessageModelID = row.modelID
            localModelStatusMessage = KairoL10n.string("settings.models.message.downloaderMissing")
            return
        }

        guard localModelDownloadProgress?.modelID != row.modelID,
              !localModelDownloadQueue.contains(where: { $0.modelID == row.modelID }) else {
            return
        }

        guard localModelDownloadTask == nil else {
            localModelDownloadQueue.append(row)
            localModelStatusMessageModelID = row.modelID
            localModelStatusMessage = nil
            return
        }

        startLocalModelDownload(row, downloader: localModelDownloader)
    }

    private func startLocalModelDownload(_ row: LocalModelSettingsRow, downloader localModelDownloader: any LocalModelDownloader) {
        let task = Task {
            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.downloading", row.displayName)
                    localModelDownloadProgress = LocalModelDownloadProgressState(modelID: row.modelID, fractionCompleted: 0.05)
                }
                _ = try await localModelDownloader.download(row.manifest) { fractionCompleted in
                    Task { @MainActor in
                        localModelDownloadProgress = LocalModelDownloadProgressState(
                            modelID: row.modelID,
                            fractionCompleted: fractionCompleted
                        )
                    }
                }
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloaded", row.displayName)) }
                await reloadLocalModelStatus()
                await MainActor.run { startNextQueuedLocalModelDownloadIfNeeded() }
            } catch LocalModelDownloadError.cancelled {
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloadCancelled", row.displayName)) }
                await reloadLocalModelStatus()
                await MainActor.run { startNextQueuedLocalModelDownloadIfNeeded() }
            } catch {
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloadFailed", error.localizedDescription)) }
                await reloadLocalModelStatus()
                await MainActor.run { startNextQueuedLocalModelDownloadIfNeeded() }
            }
        }
        localModelDownloadTask = task
    }

    func cancelLocalModelDownload(_ row: LocalModelSettingsRow) {
        localModelDownloadTask?.cancel()
        localModelStatusMessageModelID = row.modelID
        localModelStatusMessage = KairoL10n.string("settings.models.message.cancellingDownload", row.displayName)
    }

    func finishLocalModelDownload(_ row: LocalModelSettingsRow, message: String) {
        localModelStatusMessageModelID = row.modelID
        localModelDownloadProgress = nil
        localModelDownloadTask = nil
        localModelStatusMessage = message
    }

    private func startNextQueuedLocalModelDownloadIfNeeded() {
        guard localModelDownloadTask == nil,
              let localModelDownloader,
              !localModelDownloadQueue.isEmpty else {
            return
        }
        let next = localModelDownloadQueue.removeFirst()
        startLocalModelDownload(next, downloader: localModelDownloader)
    }

    func selectLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.selectModel(
                    id: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.selected", row.displayName)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.selectFailed", error.localizedDescription)
                }
            }
        }
    }

    func addCustomHuggingFaceLocalModel(_ input: String) {
        guard let localModelCatalogService else {
            localModelStatusMessageModelID = nil
            localModelStatusMessage = KairoL10n.string("settings.models.message.catalogResolverMissing")
            return
        }
        guard localModelSettingsService != nil else {
            localModelStatusMessageModelID = nil
            localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
            return
        }
        guard localModelDownloader != nil else {
            localModelStatusMessageModelID = nil
            localModelStatusMessage = KairoL10n.string("settings.models.message.downloaderMissing")
            return
        }

        Task {
            do {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.customResolving")
                }
                let manifest = try await localModelCatalogService.resolveHuggingFaceModel(from: input)
                let updatedCatalog = localModelCatalog.upserting(manifest)
                if let localModelSettingsService {
                    await localModelSettingsService.replaceCatalog(updatedCatalog)
                }
                if let localModelBenchmarkService {
                    await localModelBenchmarkService.replaceCatalog(updatedCatalog)
                }
                if let localModelReplyCheckService {
                    await localModelReplyCheckService.replaceCatalog(updatedCatalog)
                }
                await MainActor.run {
                    localModelCatalog = updatedCatalog
                    localModelStatusMessageModelID = manifest.id
                    localModelStatusMessage = KairoL10n.string("settings.models.message.customResolved", manifest.displayName)
                }
                await reloadLocalModelStatus()
                let row = LocalModelSettingsRow(
                    model: manifest,
                    installRecord: nil,
                    isSelected: false
                )
                await MainActor.run {
                    downloadLocalModel(row)
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.customFailed", error.localizedDescription)
                }
                await reloadLocalModelStatus()
            }
        }
    }

    func runLocalModelBenchmark(_ row: LocalModelSettingsRow, contextSize: Int = LocalModelBenchmarkRunInfo.defaultContextSize) {
        Task {
            let outputTokenTarget = row.runtimeParameters.maxOutputTokens
            guard let localModelBenchmarkService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkServiceMissing")
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelBenchmarkRunInfo = LocalModelBenchmarkRunInfo(
                        modelID: row.modelID,
                        contextSize: contextSize,
                        outputTokenTarget: outputTokenTarget,
                        state: .running,
                        summary: nil
                    )
                    localModelStatusMessage = nil
                }
                let result = try await localModelBenchmarkService.runBenchmark(
                    modelID: row.modelID,
                    generatedTokenTarget: outputTokenTarget,
                    contextSize: contextSize,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelBenchmarkRunInfo = LocalModelBenchmarkRunInfo(
                        modelID: row.modelID,
                        contextSize: contextSize,
                        outputTokenTarget: outputTokenTarget,
                        state: .finished,
                        summary: result.summaryText
                    )
                    localModelStatusMessage = nil
                }
            } catch let error as LocalModelBenchmarkError {
                let summary: String
                switch error {
                case .modelNotInstalled:
                    summary = KairoL10n.string("settings.models.message.benchmarkNeedsDownload", row.displayName)
                case let .modelUnavailable(modelID):
                    summary = KairoL10n.string("settings.models.message.benchmarkModelUnavailable", modelID)
                case let .runtimeUnavailable(reason):
                    summary = KairoL10n.string("settings.models.message.benchmarkRuntimeUnavailable", reason)
                }
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelBenchmarkRunInfo = LocalModelBenchmarkRunInfo(
                        modelID: row.modelID,
                        contextSize: contextSize,
                        outputTokenTarget: outputTokenTarget,
                        state: .failed,
                        summary: summary
                    )
                    localModelStatusMessage = nil
                }
            } catch {
                let summary = KairoL10n.string("settings.models.message.benchmarkFailed", error.localizedDescription)
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelBenchmarkRunInfo = LocalModelBenchmarkRunInfo(
                        modelID: row.modelID,
                        contextSize: contextSize,
                        outputTokenTarget: outputTokenTarget,
                        state: .failed,
                        summary: summary
                    )
                    localModelStatusMessage = nil
                }
            }
        }
    }

    func runLocalModelReplyCheck(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelReplyCheckService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckServiceMissing")
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckRunning", row.displayName)
                }
                let result = try await localModelReplyCheckService.runReplyCheck(
                    modelID: row.modelID,
                    parameters: row.runtimeParameters,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckResult", row.displayName, result.summaryText)
                }
            } catch let error as LocalModelReplyCheckError {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    switch error {
                    case .modelNotInstalled:
                        localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckNeedsDownload", row.displayName)
                    case let .modelUnavailable(modelID):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckModelUnavailable", modelID)
                    case let .runtimeUnavailable(reason):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckRuntimeUnavailable", reason)
                    }
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckFailed", error.localizedDescription)
                }
            }
        }
    }

    func deleteLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.deleteModel(id: row.modelID)
                try? await localModelBenchmarkService?.deleteResults(for: row.modelID)
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.deleted", row.displayName)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.deleteFailed", error.localizedDescription)
                }
            }
        }
    }

    func refreshLocalModelCatalog() {
        Task {
            guard let localModelCatalogService else {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.usingBuiltInCatalog")
                }
                return
            }

            await MainActor.run {
                localModelStatusMessageModelID = nil
                localModelStatusMessage = KairoL10n.string("settings.models.message.refreshingCatalog")
            }
            let result = await localModelCatalogService.refreshCatalog(with: localModelCatalog)
            let refreshedCatalog = result.catalog
            if let localModelSettingsService {
                await localModelSettingsService.replaceCatalog(refreshedCatalog)
            }
            if let localModelBenchmarkService {
                await localModelBenchmarkService.replaceCatalog(refreshedCatalog)
            }
            if let localModelReplyCheckService {
                await localModelReplyCheckService.replaceCatalog(refreshedCatalog)
            }
            await MainActor.run {
                localModelCatalog = refreshedCatalog
                localModelStatusMessageModelID = nil
                let count = refreshedCatalog.availableModels(
                    minimumSafetyPolicyVersion: refreshedCatalog.minimumSafetyPolicyVersion
                ).count
                switch result.source {
                case .remote:
                    localModelStatusMessage = KairoL10n.string("settings.models.message.catalogRefreshed", Int64(count))
                case .builtInFallback:
                    localModelStatusMessage = KairoL10n.string("settings.models.message.catalogUsingBuiltInFallback", Int64(count))
                }
            }
            await reloadLocalModelStatus()
        }
    }

    func reloadLocalModelStatus() async {
        let status: LocalModelSettingsStatus
        if let localModelSettingsService {
            if localModelDownloadTask == nil {
                do {
                    let cleanedModelIDs = try await localModelSettingsService.cleanupStaleDownloadingRecords()
                    if !cleanedModelIDs.isEmpty {
                        await MainActor.run {
                            localModelStatusMessageModelID = nil
                            localModelStatusMessage = KairoL10n.string("settings.models.message.cleanedStaleDownload")
                        }
                    }
                } catch {
                    await MainActor.run {
                        localModelStatusMessageModelID = nil
                        localModelStatusMessage = KairoL10n.string("settings.models.message.cleanStaleDownloadFailed", error.localizedDescription)
                    }
                }
            }
            status = await localModelSettingsService.status(
                minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
            )
        } else {
            status = Self.catalogOnlyLocalModelStatus(catalog: localModelCatalog)
        }

        await MainActor.run {
            localModelStatus = status
        }
    }

    static func catalogOnlyLocalModelStatus(catalog: LocalModelCatalog) -> LocalModelSettingsStatus {
        LocalModelSettingsStatus(
            selectedModelID: nil,
            selectedModel: nil,
            installedRecord: nil,
            preference: .automatic,
            availableModels: catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion),
            installedModels: []
        )
    }

    var localModelCatalogSourceText: String {
        localModelCatalog.sourceRepository?.absoluteString ?? KairoL10n.string("settings.models.catalogBuiltIn")
    }

    func localModelStatusColor(for action: LocalModelSettingsPrimaryAction) -> Color {
        switch action {
        case .selected:
            return .green
        case .select:
            return .blue
        case .download, .retryDownload:
            return .orange
        case .unavailable:
            return .secondary
        }
    }
}
#endif
