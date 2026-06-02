#if canImport(SwiftUI)
import KairoCore
import SwiftUI

@main
struct KairoApp: App {
    @State private var environment: KairoEnvironment = .preview()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .task {
                    guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
                        return
                    }
                    if let liveEnvironment = try? await KairoEnvironment.live(
                        appGroupIdentifier: KairoSharedAppStorage.appGroupIdentifier
                    ) {
                        environment = liveEnvironment
                    }
                }
        }
    }
}
#endif
