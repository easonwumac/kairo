#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
    private let environment: KairoEnvironment

    public init(environment: KairoEnvironment = .preview()) {
        self.environment = environment
    }

    public var body: some View {
        TabView {
            ChatView(environment: environment)
                .tabItem {
                    Label("Chat", systemImage: "message")
                        .accessibilityIdentifier("root.tab.chat")
                }

            MemoryCenterView(store: environment.memoryStore)
                .tabItem {
                    Label("Memory", systemImage: "brain.head.profile")
                        .accessibilityIdentifier("root.tab.memory")
                }

            PermissionHubView(
                skillManagerService: environment.agentSkillManagerService,
                marketplaceCatalogService: environment.agentSkillMarketplaceCatalogService
            )
                .tabItem {
                    Label("Access", systemImage: "switch.2")
                        .accessibilityIdentifier("root.tab.access")
                }

            SettingsView(
                settingsService: OpenAISettingsService(credentialStore: environment.credentialStore),
                credentialStore: environment.credentialStore
            )
                .tabItem {
                    Label("Settings", systemImage: "gear")
                        .accessibilityIdentifier("root.tab.settings")
                }
        }
    }
}
#endif
