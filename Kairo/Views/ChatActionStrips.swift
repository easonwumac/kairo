#if canImport(SwiftUI)
import SwiftUI

struct ProposedActionsStrip: View {
    let actions: [AgentAction]
    let onSelect: (AgentAction) -> Void
    private let catalog = SandboxActionCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actions) { action in
                if let descriptor = catalog.descriptor(for: action.kind) {
                    let riskSummary = actionRiskSummary(for: action)
                    Button {
                        onSelect(action)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: descriptor.supportStatus == .unsupportedBySandbox ? "exclamationmark.triangle" : "checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(actionRiskColor(for: action))
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(KairoL10n.string("chat.action.card.intent"))
                                    .font(.caption2.weight(.bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue).intent")

                                Text(descriptor.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(KairoDesign.ink)
                                    .lineLimit(2)

                                HStack(spacing: 6) {
                                    CapabilityChipView(descriptor: descriptor)

                                    Text(riskSummary)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(actionRiskColor(for: action))
                                        .lineLimit(1)
                                        .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue).risk")
                                }
                            }

                            Spacer(minLength: 8)

                            Text(KairoL10n.string("chat.action.card.review"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(KairoDesign.ink, in: Capsule())
                        }
                        .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue)")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.07), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(KairoL10n.string("chat.action.accessibility.preview", descriptor.displayName, descriptor.supportStatus.displayName, riskSummary))
                    .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("chat.proposed-actions")
    }

    private func actionRiskSummary(for action: AgentAction) -> String {
        let confirmation = action.requiresConfirmation
            ? KairoL10n.string("chat.action.confirmation.willAskFirst")
            : KairoL10n.string("chat.action.confirmation.noChanges")
        return "\(actionRiskTierLabel(for: action.riskTier)) · \(confirmation)"
    }

    private func actionRiskTierLabel(for riskTier: ActionRiskTier) -> String {
        switch riskTier {
        case .tier0ReadOnly:
            return KairoL10n.string("chat.action.risk.readOnly")
        case .tier1Draft:
            return KairoL10n.string("chat.action.risk.draftOnly")
        case .tier2LowRiskWrite:
            return KairoL10n.string("chat.action.risk.phoneChange")
        case .tier3HighRiskExternal:
            return KairoL10n.string("chat.action.risk.externalHandoff")
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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(candidates) { candidate in
                let riskSummary = toolRiskSummary(for: candidate)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: iconName(for: candidate.skillKind))
                            .font(.subheadline.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(toolRiskColor(for: candidate))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(KairoL10n.string("chat.tool.card.intent"))
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).intent")

                            Text(candidate.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                                .lineLimit(2)

                            Text(candidate.handoffSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).summary")

                            HStack(spacing: 6) {
                                KairoStatusPill(
                                    title: optionDetail(for: candidate),
                                    systemImage: candidate.requiresConfirmation ? "checkmark.shield" : "arrow.up.right",
                                    tint: toolRiskColor(for: candidate)
                                )

                                Text(riskSummary)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(toolRiskColor(for: candidate))
                                    .lineLimit(1)
                                    .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).risk")
                            }
                        }

                        Spacer(minLength: 8)

                        Text(KairoL10n.string("chat.action.card.review"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(KairoDesign.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(KairoDesign.ink.opacity(0.08), in: Capsule())
                    }
                    .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id)")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                }
                .accessibilityLabel(KairoL10n.string("chat.option.accessibility.suggested", candidate.title, optionDetail(for: candidate), candidate.handoffSummary, riskSummary))
                .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id)")
            }
        }
        .accessibilityIdentifier("chat.tool-candidates")
    }

    private func toolRiskSummary(for candidate: AgentToolInvocationCandidate) -> String {
        let confirmation = candidate.requiresConfirmation
            ? KairoL10n.string("chat.action.confirmation.willAskFirst")
            : KairoL10n.string("chat.action.confirmation.noChanges")
        return "\(toolRiskTierLabel(for: candidate.riskTier)) · \(confirmation)"
    }

    private func optionDetail(for candidate: AgentToolInvocationCandidate) -> String {
        if candidate.requiresConfirmation {
            return KairoL10n.string("chat.option.reviewFirst")
        }
        switch candidate.riskTier {
        case .tier0ReadOnly:
            return KairoL10n.string("chat.action.confirmation.noChanges")
        case .tier1Draft:
            return KairoL10n.string("chat.option.visibleHandoff")
        case .tier2LowRiskWrite:
            return KairoL10n.string("chat.action.risk.phoneChange")
        case .tier3HighRiskExternal:
            return KairoL10n.string("chat.action.risk.externalHandoff")
        }
    }

    private func toolRiskTierLabel(for riskTier: ActionRiskTier) -> String {
        switch riskTier {
        case .tier0ReadOnly:
            return KairoL10n.string("chat.action.risk.readOnly")
        case .tier1Draft:
            return KairoL10n.string("chat.action.risk.draftOnly")
        case .tier2LowRiskWrite:
            return KairoL10n.string("chat.action.risk.phoneChange")
        case .tier3HighRiskExternal:
            return KairoL10n.string("chat.action.risk.externalHandoff")
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
