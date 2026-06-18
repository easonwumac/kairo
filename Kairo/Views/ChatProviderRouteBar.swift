#if canImport(SwiftUI)
import SwiftUI

struct ChatProviderRouteBar: View {
    let status: ChatProviderRouteStatus
    let canEdit: Bool
    let openModelSettings: () -> Void
    let selectOption: (ChatProviderRouteOption) -> Void
    @State private var isPalettePresented = false

    var body: some View {
        routeContent
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isPalettePresented)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chat.provider-route")
    }

    @ViewBuilder
    private var routeContent: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 7) {
                routeStack
            }
        } else {
            routeStack
        }
    }

    private var routeStack: some View {
        VStack(spacing: 7) {
            routeHeader

            if isPalettePresented {
                routePalette
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var routeHeader: some View {
        HStack(spacing: 7) {
            Button {
                guard !status.options.isEmpty else {
                    isPalettePresented = false
                    openModelSettings()
                    return
                }
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
            .frame(maxWidth: .infinity)

            Button {
                isPalettePresented = false
                openModelSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.teal)
                    .frame(width: 34, height: 34)
                    .providerRouteGlassIcon(tint: KairoDesign.teal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(KairoL10n.string("settings.models.section"))
            .accessibilityIdentifier("chat.provider-route.settings")
        }
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

            Image(systemName: isPalettePresented ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KairoDesign.muted)
                .accessibilityIdentifier("chat.provider-route.preference")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .frame(height: 34)
        .providerRouteGlassCapsule(isInteractive: true)
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
                    systemImage: "lock.slash",
                    isSelected: false,
                    isEnabled: false
                )
                .accessibilityIdentifier("chat.provider-route.preference.unavailable")
            }
        }
        .padding(8)
        .providerRouteGlassPanel(cornerRadius: 18)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.provider-route.palette")
    }

    private func routePaletteRow(
        title: String,
        sourceTitle: String,
        systemImage: String,
        isSelected: Bool,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? KairoDesign.blue : (isEnabled ? KairoDesign.ink : KairoDesign.muted))
                .frame(width: 24, height: 24)
                .providerRouteGlassIcon(tint: isSelected ? KairoDesign.blue : KairoDesign.muted)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? KairoDesign.ink : KairoDesign.muted)
                .lineLimit(1)

            Text(sourceTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isEnabled ? KairoDesign.blue : KairoDesign.muted)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .providerRouteGlassTag(tint: isEnabled ? KairoDesign.blue : KairoDesign.muted)

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(KairoDesign.blue)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .opacity(isEnabled ? 1 : 0.66)
        .providerRouteGlassRow(
            tint: isSelected ? KairoDesign.blue : KairoDesign.muted,
            fallbackOpacity: isSelected ? 0.70 : 0.55,
            isInteractive: isEnabled
        )
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

private extension View {
    @ViewBuilder
    func providerRouteGlassCapsule(isInteractive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(.regular.tint(KairoDesign.elevatedSurface.opacity(0.12)).interactive(), in: .capsule)
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: KairoDesign.shadow.opacity(0.30), radius: 10, x: 0, y: 6)
            } else {
                self
                    .glassEffect(.regular.tint(KairoDesign.elevatedSurface.opacity(0.10)), in: .capsule)
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        } else {
            self
                .background(KairoDesign.elevatedSurface.opacity(0.72), in: Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func providerRouteGlassPanel(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(KairoDesign.elevatedSurface.opacity(0.12)), in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    shape.stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.34), radius: 14, x: 0, y: 9)
        } else {
            self
                .background(KairoDesign.elevatedSurface.opacity(0.72), in: shape)
                .overlay {
                    shape.stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 14, x: 0, y: 9)
        }
    }

    @ViewBuilder
    func providerRouteGlassRow(tint: Color, fallbackOpacity: Double, isInteractive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 12))
                    .overlay {
                        shape.stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
            } else {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: 12))
                    .overlay {
                        shape.stroke(Color.white.opacity(0.05), lineWidth: 1)
                    }
            }
        } else {
            self
                .background(KairoDesign.softSurface.opacity(fallbackOpacity), in: shape)
        }
    }

    @ViewBuilder
    func providerRouteGlassIcon(tint: Color) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint.opacity(0.10)), in: .circle)
        } else {
            self
                .background(KairoDesign.softSurface.opacity(0.55), in: Circle())
        }
    }

    @ViewBuilder
    func providerRouteGlassTag(tint: Color) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint.opacity(0.10)), in: .capsule)
        } else {
            self
                .background(KairoDesign.softSurface.opacity(0.65), in: Capsule())
        }
    }
}
#endif
