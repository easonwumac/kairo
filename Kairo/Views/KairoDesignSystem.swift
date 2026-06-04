#if canImport(SwiftUI)
import SwiftUI

enum KairoDesign {
    static let ink = Color(.sRGB, red: 0.07, green: 0.10, blue: 0.16, opacity: 1)
    static let muted = Color(.sRGB, red: 0.33, green: 0.38, blue: 0.45, opacity: 1)
    static let background = Color(.sRGB, red: 0.955, green: 0.965, blue: 0.972, opacity: 1)
    static let groupedSurface = Color(.sRGB, red: 0.995, green: 0.997, blue: 1.00, opacity: 0.96)
    static let elevatedSurface = Color(.sRGB, red: 1.00, green: 1.00, blue: 1.00, opacity: 0.98)
    static let softSurface = Color(.sRGB, red: 0.92, green: 0.945, blue: 0.955, opacity: 1)
    static let line = Color.black.opacity(0.07)
    static let teal = Color(.sRGB, red: 0.38, green: 0.87, blue: 0.73, opacity: 1)
    static let blue = Color(.sRGB, red: 0.29, green: 0.43, blue: 0.86, opacity: 1)
    static let amber = Color(.sRGB, red: 1.00, green: 0.72, blue: 0.42, opacity: 1)
    static let red = Color(.sRGB, red: 0.90, green: 0.20, blue: 0.25, opacity: 1)
    static let green = Color(.sRGB, red: 0.11, green: 0.55, blue: 0.38, opacity: 1)
    static let violet = Color(.sRGB, red: 0.45, green: 0.35, blue: 0.82, opacity: 1)
    static let shadow = Color.black.opacity(0.08)
}

struct KairoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(KairoDesign.ink)

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
    let subtitle: String
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
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
    }
}
#endif
