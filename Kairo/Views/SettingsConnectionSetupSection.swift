#if canImport(SwiftUI)
import SwiftUI

struct SettingsConnectionSetupSection<Content: View>: View {
    @Binding var showsConnectionSetup: Bool
    @Binding var showsConnectionDetails: Bool

    let hasAPIKey: Bool
    let connectedConnectorCount: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                setupToggle

                if showsConnectionSetup {
                    detailsToggle

                    if showsConnectionDetails {
                        connectionDetails
                    }

                    Divider()
                    content()
                }
            }
        }
    }

    private var setupToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                showsConnectionSetup.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(KairoL10n.string("settings.connection.section"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                }

                Spacer(minLength: 8)

                Image(systemName: showsConnectionSetup ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)
                    .frame(width: 36, height: 36)
                    .background(KairoDesign.blue.opacity(0.10), in: Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsConnectionSetup ? KairoL10n.string("settings.connection.hide") : KairoL10n.string("settings.connection.show"))
        .accessibilityIdentifier("settings.connection.toggle")
    }

    private var detailsToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                showsConnectionDetails.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: showsConnectionDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(KairoL10n.string("settings.connection.details.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.connection.details.toggle")
    }

    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KairoStatusPill(
                    title: hasAPIKey ? KairoL10n.string("settings.openai.status.configured") : KairoL10n.string("settings.openai.status.notConfigured"),
                    systemImage: "key.fill",
                    tint: hasAPIKey ? KairoDesign.green : KairoDesign.amber
                )
                KairoStatusPill(
                    title: KairoL10n.string("settings.routing.connectedAccounts", Int64(connectedConnectorCount)),
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: connectedConnectorCount > 0 ? KairoDesign.green : KairoDesign.violet
                )
            }
        }
    }
}
#endif
