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
                .tabItem { Label("Chat", systemImage: "message") }

            MemoryCenterView(store: environment.memoryStore)
                .tabItem { Label("Memory", systemImage: "brain.head.profile") }

            PermissionHubView()
                .tabItem { Label("Access", systemImage: "switch.2") }

            SettingsView(settingsService: OpenAISettingsService(credentialStore: environment.credentialStore))
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
#endif
