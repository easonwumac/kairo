#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum KairoAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case dark
    case light
    case warm

    static let storageKey = "kairo.appearance.preference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return KairoL10n.string("settings.appearance.system")
        case .dark:
            return KairoL10n.string("settings.appearance.dark")
        case .light:
            return KairoL10n.string("settings.appearance.light")
        case .warm:
            return KairoL10n.string("settings.appearance.warm")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        case .warm:
            return .light
        }
    }

    static var current: KairoAppearancePreference {
        let storedValue = UserDefaults.standard.string(forKey: storageKey)
        return storedValue.flatMap(KairoAppearancePreference.init(rawValue:)) ?? .system
    }
}

enum KairoDesign {
    static let rootChromeTopPadding: CGFloat = 86
    static let rootChromeContentTopPadding: CGFloat = rootChromeTopPadding + 32
    static let rootChromeNavigationStackContentTopPadding: CGFloat = 0

    static var ink: Color {
        color(
            light: (0.08, 0.12, 0.18, 1.00),
            dark: (0.92, 0.96, 1.00, 1.00),
            warm: (0.16, 0.13, 0.10, 1.00)
        )
    }

    static var muted: Color {
        color(
            light: (0.42, 0.49, 0.60, 1.00),
            dark: (0.58, 0.66, 0.76, 1.00),
            warm: (0.50, 0.45, 0.37, 1.00)
        )
    }

    static var background: Color {
        color(
            light: (0.92, 0.96, 1.00, 1.00),
            dark: (0.035, 0.055, 0.085, 1.00),
            warm: (0.925, 0.905, 0.855, 1.00)
        )
    }

    static var groupedSurface: Color {
        color(
            light: (0.96, 0.985, 1.00, 0.92),
            dark: (0.075, 0.105, 0.145, 0.92),
            warm: (0.965, 0.945, 0.895, 0.90)
        )
    }

    static var elevatedSurface: Color {
        color(
            light: (0.985, 0.995, 1.00, 0.94),
            dark: (0.105, 0.145, 0.195, 0.94),
            warm: (0.985, 0.965, 0.915, 0.92)
        )
    }

    static var softSurface: Color {
        color(
            light: (0.90, 0.95, 1.00, 1.00),
            dark: (0.12, 0.17, 0.23, 1.00),
            warm: (0.88, 0.855, 0.79, 1.00)
        )
    }

    static var line: Color {
        color(
            light: (0.00, 0.00, 0.00, 0.08),
            dark: (1.00, 1.00, 1.00, 0.10),
            warm: (0.22, 0.16, 0.08, 0.10)
        )
    }

    static var teal: Color {
        color(
            light: (0.38, 0.87, 0.73, 1.00),
            dark: (0.32, 0.80, 0.68, 1.00),
            warm: (0.35, 0.68, 0.52, 1.00)
        )
    }
    static var blue: Color {
        color(
            light: (0.29, 0.43, 0.86, 1.00),
            dark: (0.42, 0.55, 0.92, 1.00),
            warm: (0.22, 0.38, 0.72, 1.00)
        )
    }
    static var amber: Color { Color(.sRGB, red: 1.00, green: 0.72, blue: 0.42, opacity: 1) }
    static var red: Color {
        color(
            light: (0.90, 0.20, 0.25, 1.00),
            dark: (0.85, 0.25, 0.28, 1.00),
            warm: (0.80, 0.32, 0.28, 1.00)
        )
    }
    static var green: Color { Color(.sRGB, red: 0.11, green: 0.55, blue: 0.38, opacity: 1) }
    static var violet: Color {
        color(
            light: (0.45, 0.35, 0.82, 1.00),
            dark: (0.62, 0.52, 0.92, 1.00),
            warm: (0.55, 0.42, 0.68, 1.00)
        )
    }

    static func onColor(isOn: Bool) -> Color {
        if isOn {
            return KairoDesign.blue.opacity(0.32)
        }
        return KairoDesign.elevatedSurface
    }

    static func warmOnColor(isOn: Bool) -> Color {
        if isOn {
            return KairoDesign.amber.opacity(0.45)
        }
        return KairoDesign.softSurface
    }

    static var shadow: Color {
        color(
            light: (0.00, 0.00, 0.00, 0.12),
            dark: (0.00, 0.00, 0.00, 0.30),
            warm: (0.22, 0.16, 0.08, 0.14)
        )
    }

    static var topGlow: Color {
        color(
            light: (0.29, 0.43, 0.86, 0.16),
            dark: (0.29, 0.43, 0.86, 0.26),
            warm: (1.00, 0.74, 0.38, 0.20)
        )
    }

