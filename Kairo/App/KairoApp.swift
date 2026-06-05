#if canImport(SwiftUI)
import KairoCore
import SwiftUI

@main
struct KairoApp: App {
    @State private var environment: KairoEnvironment = .preview()
    @State private var environmentRevision = 0
    @State private var didLoadEnvironment = false
    @State private var isLoadingLaunchEnvironment = true
    @State private var launchEnvironmentError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let launchEnvironmentError {
                    Text(launchEnvironmentError)
                        .accessibilityIdentifier("root.environment.error")
                } else if isLoadingLaunchEnvironment {
                    ProgressView(KairoL10n.string("root.environment.loading"))
                        .accessibilityIdentifier("root.environment.loading")
                } else {
                    RootView(
                        environment: environment,
                        initialSection: Self.launchInitialSection(arguments: ProcessInfo.processInfo.arguments),
                        settingsMode: Self.launchSettingsMode(arguments: ProcessInfo.processInfo.arguments)
                    )
                        .id(environmentRevision)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea())
                .task {
                    guard !didLoadEnvironment else { return }
                    didLoadEnvironment = true

                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains("--ui-testing") {
                        do {
                            let uiTestingEnvironment = try await KairoEnvironment.uiTesting(
                                resetPersistentState: arguments.contains("--reset-ui-testing-data"),
                                seedInstalledLocalModel: arguments.contains("--ui-testing-installed-local-model"),
                                seedInstalledWeatherSkill: arguments.contains("--ui-testing-installed-weather-skill"),
                                seedExpandedLocalModelCatalog: arguments.contains("--ui-testing-expanded-local-model-catalog"),
                                seedSharedTaskText: arguments.contains("--ui-testing-seed-shared-task"),
                                selectInstalledLocalModel: arguments.contains("--ui-testing-select-local-model"),
                                localModelRoutePreference: Self.uiTestingLocalModelRoutePreference(arguments: arguments),
                                installedLocalModelFileURL: Self.uiTestingLocalModelFileURL(arguments: arguments),
                                localModelReplyCheckRuntimeOverride: Self.uiTestingLocalModelReplyRuntime(arguments: arguments),
                                localModelBenchmarkEngineOverride: Self.uiTestingLocalModelBenchmarkEngine(arguments: arguments)
                            )
                            environment = uiTestingEnvironment
                            environmentRevision += 1
                            isLoadingLaunchEnvironment = false
                        } catch {
                            launchEnvironmentError = KairoL10n.string("root.environment.uiTestingLoadFailed")
                            isLoadingLaunchEnvironment = false
                        }
                        return
                    }
                    do {
                        let liveEnvironment = try await Self.liveEnvironment()
                        environment = liveEnvironment
                        environmentRevision += 1
                        isLoadingLaunchEnvironment = false
                    } catch {
                        launchEnvironmentError = KairoL10n.string("root.environment.liveLoadFailed")
                        isLoadingLaunchEnvironment = false
                    }
                }
        }
    }

    private static func liveEnvironment() async throws -> KairoEnvironment {
        #if canImport(llama)
        let runtime = LlamaCppLocalModelRuntime()
        return try await KairoEnvironment.live(
            appGroupIdentifier: KairoSharedAppStorage.appGroupIdentifier,
            localModelReplyCheckRuntimeOverride: runtime,
            localModelBenchmarkEngineOverride: runtime
        )
        #else
        #if DEBUG && targetEnvironment(simulator)
        return try await KairoEnvironment.live(
            appGroupIdentifier: KairoSharedAppStorage.appGroupIdentifier,
            localModelReplyCheckRuntimeOverride: DeterministicLocalModelReplyCheckRuntime(
                runtimePackage: "simulator-dev-local-runtime",
                responseText: KairoL10n.string("chat.provider.localSimulator.response"),
                generationTokensPerSecond: 38.5
            )
        )
        #else
        return try await KairoEnvironment.live(
            appGroupIdentifier: KairoSharedAppStorage.appGroupIdentifier
        )
        #endif
        #endif
    }

    private static func uiTestingLocalModelFileURL(arguments: [String]) -> URL? {
        let prefix = "--ui-testing-local-model-file="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return URL(fileURLWithPath: String(argument.dropFirst(prefix.count)))
    }

    private static func uiTestingLocalModelRoutePreference(arguments: [String]) -> ProviderRoutePreference? {
        let prefix = "--ui-testing-local-route-preference="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return ProviderRoutePreference(rawValue: String(argument.dropFirst(prefix.count)))
    }

    private static func uiTestingLocalModelReplyRuntime(arguments: [String]) -> (any LocalModelReplyCheckRuntime)? {
        #if canImport(llama)
        guard arguments.contains("--ui-testing-live-local-model-runtime") else {
            return nil
        }
        return LlamaCppLocalModelRuntime()
        #else
        return nil
        #endif
    }

    private static func uiTestingLocalModelBenchmarkEngine(arguments: [String]) -> (any LocalModelBenchmarkEngine)? {
        #if canImport(llama)
        guard arguments.contains("--ui-testing-live-local-model-runtime") else {
            return nil
        }
        return LlamaCppLocalModelRuntime()
        #else
        return nil
        #endif
    }

    private static func launchInitialSection(arguments: [String]) -> String? {
        let prefix = "--ui-testing-root-section="
        return arguments
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private static func launchSettingsMode(arguments: [String]) -> SettingsViewMode {
        guard arguments.contains("--ui-testing-settings-shortcut-demos-only") else {
            return .all
        }
        return .shortcutDemosOnly
    }
}
#endif
