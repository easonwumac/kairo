#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let canEdit: Bool
    let setPreference: (ProviderRoutePreference) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(status.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .accessibilityIdentifier("chat.provider-route.title")

            if status.warning != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityLabel(status.warning ?? "")
                    .accessibilityIdentifier("chat.provider-route.warning")
            }

            Spacer(minLength: 4)

            routePreferenceMenu
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(status.title). \(status.detail)")
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
                            Text(preference.settingsTitle)
                            if status.preference == preference {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityIdentifier("chat.provider-route.preference.\(preference.rawValue)")
                }
            } else {
                Text("Route settings unavailable")
            }
        } label: {
            Label("Route", systemImage: "slider.horizontal.3")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .frame(height: 34)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .disabled(!canEdit)
        .accessibilityLabel("Chat route")
        .accessibilityIdentifier("chat.provider-route.preference")
    }
}
#endif
