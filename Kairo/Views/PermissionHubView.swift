#if canImport(SwiftUI)
import SwiftUI

public struct PermissionHubView: View {
    @State private var homeKitPreviewMessage: String?
    @State private var skillManagerMessage: String?
    @State private var manifestImportText = ""
    @State private var manifestInstallPreview: AgentSkillInstallPreview?
    @State private var isRefreshingMarketplace = false
    @State private var localSkillName = ""
    @State private var localSkillSummary = ""
    @State private var localSkillCapability: CapabilityKey = .appIntents
    @State private var localSkillConfirmationPolicy: AgentSkillConfirmationPolicy = .previewRequired
    @State private var skillSearchText = ""
    @State private var skillCatalog: AgentSkillCatalog

    private let registry = CapabilityRegistry()
    private let actionCatalog = SandboxActionCatalog()
    private let homeKitDemoCatalog = HomeKitControlDemoCatalog.default
    private let skillManagerService: AgentSkillManagerService?
    private let marketplaceCatalogService: AgentSkillMarketplaceCatalogService?

    public init(
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples
    ) {
        self.skillManagerService = skillManagerService
        self.marketplaceCatalogService = marketplaceCatalogService
        _skillCatalog = State(initialValue: initialSkillCatalog)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Capabilities") {
                    ForEach(registry.capabilities) { capability in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(capability.displayName).font(.headline)
                                Spacer()
                                Text(capability.permission.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(capability.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let fallbackMessage = capability.status.accessFallbackMessage {
                                Text(fallbackMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("access.capability.\(capability.key.rawValue).status-fallback")
                            }
                            HStack {
                                if capability.isMVP {
                                    Text(KairoL10n.string("access.capability.core"))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                ForEach(actionCatalog.descriptors(for: capability.key).prefix(3)) { descriptor in
                                    CapabilityChipView(descriptor: descriptor)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    skillSearchControls()
                    if normalizedSkillSearchText.isEmpty {
                        manifestImportControls()
                    }

                    if let skillManagerMessage {
                        Text(skillManagerMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("access.skills.message")
                    }

                    ForEach(filteredSkills) { skill in
                        skillManagerRow(skill)
                    }

                    if let manifestInstallPreview {
                        manifestPreview(manifestInstallPreview)
                    }
                } header: {
                    Text(KairoL10n.string("access.skills.manager.title"))
                        .accessibilityIdentifier("access.skills.manager")
                }

                Section {
                    ForEach(homeKitDemoCatalog.recipes) { recipe in
                        homeKitDemoRow(recipe)
                    }

                    if let homeKitPreviewMessage {
                        Text(homeKitPreviewMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(KairoL10n.string("access.homekit.demos.title"))
                        .accessibilityIdentifier("access.homekit.demos")
                }
            }
            .navigationTitle("Access")
            .task {
                await loadSkillCatalog()
            }
        }
    }

    @ViewBuilder
    private func manifestImportControls() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("access.skills.manifestImport.title"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.manifest-import")

            TextField(KairoL10n.string("access.skills.localCreate.namePlaceholder"), text: $localSkillName)
                .accessibilityIdentifier("access.skills.local-create.name")

            TextField(KairoL10n.string("access.skills.localCreate.summaryPlaceholder"), text: $localSkillSummary, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityIdentifier("access.skills.local-create.summary")

            Picker(KairoL10n.string("access.skills.localCreate.capability"), selection: $localSkillCapability) {
                ForEach(CapabilityKey.allCases, id: \.self) { capability in
                    Text(capability.rawValue).tag(capability)
                }
            }
            .accessibilityIdentifier("access.skills.local-create.capability")

            Picker(KairoL10n.string("access.skills.localCreate.confirmation"), selection: $localSkillConfirmationPolicy) {
                ForEach(AgentSkillConfirmationPolicy.allCases, id: \.self) { policy in
                    Text(policy.settingsTitle).tag(policy)
                }
            }
            .accessibilityIdentifier("access.skills.local-create.confirmation-policy")

            Button {
                Task {
                    await createLocalSkillDraft()
                }
            } label: {
                Label(KairoL10n.string("access.skills.localCreate.createDraft"), systemImage: "plus.circle")
            }
            .disabled(localSkillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("access.skills.local-create.button")

            Button {
                Task {
                    await refreshMarketplaceCatalog()
                }
            } label: {
                Label(KairoL10n.string("access.skills.marketplace.refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshingMarketplace || marketplaceCatalogService == nil)
            .accessibilityIdentifier("access.skills.marketplace-refresh")

            TextEditor(text: $manifestImportText)
                .frame(minHeight: 84)
                .font(.caption)
                .accessibilityIdentifier("access.skills.manifest-import.text")

            Button {
                Task {
                    await previewManifestText()
                }
            } label: {
                Label(KairoL10n.string("access.skills.manifestImport.preview"), systemImage: "doc.text.magnifyingglass")
            }
            .disabled(manifestImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("access.skills.manifest-import.button")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func skillSearchControls() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(KairoL10n.string("access.skills.search.placeholder"), text: $skillSearchText)
                .accessibilityIdentifier("access.skills.search")

            Text(skillSearchSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.search.summary")
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func createLocalSkillDraft() async {
        let request = AgentSkillDraftRequest(
            displayName: localSkillName,
            summary: localSkillSummary,
            kind: .custom,
            requiredCapabilities: [localSkillCapability],
            confirmationPolicy: localSkillConfirmationPolicy
        )

        guard let skillManagerService else {
            do {
                let draft = try previewLocalSkillDraft(from: request)
                skillCatalog = skillCatalog.replacing(draft)
                localSkillName = ""
                localSkillSummary = ""
                localSkillCapability = .appIntents
                localSkillConfirmationPolicy = .previewRequired
                manifestInstallPreview = nil
                skillManagerMessage = KairoL10n.string("access.skills.message.draftSaved", draft.displayName)
            } catch AgentSkillDraftError.emptyDisplayName {
                skillManagerMessage = KairoL10n.string("access.skills.message.skillNameRequired")
            } catch AgentSkillDraftError.missingCapabilitySelection {
                skillManagerMessage = KairoL10n.string("access.skills.message.capabilityRequired")
            } catch AgentSkillDraftError.missingConfirmationPolicy {
                skillManagerMessage = KairoL10n.string("access.skills.message.confirmationRequired")
            } catch {
                skillManagerMessage = KairoL10n.string("access.skills.message.createDraftFailed")
            }
            return
        }

        do {
            let draft = try await skillManagerService.createUserSkillDraft(request)
            skillCatalog = try await skillManagerService.catalog()
            localSkillName = ""
            localSkillSummary = ""
            localSkillCapability = .appIntents
            localSkillConfirmationPolicy = .previewRequired
            manifestInstallPreview = nil
            skillManagerMessage = KairoL10n.string("access.skills.message.draftSaved", draft.displayName)
        } catch AgentSkillDraftError.emptyDisplayName {
            skillManagerMessage = KairoL10n.string("access.skills.message.skillNameRequired")
        } catch AgentSkillDraftError.missingCapabilitySelection {
            skillManagerMessage = KairoL10n.string("access.skills.message.capabilityRequired")
        } catch AgentSkillDraftError.missingConfirmationPolicy {
            skillManagerMessage = KairoL10n.string("access.skills.message.confirmationRequired")
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.createDraftFailed")
        }
    }

    private func previewLocalSkillDraft(from request: AgentSkillDraftRequest) throws -> AgentSkill {
        let trimmedName = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AgentSkillDraftError.emptyDisplayName }
        guard !request.requiredCapabilities.isEmpty else { throw AgentSkillDraftError.missingCapabilitySelection }
        guard let confirmationPolicy = request.confirmationPolicy else { throw AgentSkillDraftError.missingConfirmationPolicy }

        let trimmedSummary = request.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackID = "user-\(trimmedName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return AgentSkill(
            id: fallbackID,
            displayName: trimmedName,
            summary: trimmedSummary.isEmpty ? KairoL10n.string("access.skills.localCreate.defaultSummary") : trimmedSummary,
            kind: request.kind,
            source: .userCreated,
            installationStatus: .disabled,
            requiredCapabilities: request.requiredCapabilities,
            shortcutRecipeID: request.shortcutRecipeID,
            version: "local-draft",
            author: "User",
            confirmationPolicy: confirmationPolicy,
            compatibilityRequirements: request.compatibilityRequirements
        )
    }

    @ViewBuilder
    private func manifestPreview(_ manifestInstallPreview: AgentSkillInstallPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manifestInstallPreview.summary)
                .font(.caption)
                .fontWeight(.medium)
                .accessibilityIdentifier("access.skills.manifest-preview.summary")

            Text(manifestPreviewVersionSummary(manifestInstallPreview))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.manifest-preview.version")

            Text(manifestInstallPreview.compatibilityReport.summary)
                .font(.caption2)
                .foregroundStyle(manifestInstallPreview.compatibilityReport.isInstallable ? Color.secondary : Color.red)
                .accessibilityIdentifier("access.skills.manifest-preview.compatibility")

            ForEach(manifestInstallPreview.compatibilityReport.issues) { issue in
                Text("- \(issue.message)")
                    .font(.caption2)
                    .foregroundStyle(issue.severity == .blocking ? .red : .secondary)
                    .accessibilityIdentifier("access.skills.manifest-preview.compatibility.\(issue.kind.rawValue)")
            }

            if manifestInstallPreview.changelog.isEmpty {
                Text(KairoL10n.string("access.skills.manifestPreview.noChangelog"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("access.skills.manifest-preview.changelog.empty")
            } else {
                ForEach(manifestInstallPreview.changelog, id: \.self) { item in
                    Text("- \(item)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("access.skills.manifest-preview.changelog")
                }
            }

            Button {
                Task {
                    await confirmManifestInstall()
                }
            } label: {
                Label(KairoL10n.string("access.skills.manifestPreview.confirmInstall"), systemImage: "checkmark.circle")
            }
            .font(.caption)
            .disabled(
                manifestInstallPreview.installationChange == .downgradeBlocked
                || !manifestInstallPreview.compatibilityReport.isInstallable
            )
            .accessibilityIdentifier("access.skills.manifest-preview.confirm")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("access.skills.manifest-preview")
    }

    private func manifestPreviewVersionSummary(_ manifestInstallPreview: AgentSkillInstallPreview) -> String {
        if let installedVersion = manifestInstallPreview.installedVersion {
            return KairoL10n.string("access.skills.manifestPreview.versionUpdate", installedVersion, manifestInstallPreview.incomingVersion)
        }

        return KairoL10n.string("access.skills.manifestPreview.versionIncoming", manifestInstallPreview.incomingVersion)
    }

    @ViewBuilder
    private func skillManagerRow(_ skill: AgentSkill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(skill.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(skill.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(skill.managementSummary)
                .font(.caption)
                .accessibilityIdentifier("access.skill.\(skill.id).summary")

            HStack {
                Button {
                    skillManagerMessage = KairoL10n.string("access.skills.message.managementSummary", skill.displayName, skill.managementSummary)
                } label: {
                    Label(KairoL10n.string("access.skills.action.manage"), systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("access.skill.\(skill.id).manage")

                switch skill.installationStatus {
                case .available:
                    Button {
                        Task {
                            await installSkill(skill)
                        }
                    } label: {
                        Label(KairoL10n.string("access.skills.action.install"), systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).install")
                case .installed:
                    if skill.source == .marketplace, skill.downloadURL != nil {
                        Button {
                            Task {
                                await installSkill(skill)
                            }
                        } label: {
                            Label(KairoL10n.string("access.skills.action.previewUpdate"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .accessibilityIdentifier("access.skill.\(skill.id).update")
                    }

                    Button {
                        Task {
                            await disableSkill(skill)
                        }
                    } label: {
                        Label(KairoL10n.string("access.skills.action.disable"), systemImage: "pause.circle")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).disable")
                case .disabled:
                    Button {
                        Task {
                            await enableSkill(skill)
                        }
                    } label: {
                        Label(KairoL10n.string("access.skills.action.enable"), systemImage: "play.circle")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).enable")
                }

                Button(role: .destructive) {
                    Task {
                        await removeSkill(skill)
                    }
                } label: {
                    Label(KairoL10n.string("access.skills.action.remove"), systemImage: "trash")
                }
                .accessibilityIdentifier("access.skill.\(skill.id).remove")
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("access.skill.\(skill.id)")
    }

    private var filteredSkills: [AgentSkill] {
        let query = normalizedSkillSearchText
        guard !query.isEmpty else {
            return skillCatalog.skills
        }
        return skillCatalog.skills.filter { skillMatchesSearch($0, query: query) }
    }

    private var normalizedSkillSearchText: String {
        skillSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var skillSearchSummary: String {
        let total = skillCatalog.skills.count
        let filtered = filteredSkills.count
        if normalizedSkillSearchText.isEmpty {
            return KairoL10n.string("access.skills.search.summary.all", Int64(total))
        }
        if filtered == 1, let skill = filteredSkills.first {
            return KairoL10n.string("access.skills.search.summary.one", Int64(total), skill.displayName)
        }
        return KairoL10n.string("access.skills.search.summary.many", Int64(filtered), Int64(total))
    }

    private func skillMatchesSearch(_ skill: AgentSkill, query: String) -> Bool {
        [
            skill.id,
            skill.displayName,
            skill.summary,
            skill.kind.settingsTitle,
            skill.source.rawValue,
            skill.installationStatus.rawValue
        ]
            .map { $0.lowercased() }
            .contains { $0.contains(query) }
    }

    @MainActor
    private func refreshMarketplaceCatalog() async {
        guard let marketplaceCatalogService else {
            skillManagerMessage = KairoL10n.string("access.skills.message.marketplaceSourceRequired")
            return
        }

        isRefreshingMarketplace = true
        defer { isRefreshingMarketplace = false }

        do {
            let remoteCatalog = try await marketplaceCatalogService.fetchCatalog()
            skillCatalog = skillCatalog.mergingMarketplaceCatalog(remoteCatalog.catalog)
            skillManagerMessage = KairoL10n.string("access.skills.message.marketplaceLoaded", Int64(remoteCatalog.catalog.skills.count), remoteCatalog.sourceRepository.host ?? KairoL10n.string("access.skills.message.repositoryFallback"))
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.marketplaceRefreshFailed", error.localizedDescription)
        }
    }

    @MainActor
    private func previewManifestText() async {
        let trimmedManifest = manifestImportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedManifest.isEmpty else {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestEmpty")
            manifestInstallPreview = nil
            return
        }
        guard let skillManagerService else {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRequiresLiveManager")
            manifestInstallPreview = nil
            return
        }

        do {
            let preview = try await skillManagerService.previewInstall(jsonString: manifestImportText)
            manifestInstallPreview = preview
            skillManagerMessage = preview.summary
        } catch AgentSkillManifestImportError.invalidJSON {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidJSON")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidSignature")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRevokedKey")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyPendingPublication(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestPendingPublication")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyNotYetValid")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyExpired")
            manifestInstallPreview = nil
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestImportFailed")
            manifestInstallPreview = nil
        }
    }

    @MainActor
    private func confirmManifestInstall() async {
        guard let manifestInstallPreview else {
            skillManagerMessage = KairoL10n.string("access.skills.message.previewBeforeInstall")
            return
        }
        guard manifestInstallPreview.installationChange != .downgradeBlocked else {
            skillManagerMessage = manifestInstallPreview.summary
            return
        }
        guard let skillManagerService else {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRequiresLiveManager")
            return
        }

        do {
            let installed = try await skillManagerService.install(manifest: manifestInstallPreview.manifest)
            skillCatalog = try await skillManagerService.catalog()
            manifestImportText = ""
            self.manifestInstallPreview = nil
            skillManagerMessage = KairoL10n.string("access.skills.message.installedFromManifest", installed.displayName)
        } catch AgentSkillInstallError.versionDowngrade(_, let installedVersion, let incomingVersion) {
            skillManagerMessage = KairoL10n.string("access.skills.message.downgradeBlocked", installedVersion, incomingVersion)
        } catch AgentSkillInstallError.compatibilityBlocked(_, let issues) {
            skillManagerMessage = issues.map(\.message).joined(separator: "; ")
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidSignature")
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRevokedKey")
        } catch AgentSkillManifestValidationError.signingKeyPendingPublication(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestPendingPublication")
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyNotYetValid")
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyExpired")
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestImportFailed")
        }
    }

    @MainActor
    private func loadSkillCatalog() async {
        guard let skillManagerService else { return }

        do {
            skillCatalog = try await skillManagerService.catalog()
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.loadFailed")
        }
    }

    @MainActor
    private func installSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = KairoL10n.string("access.skills.message.installed", skill.displayName)
            return
        }

        guard let marketplaceCatalogService, skill.downloadURL != nil else {
            skillManagerMessage = KairoL10n.string("access.skills.message.signedManifestRequired", skill.displayName)
            return
        }

        do {
            let manifest = try await marketplaceCatalogService.fetchManifest(for: skill)
            let preview = try await skillManagerService.previewInstall(manifest: manifest)
            manifestInstallPreview = preview
            skillManagerMessage = preview.summary
        } catch AgentSkillManifestImportError.invalidJSON {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidJSON")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidSignature")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRevokedKey")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyPendingPublication(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestPendingPublication")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyNotYetValid")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyExpired")
            manifestInstallPreview = nil
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.previewFailed", skill.displayName)
            manifestInstallPreview = nil
        }
    }

    @MainActor
    private func disableSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .disabled)
            skillManagerMessage = KairoL10n.string("access.skills.message.disabled", skill.displayName)
            return
        }

        do {
            _ = try await skillManagerService.disableSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = KairoL10n.string("access.skills.message.disabled", skill.displayName)
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.disableFailed", skill.displayName)
        }
    }

    @MainActor
    private func enableSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = KairoL10n.string("access.skills.message.enabled", skill.displayName)
            return
        }

        do {
            _ = try await skillManagerService.enableSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = KairoL10n.string("access.skills.message.enabled", skill.displayName)
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.enableFailed", skill.displayName)
        }
    }

    @MainActor
    private func removeSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.removingSkill(id: skill.id)
            skillManagerMessage = KairoL10n.string("access.skills.message.removed", skill.displayName)
            return
        }

        do {
            try await skillManagerService.removeSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = KairoL10n.string("access.skills.message.removed", skill.displayName)
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.removeFailed", skill.displayName)
        }
    }

    @ViewBuilder
    private func homeKitDemoRow(_ recipe: HomeKitControlDemoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recipe.targetSummary)
                .font(.caption)
                .accessibilityIdentifier("access.homekit.demo.\(recipe.id)")

            Text(recipe.sandboxNotes)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(KairoL10n.string("access.homekit.demo.previewConfirmation")) {
                homeKitPreviewMessage = recipe.confirmationSummary
            }
            .accessibilityIdentifier("access.homekit.demo.\(recipe.id).confirm")
        }
        .padding(.vertical, 4)
    }
}
#endif
