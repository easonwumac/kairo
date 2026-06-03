#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
    private let environment: KairoEnvironment
    private let settingsMode: SettingsViewMode
    @State private var selectedSection: RootSection = .chat
    @State private var isMenuPresented = false

    public init(
        environment: KairoEnvironment = .preview(),
        initialSection: String? = nil,
        settingsMode: SettingsViewMode = .all
    ) {
        self.environment = environment
        self.settingsMode = settingsMode
        let section = initialSection.flatMap(RootSection.init(rawValue:)) ?? .chat
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
        case .chat:
            ChatView(environment: environment)
        case .memory:
            MemoryCenterView(store: environment.memoryStore)
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
            if selectedSection == .chat {
                KairoMark(size: 34)
            } else {
                Button {
                    selectedSection = .chat
                } label: {
                    Label("Back to Chat", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.blue)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(KairoDesign.blue.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Chat")
                .accessibilityIdentifier("root.back-to-chat")
            }

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
                            Text("Kairo Chat")
                                .font(.title3.bold())
                            Text("Chat stays first. Manage tools only when you need setup.")
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

                    Text("Kairo uses public APIs, explicit permission, and visible handoff. Nothing changes silently.")
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
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selectedSection == section ? section.tint : .secondary)
                    .frame(width: 28, height: 28)

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

private enum RootSection: String, CaseIterable, Identifiable {
    case chat
    case memory
    case shortcuts
    case access
    case models
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat:
            return "Kairo Chat"
        case .memory:
            return "Memory"
        case .shortcuts:
            return "Workflows"
        case .access:
            return "Phone tools"
        case .models:
            return "AI engine"
        case .settings:
            return "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .chat:
            return "Tell Kairo what to do on this phone"
        case .memory:
            return "Approved context"
        case .shortcuts:
            return "Reusable Kairo recipes"
        case .access:
            return "What Chat can suggest"
        case .models:
            return "Cloud and local models"
        case .settings:
            return "Accounts and privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "bubble.left.and.text.bubble.right"
        case .memory:
            return "books.vertical"
        case .shortcuts:
            return "list.bullet.rectangle"
        case .access:
            return "iphone.gen3"
        case .models:
            return "cpu"
        case .settings:
            return "gear"
        }
    }

    var tint: Color {
        switch self {
        case .memory, .access:
            return KairoDesign.teal
        case .chat, .models:
            return KairoDesign.blue
        case .shortcuts:
            return KairoDesign.amber
        case .settings:
            return KairoDesign.muted
        }
    }
}
#endif
