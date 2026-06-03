#if canImport(SwiftUI)
import SwiftUI

struct ProposedActionsStrip: View {
    let actions: [AgentAction]
    let onSelect: (AgentAction) -> Void
    private let catalog = SandboxActionCatalog()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    if let descriptor = catalog.descriptor(for: action.kind) {
                        let riskSummary = actionRiskSummary(for: action)
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                onSelect(action)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: descriptor.supportStatus == .unsupportedBySandbox ? "exclamationmark.triangle" : "checkmark.circle")
                                    Text(descriptor.displayName)
                                    CapabilityChipView(descriptor: descriptor)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Action preview: \(descriptor.displayName), \(descriptor.supportStatus.displayName), \(riskSummary)")
                            .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue)")

                            Text(riskSummary)
                                .font(.caption2)
                                .foregroundStyle(actionRiskColor(for: action))
                                .lineLimit(1)
                                .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue).risk")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .accessibilityIdentifier("chat.proposed-actions")
    }

    private func actionRiskSummary(for action: AgentAction) -> String {
        let confirmation = action.requiresConfirmation ? "Will ask first" : "No changes"
        return "\(actionRiskTierLabel(for: action.riskTier)) · \(confirmation)"
    }

    private func actionRiskTierLabel(for riskTier: ActionRiskTier) -> String {
        switch riskTier {
        case .tier0ReadOnly:
            return "Read only"
        case .tier1Draft:
            return "Draft only"
        case .tier2LowRiskWrite:
            return "Phone change"
        case .tier3HighRiskExternal:
            return "External handoff"
        }
    }

    private func actionRiskColor(for action: AgentAction) -> Color {
        switch action.riskTier {
        case .tier0ReadOnly:
            return .secondary
        case .tier1Draft:
            return .blue
        case .tier2LowRiskWrite:
            return .orange
        case .tier3HighRiskExternal:
            return .red
        }
    }
}

struct ToolCandidatesStrip: View {
    let candidates: [AgentToolInvocationCandidate]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(candidates) { candidate in
                    let riskSummary = toolRiskSummary(for: candidate)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: iconName(for: candidate.skillKind))
                            Text(candidate.title)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(candidate.skillKind.settingsTitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(candidate.handoffSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).summary")

                        Text(riskSummary)
                            .font(.caption2)
                            .foregroundStyle(toolRiskColor(for: candidate))
                            .lineLimit(1)
                            .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).risk")
                    }
                    .font(.caption)
                    .frame(width: 232, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tool candidate: \(candidate.title), \(candidate.skillKind.settingsTitle). \(candidate.handoffSummary). \(riskSummary)")
                    .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id)")
                }
            }
        }
        .accessibilityIdentifier("chat.tool-candidates")
    }

    private func toolRiskSummary(for candidate: AgentToolInvocationCandidate) -> String {
        let confirmation = candidate.requiresConfirmation ? "Will ask first" : "No changes"
        return "\(toolRiskTierLabel(for: candidate.riskTier)) · \(confirmation)"
    }

    private func toolRiskTierLabel(for riskTier: ActionRiskTier) -> String {
        switch riskTier {
        case .tier0ReadOnly:
            return "Read only"
        case .tier1Draft:
            return "Draft only"
        case .tier2LowRiskWrite:
            return "Phone change"
        case .tier3HighRiskExternal:
            return "External handoff"
        }
    }

    private func toolRiskColor(for candidate: AgentToolInvocationCandidate) -> Color {
        switch candidate.riskTier {
        case .tier0ReadOnly:
            return .secondary
        case .tier1Draft:
            return .blue
        case .tier2LowRiskWrite:
            return .orange
        case .tier3HighRiskExternal:
            return .red
        }
    }

    private func iconName(for kind: AgentSkillKind) -> String {
        switch kind {
        case .homeKitControl:
            return "house"
        case .shortcutWorkflow:
            return "square.stack.3d.up"
        case .oauthConnector:
            return "person.crop.circle.badge.checkmark"
        case .localModel:
            return "cpu"
        case .custom:
            return "wrench.and.screwdriver"
        }
    }
}
#endif
