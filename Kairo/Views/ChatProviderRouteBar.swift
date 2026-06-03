#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let canEdit: Bool
    let setPreference: (ProviderRoutePreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)

                Text(status.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("chat.provider-route.title")

                Spacer(minLength: 8)

                Text(status.badge)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
                    .accessibilityIdentifier("chat.provider-route.badge")
            }

            Text(status.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("chat.provider-route.detail")

            if let warning = status.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat.provider-route.warning")
            }

            routePreferenceControls
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.sRGB, white: 0.985, opacity: 1))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.provider-route")
    }

    private var routePreferenceControls: some View {
        HStack(spacing: 6) {
            ForEach(ProviderRoutePreference.settingsChoices, id: \.rawValue) { preference in
                routePreferenceButton(preference, isSelected: status.preference == preference)
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.provider-route.preference")
    }

    private func routePreferenceButton(_ preference: ProviderRoutePreference, isSelected: Bool) -> some View {
        Button {
            setPreference(preference)
        } label: {
            Text(preference.chatControlTitle)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(minWidth: 52)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(routePreferenceBackground(isSelected: isSelected), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
        .accessibilityLabel("Set chat route to \(preference.settingsTitle)")
        .accessibilityIdentifier("chat.provider-route.preference.\(preference.rawValue)")
    }

    private func routePreferenceBackground(isSelected: Bool) -> Color {
        isSelected ? Color.accentColor : Color.primary.opacity(0.07)
    }
}
#endif
