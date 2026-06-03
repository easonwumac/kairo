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
                                    Text("MVP")
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
                    Text("Skill Manager")
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
                    Text("HomeKit Control Demos")
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
            Text("Signed Manifest Import")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.manifest-import")

            TextField("Local skill name", text: $localSkillName)
                .accessibilityIdentifier("access.skills.local-create.name")

            TextField("Local skill summary", text: $localSkillSummary, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityIdentifier("access.skills.local-create.summary")

            Picker("Capability", selection: $localSkillCapability) {
                ForEach(CapabilityKey.allCases, id: \.self) { capability in
                    Text(capability.rawValue).tag(capability)
                }
            }
            .accessibilityIdentifier("access.skills.local-create.capability")

            Picker("Confirmation", selection: $localSkillConfirmationPolicy) {
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
                Label("Create Draft", systemImage: "plus.circle")
            }
            .disabled(localSkillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("access.skills.local-create.button")

            Button {
                Task {
                    await refreshMarketplaceCatalog()
                }
            } label: {
                Label("Refresh Marketplace", systemImage: "arrow.clockwise")
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
                Label("Preview Manifest", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(manifestImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("access.skills.manifest-import.button")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func skillSearchControls() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Search skills", text: $skillSearchText)
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
                skillManagerMessage = "\(draft.displayName) saved as a disabled local draft."
            } catch AgentSkillDraftError.emptyDisplayName {
                skillManagerMessage = "Skill name is required."
            } catch AgentSkillDraftError.missingCapabilitySelection {
                skillManagerMessage = "Choose at least one capability."
            } catch AgentSkillDraftError.missingConfirmationPolicy {
                skillManagerMessage = "Choose a confirmation policy."
            } catch {
                skillManagerMessage = "Unable to create local skill draft."
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
            skillManagerMessage = "\(draft.displayName) saved as a disabled local draft."
        } catch AgentSkillDraftError.emptyDisplayName {
            skillManagerMessage = "Skill name is required."
        } catch AgentSkillDraftError.missingCapabilitySelection {
            skillManagerMessage = "Choose at least one capability."
        } catch AgentSkillDraftError.missingConfirmationPolicy {
            skillManagerMessage = "Choose a confirmation policy."
        } catch {
            skillManagerMessage = "Unable to create local skill draft."
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
            summary: trimmedSummary.isEmpty ? "User-created local Kairo skill draft." : trimmedSummary,
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
                Text("No changelog provided.")
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
                Label("Confirm Install", systemImage: "checkmark.circle")
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
            return "Installed \(installedVersion) -> Incoming \(manifestInstallPreview.incomingVersion)"
        }

        return "Incoming \(manifestInstallPreview.incomingVersion)"
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
                    skillManagerMessage = "\(skill.displayName): \(skill.managementSummary)"
                } label: {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("access.skill.\(skill.id).manage")

                switch skill.installationStatus {
                case .available:
                    Button {
                        Task {
                            await installSkill(skill)
                        }
                    } label: {
                        Label("Install", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).install")
                case .installed:
                    if skill.source == .marketplace, skill.downloadURL != nil {
                        Button {
                            Task {
                                await installSkill(skill)
                            }
                        } label: {
                            Label("Preview Update", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .accessibilityIdentifier("access.skill.\(skill.id).update")
                    }

                    Button {
                        Task {
                            await disableSkill(skill)
                        }
                    } label: {
                        Label("Disable", systemImage: "pause.circle")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).disable")
                case .disabled:
                    Button {
                        Task {
                            await enableSkill(skill)
                        }
                    } label: {
                        Label("Enable", systemImage: "play.circle")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).enable")
                }

                Button(role: .destructive) {
                    Task {
                        await removeSkill(skill)
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
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
            return "Showing all \(total) skills."
        }
        if filtered == 1, let skill = filteredSkills.first {
            return "Showing 1 of \(total) skills: \(skill.displayName)."
        }
        return "Showing \(filtered) of \(total) skills."
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
            skillManagerMessage = "Marketplace refresh requires a catalog source."
            return
        }

        isRefreshingMarketplace = true
        defer { isRefreshingMarketplace = false }

        do {
            let remoteCatalog = try await marketplaceCatalogService.fetchCatalog()
            skillCatalog = skillCatalog.mergingMarketplaceCatalog(remoteCatalog.catalog)
            skillManagerMessage = "Loaded \(remoteCatalog.catalog.skills.count) marketplace skills from \(remoteCatalog.sourceRepository.host ?? "repository")."
        } catch {
            skillManagerMessage = "Unable to refresh marketplace skills."
        }
    }

    @MainActor
    private func previewManifestText() async {
        let trimmedManifest = manifestImportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedManifest.isEmpty else {
            skillManagerMessage = "Manifest JSON is empty."
            manifestInstallPreview = nil
            return
        }
        guard let skillManagerService else {
            skillManagerMessage = "Manifest import requires live Skill Manager."
            manifestInstallPreview = nil
            return
        }

        do {
            let preview = try await skillManagerService.previewInstall(jsonString: manifestImportText)
            manifestInstallPreview = preview
            skillManagerMessage = preview.summary
        } catch AgentSkillManifestImportError.invalidJSON {
            skillManagerMessage = "Manifest JSON is invalid."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = "Manifest signature is invalid."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = "Manifest signing key has been revoked."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = "Manifest signing key is not active yet."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = "Manifest signing key has expired."
            manifestInstallPreview = nil
        } catch {
            skillManagerMessage = "Unable to import manifest."
            manifestInstallPreview = nil
        }
    }

    @MainActor
    private func confirmManifestInstall() async {
        guard let manifestInstallPreview else {
            skillManagerMessage = "Preview a manifest before installing."
            return
        }
        guard manifestInstallPreview.installationChange != .downgradeBlocked else {
            skillManagerMessage = manifestInstallPreview.summary
            return
        }
        guard let skillManagerService else {
            skillManagerMessage = "Manifest import requires live Skill Manager."
            return
        }

        do {
            let installed = try await skillManagerService.install(manifest: manifestInstallPreview.manifest)
            skillCatalog = try await skillManagerService.catalog()
            manifestImportText = ""
            self.manifestInstallPreview = nil
            skillManagerMessage = "\(installed.displayName) installed from signed manifest."
        } catch AgentSkillInstallError.versionDowngrade(_, let installedVersion, let incomingVersion) {
            skillManagerMessage = "Blocked downgrade from \(installedVersion) to \(incomingVersion)."
        } catch AgentSkillInstallError.compatibilityBlocked(_, let issues) {
            skillManagerMessage = issues.map(\.message).joined(separator: "; ")
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = "Manifest signature is invalid."
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = "Manifest signing key has been revoked."
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = "Manifest signing key is not active yet."
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = "Manifest signing key has expired."
        } catch {
            skillManagerMessage = "Unable to import manifest."
        }
    }

    @MainActor
    private func loadSkillCatalog() async {
        guard let skillManagerService else { return }

        do {
            skillCatalog = try await skillManagerService.catalog()
        } catch {
            skillManagerMessage = "Unable to load Skill Manager state."
        }
    }

    @MainActor
    private func installSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = "\(skill.displayName) installed."
            return
        }

        guard let marketplaceCatalogService, skill.downloadURL != nil else {
            skillManagerMessage = "\(skill.displayName) requires a signed manifest import before install."
            return
        }

        do {
            let manifest = try await marketplaceCatalogService.fetchManifest(for: skill)
            let preview = try await skillManagerService.previewInstall(manifest: manifest)
            manifestInstallPreview = preview
            skillManagerMessage = preview.summary
        } catch AgentSkillManifestImportError.invalidJSON {
            skillManagerMessage = "Manifest JSON is invalid."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = "Manifest signature is invalid."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = "Manifest signing key has been revoked."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = "Manifest signing key is not active yet."
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = "Manifest signing key has expired."
            manifestInstallPreview = nil
        } catch {
            skillManagerMessage = "Unable to preview \(skill.displayName)."
            manifestInstallPreview = nil
        }
    }

    @MainActor
    private func disableSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .disabled)
            skillManagerMessage = "\(skill.displayName) disabled."
            return
        }

        do {
            _ = try await skillManagerService.disableSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = "\(skill.displayName) disabled."
        } catch {
            skillManagerMessage = "Unable to disable \(skill.displayName)."
        }
    }

    @MainActor
    private func enableSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = "\(skill.displayName) enabled."
            return
        }

        do {
            _ = try await skillManagerService.enableSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = "\(skill.displayName) enabled."
        } catch {
            skillManagerMessage = "Unable to enable \(skill.displayName)."
        }
    }

    @MainActor
    private func removeSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.removingSkill(id: skill.id)
            skillManagerMessage = "\(skill.displayName) removed from manager."
            return
        }

        do {
            try await skillManagerService.removeSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = "\(skill.displayName) removed from manager."
        } catch {
            skillManagerMessage = "Unable to remove \(skill.displayName)."
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

            Button("Preview Confirmation") {
                homeKitPreviewMessage = recipe.confirmationSummary
            }
            .accessibilityIdentifier("access.homekit.demo.\(recipe.id).confirm")
        }
        .padding(.vertical, 4)
    }
}
#endif
