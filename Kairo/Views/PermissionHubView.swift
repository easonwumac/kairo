#if canImport(SwiftUI)
import SwiftUI

public struct PermissionHubView: View {
    @State private var homeKitPreviewMessage: String?
    @State private var skillManagerMessage: String?
    @State private var skillCatalog: AgentSkillCatalog

    private let registry = CapabilityRegistry()
    private let actionCatalog = SandboxActionCatalog()
    private let homeKitDemoCatalog = HomeKitControlDemoCatalog.default
    private let skillManagerService: AgentSkillManagerService?

    public init(
        skillManagerService: AgentSkillManagerService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples
    ) {
        self.skillManagerService = skillManagerService
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

                Section("Skill Manager") {
                    ForEach(skillCatalog.skills) { skill in
                        skillManagerRow(skill)
                    }

                    if let skillManagerMessage {
                        Text(skillManagerMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("access.skills.manager")

                Section("HomeKit Control Demos") {
                    ForEach(homeKitDemoCatalog.recipes) { recipe in
                        homeKitDemoRow(recipe)
                    }

                    if let homeKitPreviewMessage {
                        Text(homeKitPreviewMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("access.homekit.demos")
            }
            .navigationTitle("Access")
            .task {
                await loadSkillCatalog()
            }
        }
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
                .accessibilityIdentifier("access.skill.\(skill.id)")

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
        guard skillManagerService != nil else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = "\(skill.displayName) installed."
            return
        }

        skillManagerMessage = "\(skill.displayName) requires a signed manifest import before install."
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
