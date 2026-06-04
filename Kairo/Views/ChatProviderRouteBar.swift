#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let isPrivateChatEnabled: Bool
    let canEdit: Bool
    let togglePrivateChat: () -> Void
    let setPreference: (ProviderRoutePreference) -> Void

    var body: some View {
        Menu {
            Button {
                togglePrivateChat()
            } label: {
                Label(
                    isPrivateChatEnabled ? KairoL10n.string("chat.mode.privateOff") : KairoL10n.string("chat.mode.privateOn"),
                    systemImage: isPrivateChatEnabled ? "lock.open" : "lock"
                )
            }
            .accessibilityIdentifier("chat.private-chat.toggle")

            Divider()

            if canEdit {
                ForEach(ProviderRoutePreference.settingsChoices, id: \.rawValue) { preference in
                    Button {
                        setPreference(preference)
                    } label: {
                        HStack {
                            Text(preference.chatControlTitle)
                            if status.preference == preference {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityIdentifier("chat.provider-route.preference.\(preference.rawValue)")
                }
            } else {
                Text(KairoL10n.string("chat.provider.route.settingsUnavailable"))
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isPrivateChatEnabled ? "lock.fill" : "shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPrivateChatEnabled ? KairoDesign.ink : .secondary)

                Text(modeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPrivateChatEnabled ? KairoDesign.ink : .secondary)

                Text("·")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)

                Image(systemName: status.warning == nil ? "bolt.horizontal.circle" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.warning == nil ? Color.secondary : Color.orange)

                Text(status.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("chat.provider-route.title")

                Spacer(minLength: 4)

                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("chat.provider-route.preference")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.primary.opacity(0.045), in: Capsule())
            .overlay(alignment: .topLeading) {
                if status.warning != nil {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityLabel(status.warning ?? "")
                        .accessibilityIdentifier("chat.provider-route.warning")
                }
            }
            .accessibilityIdentifier("chat.provider-route")
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KairoL10n.string("chat.mode.accessibilityStatus", modeTitle, status.title, status.detail))
        .accessibilityIdentifier("chat.provider-route")
    }

    private var modeTitle: String {
        isPrivateChatEnabled ? KairoL10n.string("chat.mode.private") : KairoL10n.string("chat.mode.standard")
    }
}
#endif
