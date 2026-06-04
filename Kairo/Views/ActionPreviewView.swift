#if canImport(SwiftUI)
import SwiftUI

public struct ActionPreviewView: View {
    public let action: AgentAction
    public let descriptor: SandboxActionDescriptor?
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    public init(
        action: AgentAction,
        descriptor: SandboxActionDescriptor? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.action = action
        self.descriptor = descriptor ?? SandboxActionCatalog().descriptor(for: action.kind)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: action.kind == .unsupportedSandboxAction ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(action.kind == .unsupportedSandboxAction ? KairoDesign.red : KairoDesign.teal)
                        .frame(width: 42, height: 42)
                        .background((action.kind == .unsupportedSandboxAction ? KairoDesign.red : KairoDesign.teal).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(KairoL10n.string("chat.action.preview.title"))
                            .font(.title3.bold())
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(KairoL10n.string("chat.action.preview.safetyNote"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    if let descriptor {
                        CapabilityChipView(descriptor: descriptor)
                    }
                    KairoStatusPill(title: riskLabel, systemImage: "gauge.medium", tint: riskColor)
                }

                if let descriptor {
                    reviewField(title: "Capability", value: descriptor.displayName)
                }

                reviewField(title: "Why", value: action.rationale)

                KairoGroupedSurface {
                    actionPayloadPreview
                }

                HStack(spacing: 12) {
                    Button(role: .cancel, action: onCancel) {
                        Text(KairoL10n.string("chat.action.preview.cancel"))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("chat.action.cancel.label")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("chat.action.cancel")

                    Button(action: onConfirm) {
                        Text(KairoL10n.string(action.kind == .unsupportedSandboxAction ? "chat.action.preview.dismiss" : "chat.action.preview.confirm"))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("chat.action.confirm.label")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(descriptor?.supportStatus == .unsupportedBySandbox)
                    .accessibilityIdentifier("chat.action.confirm")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(KairoDesign.background.ignoresSafeArea())
        .accessibilityIdentifier("chat.action-preview")
    }

    private var riskColor: Color {
        switch action.riskTier {
        case .tier0ReadOnly:
            return KairoDesign.muted
        case .tier1Draft:
            return KairoDesign.blue
        case .tier2LowRiskWrite:
            return KairoDesign.amber
        case .tier3HighRiskExternal:
            return KairoDesign.red
        }
    }

    private var riskLabel: String {
        switch action.kind {
        case .saveMemory:
            return "Saves memory"
        case .createReminderDraft:
            return "Creates reminder"
        case .createCalendarDraft:
            return "Creates calendar event"
        case .createContactDraft:
            return "Creates contact"
        case .sendNotification:
            return "Schedules notification"
        default:
            break
        }
        switch action.riskTier {
        case .tier0ReadOnly:
            return "Read only"
        case .tier1Draft:
            return "Draft or handoff"
        case .tier2LowRiskWrite:
            return "Writes local data"
        case .tier3HighRiskExternal:
            return "External account action"
        }
    }

    private func reviewField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(KairoDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actionPayloadPreview: some View {
        switch action.payload {
        case .text(let text):
            Text(text).font(.callout).padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        case .reminder(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title).font(.headline)
                if let notes = draft.notes { Text(notes).font(.caption) }
                if let dueDate = draft.dueDate { Text(dueDate, style: .date).font(.caption) }
            }
        case .calendarEvent(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title).font(.headline)
                if let notes = draft.notes { Text(notes).font(.caption) }
                Text("\(draft.startDate.formatted()) – \(draft.endDate.formatted())").font(.caption)
            }
        case .contact(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.displayName.isEmpty ? "Kairo Contact" : draft.displayName).font(.headline)
                if !draft.phoneNumbers.isEmpty {
                    Text("Phone: \(draft.phoneNumbers.joined(separator: ", "))").font(.caption)
                }
                if !draft.emailAddresses.isEmpty {
                    Text("Email: \(draft.emailAddresses.joined(separator: ", "))").font(.caption)
                }
                if let notes = draft.notes { Text(notes).font(.caption) }
            }
        case .email(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.subject.isEmpty ? "Email Draft" : draft.subject).font(.headline)
                if !draft.to.isEmpty {
                    Text("To: \(draft.to.joined(separator: ", "))").font(.caption)
                }
                if !draft.cc.isEmpty {
                    Text("Cc: \(draft.cc.joined(separator: ", "))").font(.caption)
                }
                if !draft.body.isEmpty {
                    Text(draft.body).font(.caption)
                }
            }
        case .mapDirections(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.destinationQuery.isEmpty ? "Apple Maps Destination" : draft.destinationQuery).font(.headline)
                Text("Mode: \(draft.mode.displayName)").font(.caption)
                Text("Apple Maps opens visibly; navigation still requires user action.").font(.caption).foregroundStyle(.secondary)
            }
        case .message(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.recipients.isEmpty ? "Messages Handoff" : draft.recipients.joined(separator: ", ")).font(.headline)
                if !draft.body.isEmpty {
                    Text(draft.body).font(.caption)
                }
                Text("Body stays in Kairo preview; Messages opens visibly with the recipient only.").font(.caption).foregroundStyle(.secondary)
            }
        case .phoneCall(let draft):
            VStack(alignment: .leading, spacing: 4) {
                if let label = draft.label, !label.isEmpty {
                    Text(label).font(.headline)
                } else {
                    Text("Phone Handoff").font(.headline)
                }
                Text("Number: \(draft.phoneNumber)").font(.caption)
                if let notes = draft.notes, !notes.isEmpty {
                    Text(notes).font(.caption)
                }
                Text("Phone opens visibly; the call still requires user action.").font(.caption).foregroundStyle(.secondary)
            }
        case .webSearch(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.query.isEmpty ? "Web Search Handoff" : draft.query).font(.headline)
                Text(draft.searchURL).font(.caption.monospaced()).textSelection(.enabled)
                Text("Safari opens visibly; Kairo does not browse or scrape pages silently.").font(.caption).foregroundStyle(.secondary)
            }
        case .notification(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title).font(.headline)
                Text(draft.body).font(.caption)
                if let deliveryDate = draft.deliveryDate { Text(deliveryDate, style: .time).font(.caption) }
            }
        case .url(let url):
            Text(url).font(.callout.monospaced()).textSelection(.enabled)
        case .homeControl(let request):
            VStack(alignment: .leading, spacing: 4) {
                Text(request.targetName).font(.headline)
                if let homeName = request.homeName { Text("Home: \(homeName)").font(.caption) }
                if let roomName = request.roomName { Text("Room: \(roomName)").font(.caption) }
                Text("Command: \(request.command.rawValue)").font(.caption)
                if let value = request.value {
                    Text("Value: \(value.displayValue)").font(.caption)
                }
            }
        case .unsupported(let explanation):
            VStack(alignment: .leading, spacing: 4) {
                Text(explanation.requestedAction).font(.headline)
                Text(explanation.reason).font(.caption)
                if let alternative = explanation.safeAlternative {
                    Text("Alternative: \(alternative)").font(.caption).foregroundStyle(.secondary)
                }
            }
        case .empty:
            EmptyView()
        }
    }
}

public struct CapabilityChipView: View {
    public let descriptor: SandboxActionDescriptor

    public init(descriptor: SandboxActionDescriptor) {
        self.descriptor = descriptor
    }

    public var body: some View {
        Text(descriptor.supportStatus.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(chipForeground)
            .background(chipBackground, in: Capsule())
    }

    private var chipForeground: Color {
        switch descriptor.supportStatus {
        case .implemented, .scaffolded:
            return .green
        case .requiresIntegration:
            return .orange
        case .unsupportedBySandbox:
            return .red
        }
    }

    private var chipBackground: Color {
        chipForeground.opacity(0.15)
    }
}

private extension HomeControlValue {
    var displayValue: String {
        switch self {
        case .bool(let value):
            return value ? "true" : "false"
        case .double(let value):
            return String(value)
        case .string(let value):
            return value
        }
    }
}

private extension MapDirectionsMode {
    var displayName: String {
        switch self {
        case .driving:
            return "Driving"
        case .walking:
            return "Walking"
        case .transit:
            return "Transit"
        }
    }
}
#endif
