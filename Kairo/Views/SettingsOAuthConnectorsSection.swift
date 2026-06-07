#if canImport(SwiftUI)
import SwiftUI

struct SettingsOAuthConnectorsSection: View {
    enum Presentation {
        case detailed
        case compact
    }

    let connectorOptions: [OAuthConnectorLoginOption]
    @Binding var expandedConnectorDetails: Set<String>
    var presentation: Presentation = .detailed
    let authorizeConnector: (OAuthConnectorLoginOption) -> Void
    let disconnectConnector: (OAuthConnectorLoginOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation == .detailed {
                sectionHeader(title: KairoL10n.string("settings.oauth.section"))
            }

            KairoGroupedSurface {
                VStack(alignment: .leading, spacing: 0) {
                    if connectorOptions.isEmpty {
                        Text(KairoL10n.string("settings.oauth.empty"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }

                    ForEach(connectorOptions) { option in
                        if presentation == .compact {
                            compactConnectorRow(option)
                        } else {
                            connectorRow(option)
                        }
                        if option.id != connectorOptions.last?.id {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.oauth.connectors")
        }
    }

    @ViewBuilder
    private func compactConnectorRow(_ option: OAuthConnectorLoginOption) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: option.readiness == .connected ? "checkmark.seal.fill" : "person.crop.circle.badge.plus")
                .font(.headline)
                .foregroundStyle(statusColor(for: option.readiness))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).name")
            }

            Spacer(minLength: 8)

            compactConnectorAction(option)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.oauth.\(option.providerKey).row")
    }

    @ViewBuilder
    private func compactConnectorAction(_ option: OAuthConnectorLoginOption) -> some View {
        if option.readiness == .connected || option.readiness == .needsReauthorization {
            Button(KairoL10n.string("settings.oauth.disconnect"), role: .destructive) {
                disconnectConnector(option)
            }
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
            .accessibilityIdentifier("settings.oauth.\(option.providerKey).disconnect")
        } else if option.canStartAuthorization {
            Button(KairoL10n.string("settings.oauth.authorize")) {
                authorizeConnector(option)
            }
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true, isCompact: true))
            .accessibilityIdentifier("settings.oauth.\(option.providerKey).authorize")
        } else {
            Text(option.readiness.settingsStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func connectorRow(_ option: OAuthConnectorLoginOption) -> some View {
        let isExpanded = expandedConnectorDetails.contains(option.providerKey)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(option.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).name")

                Spacer()

                Text(option.readiness.settingsStatusText)
                    .font(.caption)
                    .foregroundStyle(statusColor(for: option.readiness))
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).status")

                Button {
                    toggleDetails(option.providerKey)
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? KairoL10n.string("settings.oauth.details.hide") : KairoL10n.string("settings.oauth.details.show"))
                .accessibilityIdentifier("settings.oauth.\(option.providerKey).details")
            }

            if isExpanded {
                connectorDetails(option)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.oauth.\(option.providerKey).row")
    }

    @ViewBuilder
    private func connectorDetails(_ option: OAuthConnectorLoginOption) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(option.accountDataBoundary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.oauth.\(option.providerKey).detail")

            if option.requiresBackendTokenExchange {
                Text(KairoL10n.string("settings.oauth.backendExchangeRequired"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).backend-exchange")
            }

            if option.canStartAuthorization || option.readiness == .connected {
                connectorActions(option)
            } else if option.readiness == .needsClientConfiguration {
                Text(KairoL10n.string("settings.oauth.clientNotConfigured"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func connectorActions(_ option: OAuthConnectorLoginOption) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
            if option.canStartAuthorization {
                Button(KairoL10n.string("settings.oauth.authorize")) {
                    authorizeConnector(option)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
                .accessibilityIdentifier("settings.oauth.\(option.providerKey).authorize")
            }

            if option.readiness == .connected || option.readiness == .needsReauthorization {
                Button(KairoL10n.string("settings.oauth.disconnect"), role: .destructive) {
                    disconnectConnector(option)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                .accessibilityIdentifier("settings.oauth.\(option.providerKey).disconnect")
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
    }

    private func toggleDetails(_ providerKey: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedConnectorDetails.contains(providerKey) {
                expandedConnectorDetails.remove(providerKey)
            } else {
                expandedConnectorDetails.insert(providerKey)
            }
        }
    }

    private func statusColor(for readiness: OAuthConnectorLoginReadiness) -> Color {
        switch readiness {
        case .connected:
            return .green
        case .readyToAuthorize:
            return .blue
        case .needsClientConfiguration:
            return .secondary
        case .needsReauthorization:
            return .orange
        }
    }
}
#endif
