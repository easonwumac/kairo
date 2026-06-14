#if canImport(SwiftUI)
import SwiftUI

public struct ActionPreviewView: View {
    @State private var showPayloadDetails = false

    public let action: AgentAction
    public let descriptor: SandboxActionDescriptor?
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    public init(
        action: AgentAction,
        descriptor: SandboxActionDescriptor? = nil,
        descriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider(),
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.action = action
        self.descriptor = descriptor ?? descriptorProvider.descriptor(for: action.kind)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        ScrollView {
            previewContent
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(KairoDesign.background.ignoresSafeArea())
        .accessibilityLabel(KairoL10n.string("chat.action.preview.title"))
        .accessibilityHint(KairoL10n.string("chat.action.preview.safetyNote"))
        .accessibilityIdentifier("chat.action-preview")
    }

    @ViewBuilder
    private var previewContent: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                previewStack
            }
        } else {
            previewStack
        }
    }

    private var previewStack: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            outcomeHeroCard
            actionButtons

            payloadDetailsCard
            reviewChecklistCard
        }
    }

    private var outcomeHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: action.kind == .unsupportedSandboxAction ? "exclamationmark.triangle.fill" : primaryActionIcon)
                    .font(.title2)
                    .foregroundStyle(action.kind == .unsupportedSandboxAction ? KairoDesign.red : KairoDesign.teal)
                    .frame(width: 44, height: 44)
                    .background((action.kind == .unsupportedSandboxAction ? KairoDesign.red : KairoDesign.teal).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(KairoL10n.string("chat.action.preview.outcomeLabel"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(primaryActionSummary)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("chat.action.outcome")
                    Text(outcomeDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                KairoStatusPill(title: destinationLabel, systemImage: "arrow.up.right.square.fill", tint: KairoDesign.violet)
                KairoStatusPill(title: riskLabel, systemImage: "gauge.medium", tint: riskColor)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .actionPreviewGlassSurface(
            cornerRadius: 20,
            tint: action.kind == .unsupportedSandboxAction ? KairoDesign.red : KairoDesign.teal
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(role: .cancel, action: onCancel) {
                Text(KairoL10n.string("chat.action.preview.cancel"))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("chat.action.cancel.label")
            }
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.muted))
            .accessibilityIdentifier("chat.action.cancel")

            Button(action: onConfirm) {
                Text(KairoL10n.string(action.kind == .unsupportedSandboxAction ? "chat.action.preview.dismiss" : "chat.action.preview.confirm"))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("chat.action.confirm.label")
            }
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true))
            .disabled(descriptor?.supportStatus == .unsupportedBySandbox)
            .accessibilityIdentifier("chat.action.confirm")
        }
    }

    private var payloadDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    showPayloadDetails.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.blue)
                        .frame(width: 28, height: 28)
                        .background(KairoDesign.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(KairoL10n.string("chat.action.preview.field.payload"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: showPayloadDetails ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chat.action.payload.toggle")
            .accessibilityLabel(showPayloadDetails ? KairoL10n.string("chat.action.preview.payload.hide") : KairoL10n.string("chat.action.preview.payload.show"))

            if showPayloadDetails {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(KairoL10n.string("chat.action.preview.payloadDetail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    actionPayloadPreview
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("chat.action.payload.details")
            }
        }
        .padding(14)
        .actionPreviewGlassSurface(cornerRadius: 18, tint: KairoDesign.blue, isInteractive: true)
    }

    private var reviewChecklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            checklistRow(
                title: KairoL10n.string("chat.action.preview.field.confirmation"),
                value: confirmationLabel,
                systemImage: "hand.tap.fill",
                tint: riskColor
            )

            if let descriptor {
                checklistRow(
                    title: KairoL10n.string("chat.action.preview.field.capability"),
                    value: descriptor.displayName,
                    systemImage: "wrench.and.screwdriver.fill",
                    tint: KairoDesign.blue
                )
            }

            checklistRow(
                title: KairoL10n.string("chat.action.preview.field.why"),
                value: action.rationale,
                systemImage: "text.bubble.fill",
                tint: KairoDesign.teal
            )
        }
        .padding(14)
        .actionPreviewGlassSurface(cornerRadius: 18, tint: riskColor)
        .accessibilityIdentifier("chat.action.safety")
    }

    private var primaryActionSummary: String {
        switch action.payload {
        case .text(let text):
            return text.isEmpty ? action.title : text
        case .reminder(let draft):
            return draft.title.isEmpty ? action.title : draft.title
        case .calendarEvent(let draft):
            return draft.title.isEmpty ? action.title : draft.title
        case .contact(let draft):
            return draft.displayName.isEmpty ? KairoL10n.string("chat.action.preview.contactFallback") : draft.displayName
        case .email(let draft):
            return draft.subject.isEmpty ? KairoL10n.string("chat.action.preview.emailDraftFallback") : draft.subject
        case .mapDirections(let draft):
            return draft.destinationQuery.isEmpty ? KairoL10n.string("chat.action.preview.mapsDestinationFallback") : draft.destinationQuery
        case .message(let draft):
            return draft.recipients.isEmpty ? KairoL10n.string("chat.action.preview.messagesFallback") : draft.recipients.joined(separator: ", ")
        case .phoneCall(let draft):
            if let label = draft.label, !label.isEmpty { return label }
            return draft.phoneNumber.isEmpty ? KairoL10n.string("chat.action.preview.phoneFallback") : draft.phoneNumber
        case .webSearch(let draft):
            return draft.query.isEmpty ? KairoL10n.string("chat.action.preview.webFallback") : draft.query
        case .notification(let draft):
            return draft.title.isEmpty ? action.title : draft.title
        case .url(let url):
            return url
        case .homeControl(let request):
            return request.targetName
        case .unsupported(let explanation):
            return explanation.requestedAction
        case .empty:
            return action.title
        }
    }

    private var outcomeDetail: String {
        if descriptor?.supportStatus == .unsupportedBySandbox {
            return KairoL10n.string("chat.action.preview.outcomeUnavailable")
        }
        return KairoL10n.string("chat.action.preview.outcomeDetail", destinationLabel)
    }

    private var primaryActionIcon: String {
        switch action.payload {
        case .reminder:
            return "checklist"
        case .calendarEvent:
            return "calendar.badge.plus"
        case .contact:
            return "person.crop.circle.badge.plus"
        case .email:
            return "envelope.open.fill"
        case .mapDirections:
            return "map.fill"
        case .message:
            return "message.fill"
        case .phoneCall:
            return "phone.fill"
        case .webSearch:
            return "safari.fill"
        case .notification:
            return "bell.badge.fill"
        case .homeControl:
            return "house.fill"
        case .text:
            return "text.bubble.fill"
        case .url:
            return "link"
        case .unsupported, .empty:
            return "checkmark.shield.fill"
        }
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
            return KairoL10n.string("chat.action.risk.savesMemory")
        case .createReminderDraft:
            return KairoL10n.string("chat.action.risk.createsReminder")
        case .createCalendarDraft:
            return KairoL10n.string("chat.action.risk.createsCalendar")
        case .createContactDraft:
            return KairoL10n.string("chat.action.risk.createsContact")
        case .sendNotification:
            return KairoL10n.string("chat.action.risk.schedulesNotification")
        default:
            break
        }
        switch action.riskTier {
        case .tier0ReadOnly:
            return KairoL10n.string("chat.action.risk.readOnly")
        case .tier1Draft:
            return KairoL10n.string("chat.action.risk.draftOrHandoff")
        case .tier2LowRiskWrite:
            return KairoL10n.string("chat.action.risk.writesLocalData")
        case .tier3HighRiskExternal:
            return KairoL10n.string("chat.action.risk.externalAccountAction")
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

    private func checklistRow(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            reviewField(title: title, value: value)
        }
    }

    private var destinationLabel: String {
        switch action.payload {
        case .reminder:
            return KairoL10n.string("chat.action.preview.destination.reminders")
        case .calendarEvent:
            return KairoL10n.string("chat.action.preview.destination.calendar")
        case .contact:
            return KairoL10n.string("chat.action.preview.destination.contacts")
        case .email:
            return KairoL10n.string("chat.action.preview.destination.mail")
        case .mapDirections:
            return KairoL10n.string("chat.action.preview.destination.maps")
        case .message:
            return KairoL10n.string("chat.action.preview.destination.messages")
        case .phoneCall:
            return KairoL10n.string("chat.action.preview.destination.phone")
        case .webSearch:
            return KairoL10n.string("chat.action.preview.destination.safari")
        case .notification:
            return KairoL10n.string("chat.action.preview.destination.notifications")
        case .homeControl:
            return KairoL10n.string("chat.action.preview.destination.home")
        case .text:
            return KairoL10n.string("chat.action.preview.destination.kairo")
        case .url:
            return KairoL10n.string("chat.action.preview.destination.url")
        case .unsupported, .empty:
            return KairoL10n.string("chat.action.preview.destination.none")
        }
    }

    private var confirmationLabel: String {
        descriptor?.supportStatus == .unsupportedBySandbox
            ? KairoL10n.string("chat.action.preview.confirmation.unavailable")
            : KairoL10n.string("chat.action.preview.confirmation.required")
    }

    @ViewBuilder
    private var actionPayloadPreview: some View {
        switch action.payload {
        case .text(let text):
            Text(text)
                .font(.callout)
                .padding(10)
                .actionPreviewGlassSurface(cornerRadius: 10, tint: KairoDesign.blue)
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
                Text(draft.displayName.isEmpty ? KairoL10n.string("chat.action.preview.contactFallback") : draft.displayName).font(.headline)
                if !draft.phoneNumbers.isEmpty {
                    Text(KairoL10n.string("chat.action.preview.phoneLabel", draft.phoneNumbers.joined(separator: ", "))).font(.caption)
                }
                if !draft.emailAddresses.isEmpty {
                    Text(KairoL10n.string("chat.action.preview.emailLabel", draft.emailAddresses.joined(separator: ", "))).font(.caption)
                }
                if let notes = draft.notes { Text(notes).font(.caption) }
            }
        case .email(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.subject.isEmpty ? KairoL10n.string("chat.action.preview.emailDraftFallback") : draft.subject).font(.headline)
                if !draft.to.isEmpty {
                    Text(KairoL10n.string("chat.action.preview.toLabel", draft.to.joined(separator: ", "))).font(.caption)
                }
                if !draft.cc.isEmpty {
                    Text(KairoL10n.string("chat.action.preview.ccLabel", draft.cc.joined(separator: ", "))).font(.caption)
                }
                if !draft.body.isEmpty {
                    Text(draft.body).font(.caption)
                }
            }
        case .mapDirections(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.destinationQuery.isEmpty ? KairoL10n.string("chat.action.preview.mapsDestinationFallback") : draft.destinationQuery).font(.headline)
                Text(KairoL10n.string("chat.action.preview.modeLabel", draft.mode.displayName)).font(.caption)
                Text(KairoL10n.string("chat.action.preview.mapsVisibleHandoff")).font(.caption).foregroundStyle(.secondary)
            }
        case .message(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.recipients.isEmpty ? KairoL10n.string("chat.action.preview.messagesFallback") : draft.recipients.joined(separator: ", ")).font(.headline)
                if !draft.body.isEmpty {
                    Text(draft.body).font(.caption)
                }
                Text(KairoL10n.string("chat.action.preview.messagesVisibleHandoff")).font(.caption).foregroundStyle(.secondary)
            }
        case .phoneCall(let draft):
            VStack(alignment: .leading, spacing: 4) {
                if let label = draft.label, !label.isEmpty {
                    Text(label).font(.headline)
                } else {
                    Text(KairoL10n.string("chat.action.preview.phoneFallback")).font(.headline)
                }
                Text(KairoL10n.string("chat.action.preview.numberLabel", draft.phoneNumber)).font(.caption)
                if let notes = draft.notes, !notes.isEmpty {
                    Text(notes).font(.caption)
                }
                Text(KairoL10n.string("chat.action.preview.phoneVisibleHandoff")).font(.caption).foregroundStyle(.secondary)
            }
        case .webSearch(let draft):
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.query.isEmpty ? KairoL10n.string("chat.action.preview.webFallback") : draft.query).font(.headline)
                Text(draft.searchURL).font(.caption.monospaced()).textSelection(.enabled)
                Text(KairoL10n.string("chat.action.preview.webVisibleHandoff")).font(.caption).foregroundStyle(.secondary)
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
                if let homeName = request.homeName { Text(KairoL10n.string("chat.action.preview.homeLabel", homeName)).font(.caption) }
                if let roomName = request.roomName { Text(KairoL10n.string("chat.action.preview.roomLabel", roomName)).font(.caption) }
                Text(KairoL10n.string("chat.action.preview.commandLabel", request.command.rawValue)).font(.caption)
                if let value = request.value {
                    Text(KairoL10n.string("chat.action.preview.valueLabel", value.displayValue)).font(.caption)
                }
            }
        case .unsupported(let explanation):
            VStack(alignment: .leading, spacing: 4) {
                Text(explanation.requestedAction).font(.headline)
                Text(explanation.reason).font(.caption)
                if let alternative = explanation.safeAlternative {
                    Text(KairoL10n.string("chat.action.preview.alternativeLabel", alternative)).font(.caption).foregroundStyle(.secondary)
                }
            }
        case .empty:
            EmptyView()
        }
    }
}

private extension View {
    @ViewBuilder
    func actionPreviewGlassSurface(cornerRadius: CGFloat, tint: Color, isInteractive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.12)).interactive(), in: .rect(cornerRadius: cornerRadius))
                    .overlay(shape.stroke(KairoDesign.line.opacity(0.55), lineWidth: 1))
            } else {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: cornerRadius))
                    .overlay(shape.stroke(KairoDesign.line.opacity(0.45), lineWidth: 1))
            }
        } else {
            self
                .background(KairoDesign.elevatedSurface.opacity(0.76), in: shape)
                .overlay(shape.stroke(KairoDesign.line.opacity(0.7), lineWidth: 1))
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
            return KairoL10n.string(value ? "chat.action.preview.value.bool.true" : "chat.action.preview.value.bool.false")
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
            return KairoL10n.string("chat.action.preview.mode.driving")
        case .walking:
            return KairoL10n.string("chat.action.preview.mode.walking")
        case .transit:
            return KairoL10n.string("chat.action.preview.mode.transit")
        }
    }
}
#endif