    static var secondaryGlow: Color {
        color(
            light: (0.38, 0.87, 0.73, 0.12),
            dark: (0.38, 0.87, 0.73, 0.10),
            warm: (0.90, 0.58, 0.26, 0.10)
        )
    }

    static var bottomShade: Color {
        color(
            light: (1.00, 1.00, 1.00, 0.20),
            dark: (0.00, 0.00, 0.00, 0.18),
            warm: (0.78, 0.70, 0.58, 0.18)
        )
    }

    private static func color(
        light: (red: Double, green: Double, blue: Double, opacity: Double),
        dark: (red: Double, green: Double, blue: Double, opacity: Double),
        warm: (red: Double, green: Double, blue: Double, opacity: Double)? = nil
    ) -> Color {
        switch KairoAppearancePreference.current {
        case .light:
            return fixedColor(light)
        case .dark:
            return fixedColor(dark)
        case .warm:
            return fixedColor(warm ?? light)
        case .system:
            #if canImport(UIKit)
            return Color(UIColor { traitCollection in
                let palette = traitCollection.userInterfaceStyle == .light ? light : dark
                return UIColor(
                    red: palette.red,
                    green: palette.green,
                    blue: palette.blue,
                    alpha: palette.opacity
                )
            })
            #elseif canImport(AppKit)
            return Color(NSColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
                let palette = bestMatch == .aqua ? light : dark
                return NSColor(
                    red: palette.red,
                    green: palette.green,
                    blue: palette.blue,
                    alpha: palette.opacity
                )
            })
            #else
            return fixedColor(dark)
            #endif
        }
    }

    private static func fixedColor(_ palette: (red: Double, green: Double, blue: Double, opacity: Double)) -> Color {
        Color(.sRGB, red: palette.red, green: palette.green, blue: palette.blue, opacity: palette.opacity)
    }
}

extension View {
    @ViewBuilder
    func kairoHiddenNavigationChrome() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

struct KairoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(KairoDesign.elevatedSurface)

            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(KairoDesign.teal)
                .offset(y: -size * 0.02)

            Circle()
                .fill(KairoDesign.amber)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.24, y: -size * 0.22)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct KairoStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct KairoFocusCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .shadow(color: KairoDesign.shadow, radius: 22, x: 0, y: 12)
    }
}

struct KairoCommandButton: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct KairoGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var tint: Color = KairoDesign.blue
    var isProminent = false
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            liquidGlassBody(configuration: configuration)
        } else {
            fallbackBody(configuration: configuration)
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func liquidGlassBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? KairoDesign.ink : tint)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 32 : 38)
            .padding(.horizontal, isCompact ? 10 : 12)
            .glassEffect(
                .regular
                    .tint((isProminent ? tint : KairoDesign.groupedSurface).opacity(isProminent ? 0.22 : 0.10))
                    .interactive(isEnabled),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(KairoDesign.line.opacity(isProminent ? 0.72 : 0.48), lineWidth: 1)
            }
            .shadow(color: KairoDesign.shadow.opacity(isProminent ? 0.26 : 0.14), radius: isProminent ? 12 : 7, x: 0, y: isProminent ? 7 : 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.42)
    }

    private func fallbackBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? KairoDesign.ink : tint)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 32 : 38)
            .padding(.horizontal, isCompact ? 10 : 12)
            .background(background(configuration: configuration), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(KairoDesign.line.opacity(isProminent ? 1 : 0.8), lineWidth: 1)
            }
            .shadow(color: KairoDesign.shadow.opacity(isProminent ? 0.45 : 0.24), radius: isProminent ? 14 : 8, x: 0, y: isProminent ? 8 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.42)
    }

    private func background(configuration: Configuration) -> Color {
        let pressedOpacity = configuration.isPressed ? 0.72 : 1
        if isProminent {
            return KairoDesign.softSurface.opacity(0.82 * pressedOpacity)
        }
        return KairoDesign.groupedSurface.opacity(0.72 * pressedOpacity)
    }
}

struct KairoActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let trailingText: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        trailingText: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.trailingText = trailingText
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

struct KairoGroupedSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .kairoGroupedGlassSurface()
    }
}

private extension View {
    @ViewBuilder
    func kairoGroupedGlassSurface() -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(
                    .regular
                        .tint(KairoDesign.groupedSurface.opacity(0.10)),
                    in: .rect(cornerRadius: 18)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                }
        } else {
            self
                .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(KairoDesign.line, lineWidth: 1)
                }
        }
    }
}
#endif
