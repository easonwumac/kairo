#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
    private let environment: KairoEnvironment
    private let settingsMode: SettingsViewMode
    @State private var selectedSection: RootSection = .home
    @State private var isMenuPresented = false

    public init(
        environment: KairoEnvironment = .preview(),
        initialSection: String? = nil,
        settingsMode: SettingsViewMode = .all
    ) {
        self.environment = environment
        self.settingsMode = settingsMode
        let section = initialSection.flatMap(RootSection.init(rawValue:)) ?? .home
        _selectedSection = State(initialValue: section)
    }

    public var body: some View {
        GeometryReader { proxy in
            let safeAreaInsets = proxy.safeAreaInsets

            ZStack(alignment: .topLeading) {
                Self.fullScreenBackground
                    .ignoresSafeArea()

                shellMarker

                VStack(spacing: 0) {
                    rootHeader(topInset: safeAreaInsets.top)

                    selectedContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.fullScreenBackground.ignoresSafeArea())
            .sheet(isPresented: $isMenuPresented) {
                navigationMenu(safeAreaInsets: safeAreaInsets)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.fullScreenBackground.ignoresSafeArea())
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
        KairoDesign.background
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .home:
            BriefingInboxView(selectSection: { section in
                selectedSection = section
            })
        case .chat:
            ChatView(environment: environment)
        case .memory:
            MemoryCenterView(store: environment.memoryStore)
        case .skills:
            PermissionHubView(
                skillManagerService: environment.agentSkillManagerService,
                marketplaceCatalogService: environment.agentSkillMarketplaceCatalogService
            )
        case .shortcuts:
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
        case .models:
            SettingsView(
                settingsService: OpenAISettingsService(credentialStore: environment.credentialStore),
                mode: .modelsOnly,
                credentialStore: environment.credentialStore,
                oauthCallbackStore: environment.oauthConnectorCallbackStore,
                localModelCatalog: environment.localModelCatalog,
                localModelCatalogService: environment.localModelCatalogService,
                localModelSettingsService: environment.localModelSettingsService,
                localModelDownloader: environment.localModelDownloader,
                localModelBenchmarkService: environment.localModelBenchmarkService,
                localModelReplyCheckService: environment.localModelReplyCheckService
            )
        case .settings:
            SettingsView(
                settingsService: OpenAISettingsService(credentialStore: environment.credentialStore),
                mode: settingsMode,
                credentialStore: environment.credentialStore,
                oauthCallbackStore: environment.oauthConnectorCallbackStore,
                localModelCatalog: environment.localModelCatalog,
                localModelCatalogService: environment.localModelCatalogService,
                localModelSettingsService: environment.localModelSettingsService,
                localModelDownloader: environment.localModelDownloader,
                localModelBenchmarkService: environment.localModelBenchmarkService,
                localModelReplyCheckService: environment.localModelReplyCheckService
            )
        }
    }

    private func rootHeader(topInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            KairoMark(size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(selectedSection.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(selectedSection.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if selectedSection != .models {
                KairoStatusPill(title: "Auto", systemImage: "arrow.triangle.branch", tint: KairoDesign.blue)
            }

            Button {
                isMenuPresented = true
            } label: {
                Label("Menu", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open navigation menu")
            .accessibilityIdentifier("root.drawer.toggle")
        }
        .padding(.horizontal, 16)
        .padding(.top, max(topInset, 0) + 8)
        .padding(.bottom, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.safe-area-header")
    }

    private func navigationMenu(safeAreaInsets: EdgeInsets) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("root.menu.sheet")

                    HStack(spacing: 12) {
                        KairoMark(size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Kairo")
                                .font(.title3.bold())
                            Text("Choose what to review, remember, or run.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            isMenuPresented = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close navigation menu")
                        .accessibilityIdentifier("root.drawer.close")
                    }

                    KairoGroupedSurface {
                        ForEach(RootSection.allCases) { section in
                            navigationRow(section)
                            if section != RootSection.allCases.last {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }

                    Text("Kairo uses public APIs, explicit permission, and visible handoff.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, max(safeAreaInsets.bottom, 0) + 24)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .navigationTitle("Navigate")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kairo navigation menu")
        .accessibilityIdentifier("root.drawer")
    }

    private func navigationRow(_ section: RootSection) -> some View {
        Button {
            selectedSection = section
            isMenuPresented = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(section.tint)
                    .frame(width: 32, height: 32)
                    .background(section.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if selectedSection == section {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(section.tint)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("root.drawer.\(section.rawValue)")
    }
}

private struct BriefingInboxView: View {
    let selectSection: (RootSection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today")
                        .font(.largeTitle.bold())
                    Text("Review what Kairo can safely help with before anything changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                KairoGroupedSurface {
                    KairoActionRow(
                        title: "Ask Kairo",
                        subtitle: "Start a chat with memory, routes, and safe actions available.",
                        systemImage: "text.bubble",
                        tint: KairoDesign.blue,
                        trailingText: "Open"
                    ) {
                        selectSection(.chat)
                    }
                    .accessibilityIdentifier("home.ask-kairo")

                    Divider().padding(.leading, 44)

                    KairoActionRow(
                        title: "Review Queue",
                        subtitle: "Reminder, calendar, and handoff drafts wait for confirmation.",
                        systemImage: "checklist.checked",
                        tint: KairoDesign.amber,
                        trailingText: "3"
                    ) {
                        selectSection(.chat)
                    }
                    .accessibilityIdentifier("home.review-queue")

                    Divider().padding(.leading, 44)

                    KairoActionRow(
                        title: "Memory",
                        subtitle: "Search saved context or add a user-approved memory.",
                        systemImage: "books.vertical",
                        tint: KairoDesign.teal,
                        trailingText: "Ready"
                    ) {
                        selectSection(.memory)
                    }
                    .accessibilityIdentifier("home.memory")
                }

                KairoGroupedSurface {
                    KairoActionRow(
                        title: "Tools & Access",
                        subtitle: "Skills, permissions, HomeKit demos, and compatibility gates.",
                        systemImage: "switch.2",
                        tint: KairoDesign.teal
                    ) {
                        selectSection(.access)
                    }
                    .accessibilityIdentifier("home.access")

                    Divider().padding(.leading, 44)

                    KairoActionRow(
                        title: "Automations",
                        subtitle: "Internal Kairo recipes and user-installed Shortcut templates.",
                        systemImage: "square.stack.3d.up",
                        tint: KairoDesign.amber
                    ) {
                        selectSection(.shortcuts)
                    }
                    .accessibilityIdentifier("home.automations")

                    Divider().padding(.leading, 44)

                    KairoActionRow(
                        title: "Models",
                        subtitle: "Cloud route, local fallback, downloads, and reply checks.",
                        systemImage: "cpu",
                        tint: KairoDesign.blue
                    ) {
                        selectSection(.models)
                    }
                    .accessibilityIdentifier("home.models")
                }

                HStack(spacing: 8) {
                    KairoStatusPill(title: "No silent writes", systemImage: "hand.raised", tint: KairoDesign.amber)
                    KairoStatusPill(title: "Public APIs", systemImage: "checkmark.shield", tint: KairoDesign.teal)
                }
                .accessibilityIdentifier("home.safety-pills")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(KairoDesign.background.ignoresSafeArea())
        .accessibilityIdentifier("home.briefing-inbox")
    }
}

private enum RootSection: String, CaseIterable, Identifiable {
    case home
    case chat
    case memory
    case skills
    case shortcuts
    case access
    case models
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Today"
        case .chat:
            return "Chat"
        case .memory:
            return "Memory"
        case .skills:
            return "Skills"
        case .shortcuts:
            return "Automations"
        case .access:
            return "Access"
        case .models:
            return "Models"
        case .settings:
            return "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .home:
            return "Briefing inbox"
        case .chat:
            return "Ask and review"
        case .memory:
            return "Saved context"
        case .skills:
            return "Managed tools"
        case .shortcuts:
            return "Recipes and templates"
        case .access:
            return "Permissions and skills"
        case .models:
            return "Cloud and local route"
        case .settings:
            return "Accounts and privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "tray.full"
        case .chat:
            return "message"
        case .memory:
            return "books.vertical"
        case .skills:
            return "wrench.and.screwdriver"
        case .shortcuts:
            return "square.stack.3d.up"
        case .access:
            return "switch.2"
        case .models:
            return "cpu"
        case .settings:
            return "gear"
        }
    }

    var tint: Color {
        switch self {
        case .home, .memory, .access:
            return KairoDesign.teal
        case .chat, .models:
            return KairoDesign.blue
        case .skills, .shortcuts:
            return KairoDesign.amber
        case .settings:
            return KairoDesign.muted
        }
    }
}
#endif
