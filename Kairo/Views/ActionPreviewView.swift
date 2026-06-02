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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title).font(.title2.bold())
                    if let descriptor {
                        Text(descriptor.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let descriptor {
                    CapabilityChipView(descriptor: descriptor)
                }
            }

            Text(action.rationale).foregroundStyle(.secondary)
            actionPayloadPreview
            Text("Risk: \(action.riskTier.rawValue)").font(.caption)

            HStack {
                Button(role: .cancel, action: onCancel) {
                    Text("Cancel")
                        .accessibilityIdentifier("chat.action.cancel.label")
                }
                    .accessibilityIdentifier("chat.action.cancel")
                Spacer()
                Button(action: onConfirm) {
                    Text(action.kind == .unsupportedSandboxAction ? "OK" : "Confirm")
                        .accessibilityIdentifier("chat.action.confirm.label")
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(descriptor?.supportStatus == .unsupportedBySandbox)
                    .accessibilityIdentifier("chat.action.confirm")
            }
        }
        .padding()
        .accessibilityIdentifier("chat.action-preview")
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
#endif
