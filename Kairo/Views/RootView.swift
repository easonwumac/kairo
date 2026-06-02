#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
    private let environment: KairoEnvironment
    @State private var selectedSection: RootSection = .chat
    @State private var isDrawerOpen = false

    public init(environment: KairoEnvironment = .preview()) {
        self.environment = environment
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Self.fullScreenBackground
                .ignoresSafeArea()

            shellMarker

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .safeAreaInset(edge: .top, spacing: 0) {
                    rootHeader
                }

            if isDrawerOpen {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("root.drawer.scrim")
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isDrawerOpen = false
                        }
                    }
            }

            if isDrawerOpen {
                drawer
                    .transition(.move(edge: .leading))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.fullScreenBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.22), value: isDrawerOpen)
        .onOpenURL { url in
            guard let oauthCallbackStore = environment.oauthConnectorCallbackStore else { return }
            Task {
                _ = try? await OAuthConnectorLoginCenter(
                    registry: IntegrationRegistry(),
                    credentialStore: environment.credentialStore,
                    callbackStore: oauthCallbackStore
                )
                .previewCallback(url)
            }
        }
    }

    private var shellMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kairo root shell")
            .accessibilityIdentifier("root.shell")
    }

    private static var fullScreenBackground: Color {
        Color(.sRGB, white: 0.98, opacity: 1)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .chat:
            ChatView(environment: environment)
        case .memory:
            MemoryCenterView(store: environment.memoryStore)
        case .automations:
            AutomationsView(
                recipeStore: environment.kairoRecipeStore,
                memoryStore: environment.memoryStore,
                aiProvider: environment.aiProvider
            )
        case .access:
            PermissionHubView(
                skillManagerService: environment.agentSkillManagerService,
                marketplaceCatalogService: environment.agentSkillMarketplaceCatalogService
            )
        case .settings:
            SettingsView(
                settingsService: OpenAISettingsService(credentialStore: environment.credentialStore),
                credentialStore: environment.credentialStore,
                oauthCallbackStore: environment.oauthConnectorCallbackStore,
                localModelCatalog: environment.localModelCatalog,
                localModelCatalogService: environment.localModelCatalogService,
                localModelSettingsService: environment.localModelSettingsService,
                localModelDownloader: environment.localModelDownloader,
                localModelBenchmarkService: environment.localModelBenchmarkService
            )
        }
    }

    private var rootHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isDrawerOpen.toggle()
                }
            } label: {
                Label("Menu", systemImage: "line.3.horizontal")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDrawerOpen ? "Close navigation menu" : "Open navigation menu")
            .accessibilityIdentifier("root.drawer.toggle")

            Text(selectedSection.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var drawer: some View {
        ZStack(alignment: .topLeading) {
            drawerMarker

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kairo")
                            .font(.title2.bold())
                        Text("iPhone agent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isDrawerOpen = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close navigation menu")
                    .accessibilityIdentifier("root.drawer.close")
                }
                .padding(.top, 18)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(RootSection.allCases) { section in
                        drawerRow(section)
                    }
                }

                Spacer()

                Text("Public APIs, explicit permission, visible handoff.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 304)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .shadow(color: .black.opacity(0.18), radius: 22, x: 8, y: 0)
        .ignoresSafeArea(edges: .vertical)
    }

    private var drawerMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kairo navigation drawer")
            .accessibilityIdentifier("root.drawer")
    }

    private func drawerRow(_ section: RootSection) -> some View {
        Button {
            selectedSection = section
            withAnimation(.easeInOut(duration: 0.22)) {
                isDrawerOpen = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .frame(width: 24)
                Text(section.title)
                    .fontWeight(selectedSection == section ? .semibold : .regular)
                Spacer()
                if selectedSection == section {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(selectedSection == section ? Color.accentColor : Color.primary)
            .background(selectedSection == section ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("root.drawer.\(section.rawValue)")
    }
}

private enum RootSection: String, CaseIterable, Identifiable {
    case chat
    case memory
    case automations
    case access
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .memory:
            return "Memory"
        case .automations:
            return "Automations"
        case .access:
            return "Access"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "message"
        case .memory:
            return "brain.head.profile"
        case .automations:
            return "bolt.badge.automatic"
        case .access:
            return "switch.2"
        case .settings:
            return "gear"
        }
    }
}
#endif
