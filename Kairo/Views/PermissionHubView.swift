#if canImport(SwiftUI)
import SwiftUI

public struct PermissionHubView: View {
    @State private var homeKitPreviewMessage: String?
    @State private var skillManagerMessage: String?
    @State private var skillCatalog = AgentSkillCatalog.defaultWithMarketplaceSamples

    private let registry = CapabilityRegistry()
    private let actionCatalog = SandboxActionCatalog()
    private let homeKitDemoCatalog = HomeKitControlDemoCatalog.default

    public init() {}

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
                        skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
                        skillManagerMessage = "\(skill.displayName) installed."
                    } label: {
                        Label("Install", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).install")
                case .installed:
                    Button {
                        skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .disabled)
                        skillManagerMessage = "\(skill.displayName) disabled."
                    } label: {
                        Label("Disable", systemImage: "pause.circle")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).disable")
                case .disabled:
                    Button {
                        skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
                        skillManagerMessage = "\(skill.displayName) enabled."
                    } label: {
                        Label("Enable", systemImage: "play.circle")
                    }
                    .accessibilityIdentifier("access.skill.\(skill.id).enable")
                }

                Button(role: .destructive) {
                    skillCatalog = skillCatalog.removingSkill(id: skill.id)
                    skillManagerMessage = "\(skill.displayName) removed from manager."
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .accessibilityIdentifier("access.skill.\(skill.id).remove")
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
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
