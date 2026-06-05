#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let isPrivateChatEnabled: Bool
    let canEdit: Bool
    let setPreference: (ProviderRoutePreference) -> Void
    @State private var isPalettePresented = false

    var body: some View {
        VStack(spacing: 7) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    isPalettePresented.toggle()
                }
            } label: {
                routeBarLabel
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(KairoL10n.string("chat.mode.accessibilityStatus", modeTitle, status.title, status.detail))
            .accessibilityIdentifier("chat.provider-route")

            if isPalettePresented {
                routePalette
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isPalettePresented)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.provider-route")
    }

    private var modeTitle: String {
        isPrivateChatEnabled ? KairoL10n.string("chat.mode.private") : KairoL10n.string("chat.mode.standard")
    }

    private var routeBarLabel: some View {
        HStack(spacing: 8) {
            routePill(
                label: KairoL10n.string("chat.mode.label"),
                value: modeTitle,
                systemImage: isPrivateChatEnabled ? "lock.fill" : "shield",
                tint: isPrivateChatEnabled ? KairoDesign.ink : KairoDesign.muted
            )
            routePill(
                label: KairoL10n.string("chat.provider.route.label"),
                value: status.title,
                systemImage: status.warning == nil ? "bolt.horizontal.circle" : "exclamationmark.triangle.fill",
                tint: status.warning == nil ? KairoDesign.blue : KairoDesign.amber
            )
            .accessibilityIdentifier("chat.provider-route.title")
            Spacer(minLength: 4)

            Image(systemName: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KairoDesign.muted)
                .accessibilityIdentifier("chat.provider-route.preference")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(KairoDesign.elevatedSurface.opacity(0.72), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            if status.warning != nil {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityLabel(status.warning ?? "")
                    .accessibilityIdentifier("chat.provider-route.warning")
            }
        }
    }

    private var routePalette: some View {
        VStack(spacing: 7) {
            if canEdit {
                ForEach(ProviderRoutePreference.settingsChoices, id: \.rawValue) { preference in
                    Button {
                        setPreference(preference)
                        isPalettePresented = false
                    } label: {
                        routePaletteRow(
                            title: preference.chatControlTitle,
                            systemImage: "bolt.horizontal.circle",
                            isSelected: status.preference == preference
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat.provider-route.preference.\(preference.rawValue)")
                }
            } else {
                routePaletteRow(
                    title: KairoL10n.string("chat.provider.route.settingsUnavailable"),
                    systemImage: "lock.slash",
                    isSelected: false
                )
                .accessibilityIdentifier("chat.provider-route.preference.unavailable")
            }
        }
        .padding(8)
        .background(KairoDesign.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 14, x: 0, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.provider-route.palette")
    }

    private func routePaletteRow(title: String, systemImage: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? KairoDesign.blue : KairoDesign.ink)
                .frame(width: 30, height: 30)
                .background(KairoDesign.softSurface.opacity(0.55), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(KairoDesign.blue)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KairoDesign.softSurface.opacity(isSelected ? 0.70 : 0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func routePill(label: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(KairoDesign.muted)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
    }
}
#endif
