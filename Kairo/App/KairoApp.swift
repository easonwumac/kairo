#if canImport(SwiftUI)
import KairoCore
import OSLog
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
final class KairoAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        URLSessionLocalModelArtifactDownloader.setBackgroundEventsCompletionHandler(
            completionHandler,
            for: identifier
        )
    }
}
#endif

@main
struct KairoApp: App {
    private static let smokeLogger = Logger(subsystem: "app.kairo.ios", category: "LocalModelSmoke")
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(KairoAppDelegate.self) private var appDelegate
    #endif

    @State private var environment: KairoEnvironment = .preview()
    @State private var environmentRevision = 0
    @State private var didLoadEnvironment = false
    @State private var isLoadingLaunchEnvironment = true
    @State private var launchEnvironmentError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let launchEnvironmentError {
                    launchEnvironmentErrorView(launchEnvironmentError)
                } else if isLoadingLaunchEnvironment {
                    ProgressView(KairoL10n.string("root.environment.loading"))
                        .tint(Self.launchAccentColor)
                        .foregroundStyle(Self.launchTextColor)
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
                .background(Self.launchBackgroundColor.ignoresSafeArea())
                .task {
                    guard !didLoadEnvironment else { return }
                    didLoadEnvironment = true

                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains("--ui-testing") {
                        UserDefaults.standard.set(
                            !arguments.contains("--ui-testing-show-onboarding"),
                            forKey: KairoOnboarding.completedStorageKey
                        )
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
                            Self.runUITestingLocalModelSmokeIfNeeded(
                                arguments: arguments,
                                environment: uiTestingEnvironment
                            )
                        } catch {
                            launchEnvironmentError = Self.launchErrorMessage(
                                "root.environment.uiTestingLoadFailed",
                                error: error
                            )
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
                        launchEnvironmentError = Self.launchErrorMessage(
                            "root.environment.liveLoadFailed",
                            error: error
                        )
                        isLoadingLaunchEnvironment = false
                    }
                }
        }
    }

    private func launchEnvironmentErrorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.launchTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Self.launchCardColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Self.launchLineColor, lineWidth: 1)
        }
        .padding(.horizontal, 18)
        .accessibilityIdentifier("root.environment.error")
    }

    private static var launchBackgroundColor: Color {
        Color(red: 0.015, green: 0.035, blue: 0.075)
    }

    private static var launchCardColor: Color {
        Color(red: 0.075, green: 0.105, blue: 0.145).opacity(0.92)
    }

    private static var launchLineColor: Color {
        Color(red: 0.24, green: 0.58, blue: 0.76).opacity(0.26)
    }

    private static var launchTextColor: Color {
        Color(red: 0.92, green: 0.96, blue: 1.0)
    }

    private static var launchAccentColor: Color {
        Color(red: 0.32, green: 0.74, blue: 1.0)
    }

    private static func launchErrorMessage(_ key: String, error: Error) -> String {
        #if DEBUG
        return "\(KairoL10n.string(key))\n\(error.localizedDescription)"
        #else
        return KairoL10n.string(key)
        #endif
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
        return try await KairoEnvironment.live(
            appGroupIdentifier: KairoSharedAppStorage.appGroupIdentifier
        )
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

    private static func runUITestingLocalModelSmokeIfNeeded(
        arguments: [String],
        environment: KairoEnvironment
    ) {
        let prefix = "--ui-testing-run-local-model-smoke="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return
        }
        let prompt = String(argument.dropFirst(prefix.count)).removingPercentEncoding ?? "Say hello."
        Task {
            do {
                print("KAIRO_LOCAL_MODEL_SMOKE_START promptLength=\(prompt.count)")
                Self.smokeLogger.notice("KAIRO_LOCAL_MODEL_SMOKE_START promptLength=\(prompt.count)")
                let response = try await environment.aiProvider.complete(
                    AICompletionRequest(
                        systemPrompt: DefaultAgentCompletionRequestBuilder.defaultSystemPrompt,
                        userPrompt: prompt,
                        memoryContext: [],
                        allowedCapabilities: [],
                        attachmentContext: [],
                        toolContext: nil,
                        privacyMode: .standard
                    )
                )
                print(
                    "KAIRO_LOCAL_MODEL_SMOKE_SUCCESS responseLength=\(response.message.count) message=\(String(response.message.prefix(160)))"
                )
                Self.smokeLogger.notice(
                    "KAIRO_LOCAL_MODEL_SMOKE_SUCCESS responseLength=\(response.message.count) message=\(String(response.message.prefix(160)), privacy: .public)"
                )
            } catch {
                print("KAIRO_LOCAL_MODEL_SMOKE_ERROR \(error.localizedDescription)")
                Self.smokeLogger.error("KAIRO_LOCAL_MODEL_SMOKE_ERROR \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func uiTestingLocalModelReplyRuntime(arguments: [String]) -> (any LocalModelReplyCheckRuntime)? {
        #if canImport(llama)
        _ = arguments
        return LlamaCppLocalModelRuntime()
        #else
        _ = arguments
        return nil
        #endif
    }

    private static func uiTestingLocalModelBenchmarkEngine(arguments: [String]) -> (any LocalModelBenchmarkEngine)? {
        #if canImport(llama)
        _ = arguments
        return LlamaCppLocalModelRuntime()
        #else
        _ = arguments
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
