#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let canEdit: Bool
    let selectOption: (ChatProviderRouteOption) -> Void
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
            .accessibilityLabel(KairoL10n.string("chat.provider.route.accessibilityStatus", status.title, status.detail))
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

    private var routeBarLabel: some View {
        HStack(spacing: 8) {
            routePill(
                label: KairoL10n.string("chat.provider.model.label"),
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
                ForEach(status.options) { option in
                    Button {
                        selectOption(option)
                        isPalettePresented = false
                    } label: {
                        routePaletteRow(
                            title: option.title,
                            sourceTitle: option.sourceTitle,
                            detail: option.detail,
                            systemImage: option.systemImage,
                            isSelected: status.selectedOptionID == option.id,
                            isEnabled: option.isEnabled
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.isEnabled)
                    .accessibilityIdentifier("chat.provider-route.option.\(option.id)")
                }
            } else {
                routePaletteRow(
                    title: KairoL10n.string("chat.provider.route.settingsUnavailable"),
                    sourceTitle: KairoL10n.string("chat.provider.model.label"),
                    detail: KairoL10n.string("chat.provider.route.settingsUnavailable"),
                    systemImage: "lock.slash",
                    isSelected: false,
                    isEnabled: false
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

    private func routePaletteRow(
        title: String,
        sourceTitle: String,
        detail: String,
        systemImage: String,
        isSelected: Bool,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? KairoDesign.blue : (isEnabled ? KairoDesign.ink : KairoDesign.muted))
                .frame(width: 30, height: 30)
                .background(KairoDesign.softSurface.opacity(0.55), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isEnabled ? KairoDesign.ink : KairoDesign.muted)
                        .lineLimit(1)

                    Text(sourceTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isEnabled ? KairoDesign.blue : KairoDesign.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(KairoDesign.softSurface.opacity(0.65), in: Capsule())
                }

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(KairoDesign.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(KairoDesign.blue)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .opacity(isEnabled ? 1 : 0.66)
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
