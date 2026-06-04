#if canImport(SwiftUI)
import SwiftUI

extension SettingsView {
    func setLocalModelPreference(_ preference: ProviderRoutePreference) {
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
                    localModelStatus.preference = preference
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.preferenceSaved", preference.settingsTitle)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.preferenceFailed", error.localizedDescription)
                }
            }
        }
    }

    func downloadLocalModel(_ row: LocalModelSettingsRow) {
        if let progress = localModelDownloadProgress {
            localModelStatusMessageModelID = progress.modelID
            localModelStatusMessage = KairoL10n.string("settings.models.message.downloadInProgress")
            return
        }

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
            } catch LocalModelDownloadError.cancelled {
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloadCancelled", row.displayName)) }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloadFailed", error.localizedDescription)) }
                await reloadLocalModelStatus()
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

    func runLocalModelBenchmark(_ row: LocalModelSettingsRow) {
        Task {
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
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkRunning", row.displayName)
                }
                let result = try await localModelBenchmarkService.runBenchmark(
                    modelID: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkResult", row.displayName, result.summaryText)
                }
            } catch let error as LocalModelBenchmarkError {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    switch error {
                    case .modelNotInstalled:
                        localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkNeedsDownload", row.displayName)
                    case let .modelUnavailable(modelID):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkModelUnavailable", modelID)
                    case let .runtimeUnavailable(reason):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkRuntimeUnavailable", reason)
                    }
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkFailed", error.localizedDescription)
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

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.refreshingCatalog")
                }
                let mergedCatalog = try await localModelCatalogService.fetchMergedCatalog(with: localModelCatalog)
                if let localModelSettingsService {
                    await localModelSettingsService.replaceCatalog(mergedCatalog)
                }
                if let localModelBenchmarkService {
                    await localModelBenchmarkService.replaceCatalog(mergedCatalog)
                }
                if let localModelReplyCheckService {
                    await localModelReplyCheckService.replaceCatalog(mergedCatalog)
                }
                await MainActor.run {
                    localModelCatalog = mergedCatalog
                    localModelStatusMessageModelID = nil
                    let count = mergedCatalog.availableModels(
                        minimumSafetyPolicyVersion: mergedCatalog.minimumSafetyPolicyVersion
                    ).count
                    localModelStatusMessage = KairoL10n.string("settings.models.message.catalogRefreshed", Int64(count))
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.catalogRefreshFailed", error.localizedDescription)
                }
            }
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
