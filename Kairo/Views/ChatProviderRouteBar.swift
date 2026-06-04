#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let canEdit: Bool
    let setPreference: (ProviderRoutePreference) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.warning == nil ? "bolt.horizontal.circle" : "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.warning == nil ? Color.secondary : Color.orange)

            Text(status.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("chat.provider-route.title")

            routePreferenceMenu
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.primary.opacity(0.045), in: Capsule())
        .overlay(alignment: .topLeading) {
            if status.warning != nil {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityLabel(status.warning ?? "")
                    .accessibilityIdentifier("chat.provider-route.warning")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KairoL10n.string("chat.provider.route.accessibilityStatus", status.title, status.detail))
        .accessibilityIdentifier("chat.provider-route")
    }

    private var routePreferenceMenu: some View {
        Menu {
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
            Image(systemName: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .disabled(!canEdit)
        .accessibilityLabel(KairoL10n.string("chat.provider.route.accessibility"))
        .accessibilityIdentifier("chat.provider-route.preference")
    }
}
#endif
