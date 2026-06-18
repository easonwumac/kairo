#if canImport(SwiftUI)
import SwiftUI

enum RootChromeLeadingAction: Equatable {
    case menu
    case back
}

struct RootChromeContext: Equatable {
    var leadingAction: RootChromeLeadingAction = .menu
    var title: String?

    static let standard = RootChromeContext()
}

struct RootChromePreferenceKey: PreferenceKey {
    static var defaultValue = RootChromeContext.standard

    static func reduce(value: inout RootChromeContext, nextValue: () -> RootChromeContext) {
        value = nextValue()
    }
}

public struct RootView: View {
    private let environment: KairoEnvironment
    private let rootDependencies: RootFeatureDependencies
    private let settingsMode: SettingsViewMode
    @State private var urlRouter: KairoURLRouterViewModel
    @AppStorage(KairoAppearancePreference.storageKey) private var appearancePreferenceRawValue = KairoAppearancePreference.system.rawValue
    @AppStorage(KairoOnboarding.completedStorageKey) private var isOnboardingCompleted = false
    @State private var selectedSection: RootSection = .chat
    @State private var isMenuPresented = false
    @State private var isPageActionsPresented = false
    @State private var isChatDestructiveActionsExpanded = false
    @State private var chatChromeActionRequest: ChatChromeActionRequest?
    @State private var drawerChatThreads: [ChatThread] = []
    @State private var isDrawerChatHistoryExpanded = false
    @State private var isAdvancedNavigationExpanded = false
    @State private var chromeContext = RootChromeContext.standard
    @State private var chromeBackRequestID = 0
    @State private var wikiRouteRequest: KairoURLRoute?

    public init(
        environment: KairoEnvironment = .preview(),
        initialSection: String? = nil,
        settingsMode: SettingsViewMode = .all,
        urlRouter: KairoURLRouterViewModel? = nil
    ) {
        self.environment = environment
        self.rootDependencies = environment.rootFeatureDependencies
        self.settingsMode = settingsMode
        _urlRouter = State(initialValue: urlRouter ?? KairoURLRouterViewModel(router: environment.urlRouter))
        let section = initialSection.flatMap(RootSection.init(rawValue:)) ?? .chat
        _selectedSection = State(initialValue: section)
        _isAdvancedNavigationExpanded = State(initialValue: section.isAdvancedNavigationSection)
    }

    public var body: some View {
        GeometryReader { proxy in
            let safeAreaInsets = proxy.safeAreaInsets

            ZStack(alignment: .topLeading) {
                Self.fullScreenBackground
                    .ignoresSafeArea()

                shellMarker

                if isOnboardingCompleted {
                    selectedContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(.container, edges: .top)
                        .onPreferenceChange(RootChromePreferenceKey.self) { context in
                            chromeContext = context
                        }

                    rootHeader(topInset: safeAreaInsets.top)
                        .zIndex(5)
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    if isPageActionsPresented && !isMenuPresented {
                        pageActionsOverlay(topInset: safeAreaInsets.top)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .zIndex(6)
                    }

                    if isMenuPresented {
                        drawerOverlay(safeAreaInsets: safeAreaInsets, containerWidth: proxy.size.width)
                            .transition(.move(edge: .leading))
                            .zIndex(10)
                    }
                } else {
                    OnboardingView(
                        assetAPI: environment.backendAPI.knowledgeAssets,
                        openModelSettings: {
                            selectedSection = .models
                            isOnboardingCompleted = true
                        },
                        finish: {
                            isOnboardingCompleted = true
                            Task { @MainActor in
                                await Task.yield()
                                triggerChatChromeAction(.newThread)
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.fullScreenBackground.ignoresSafeArea())
            .ignoresSafeArea(.container, edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.fullScreenBackground.ignoresSafeArea())
        .preferredColorScheme(appearancePreference.colorScheme)
        .onOpenURL { url in
            guard let openURLHandler = rootDependencies.openURLHandler else { return }
            Task {
                try? await openURLHandler.handle(url)
            }
        }
        .onChange(of: selectedSection) { _, newSection in
            chromeContext = .standard
            if newSection.isAdvancedNavigationSection {
                isAdvancedNavigationExpanded = true
            }
        }
        .onChange(of: urlRouter.pending) { _, _ in
            consumePendingRoute()
        }
        .task {
            if let route = KairoIntentRouteStore().consume(router: environment.urlRouter) {
                urlRouter.navigate(to: route)
            }
            consumePendingRoute()
        }
    }

    private var appearancePreference: KairoAppearancePreference {
        KairoAppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system
    }

    private var shellMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(KairoL10n.string("root.accessibility.shell"))
            .accessibilityIdentifier("root.shell")
    }

    private static var fullScreenBackground: some View {
        ZStack {
            KairoDesign.background
            RadialGradient(
                colors: [
                    KairoDesign.topGlow,
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            LinearGradient(
                colors: [
                    KairoDesign.secondaryGlow,
                    Color.clear,
                    KairoDesign.bottomShade
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .chat:
            ChatView(
                dependencies: environment.chatFeatureDependencies,
                chromeActionRequest: chatChromeActionRequest,
                openModelSettings: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        selectedSection = .models
                        isMenuPresented = false
                        isPageActionsPresented = false
                    }
                },
                rootChromeBackRequestID: $chromeBackRequestID,
                usesRootChromeNavigation: true
            )
                .ignoresSafeArea(.container, edges: .top)
        case .wiki:
            WikiSearchView(
                searchService: environment.wikiSearchService,
                detailResolver: environment.wikiDetailResolver,
                routeRequest: wikiRouteRequest
            )
        case .assets:
            KnowledgeAssetsView(
                dependencies: environment.knowledgeAssetFeatureDependencies,
                rootChromeBackRequestID: $chromeBackRequestID,
                usesRootChromeNavigation: true
            )
        case .pages:
            InfoPageListView(
                store: environment.sharedInfoPageStore,
                assetAPI: environment.backendAPI.knowledgeAssets,
                rootChromeBackRequestID: $chromeBackRequestID,
                usesRootChromeNavigation: true
            )
        case .categories:
            KnowledgeCategoriesView(dependencies: environment.knowledgeAssetFeatureDependencies)
        case .memory:
            MemoryCenterView(dependencies: environment.memoryFeatureDependencies)
        case .shortcuts:
            AutomationsView(dependencies: environment.automationsFeatureDependencies)
        case .access:
            PermissionHubView(
                dependencies: environment.accessFeatureDependencies,
                rootChromeBackRequestID: $chromeBackRequestID,
                usesRootChromeNavigation: true
            )
        case .models:
            SettingsView(
                dependencies: environment.settingsFeatureDependencies,
                mode: .modelsOnly,
                deletionAPI: nil,
                rootChromeBackRequestID: $chromeBackRequestID,
                usesRootChromeNavigation: true
            )
        case .performance:
            LocalModelPerformanceView(
                benchmarkService: environment.localModelBenchmarkService,
                settingsService: environment.localModelSettingsService
            )
        case .settings:
            SettingsView(
                dependencies: environment.settingsFeatureDependencies,
                mode: settingsMode,
                rootChromeBackRequestID: $chromeBackRequestID,
                usesRootChromeNavigation: true
            )
        }
    }

    private func consumePendingRoute() {
        guard let route = urlRouter.consume() else { return }
        handle(route)
    }

    private func handle(_ route: KairoURLRoute) {
        switch route {
        case .section(let section):
            isOnboardingCompleted = true
            selectedSection = RootSection(section)
            isMenuPresented = false
            isPageActionsPresented = false
            wikiRouteRequest = nil
        case .search, .infoPage, .knowledgeAsset, .memoryRecord:
            isOnboardingCompleted = true
            selectedSection = .wiki
            isMenuPresented = false
            isPageActionsPresented = false
            wikiRouteRequest = route
        case .chatThread(let id):
            isOnboardingCompleted = true
            selectedSection = .chat
            isMenuPresented = false
            isPageActionsPresented = false
            triggerChatChromeAction(.selectThread(id))
        case .captureReview:
            isOnboardingCompleted = true
            selectedSection = .chat
            isMenuPresented = false
            isPageActionsPresented = false
            wikiRouteRequest = nil
            Task { @MainActor in
                await enqueueIntentCapturesForReview()
                await Task.yield()
                triggerChatChromeAction(.reviewCaptures)
            }
        }
    }

    private func enqueueIntentCapturesForReview() async {
        let captures = KairoIntentCaptureStore().consume()
        guard !captures.isEmpty else { return }
        do {
            try await KairoIntentCaptureIngestor().enqueue(captures, into: environment.shareIngestionQueue)
        } catch {
            // Best effort: the route still opens Chat so existing pending captures can be reviewed.
        }
    }

    @ViewBuilder
    private func rootHeader(topInset: CGFloat) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                rootHeaderContent(topInset: topInset)
            }
        } else {
            rootHeaderContent(topInset: topInset)
        }
    }

    private func rootHeaderContent(topInset: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button {
                switch chromeContext.leadingAction {
                case .back:
                    chromeBackRequestID += 1
                case .menu:
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        isPageActionsPresented = false
                        isMenuPresented = true
                    }
                    Task { await loadDrawerChatThreads() }
                }
            } label: {
                Label(
                    rootLeadingButtonAccessibilityLabel,
                    systemImage: chromeContext.leadingAction == .back ? "chevron.left" : "line.3.horizontal"
                )
                    .labelStyle(.iconOnly)
                    .font(.headline.weight(.semibold))
                    .glassCircleControl()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rootLeadingButtonAccessibilityLabel)
            .accessibilityIdentifier("root.drawer.toggle")

            Text(chromeContext.title ?? selectedSection.shortTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .glassCapsuleControl()
                .accessibilityLabel(chromeContext.title ?? selectedSection.title)
                .accessibilityIdentifier("root.current-section")

            Spacer(minLength: 8)

            if selectedSection == .chat {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        isMenuPresented = false
                        isPageActionsPresented.toggle()
                        if !isPageActionsPresented {
                            isChatDestructiveActionsExpanded = false
                        }
                    }
                } label: {
                    Label(KairoL10n.string("root.moreActions"), systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .font(.headline.weight(.bold))
                        .glassCircleControl()
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KairoL10n.string("root.moreActions"))
                .accessibilityIdentifier("root.page-actions")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .padding(.top, max(topInset - 8, 0))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.safe-area-header")
    }

    private var rootLeadingButtonAccessibilityLabel: String {
        switch chromeContext.leadingAction {
        case .back:
            return KairoL10n.string("root.back")
        case .menu:
            return KairoL10n.string("root.menu.open")
        }
    }

    private func drawerOverlay(safeAreaInsets: EdgeInsets, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Self.fullScreenBackground
                .ignoresSafeArea()

            navigationMenu(safeAreaInsets: safeAreaInsets)
                .frame(width: containerWidth, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isMenuPresented = false
        }
    }

    private func pageActionsOverlay(topInset: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                        isPageActionsPresented = false
                        isChatDestructiveActionsExpanded = false
                    }
                }

            pageActionsPalette
                .padding(.top, max(topInset - 8, 0) + 44)
                .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(true)
        .accessibilityIdentifier("root.page-actions.overlay")
    }

    private var pageActionsPalette: some View {
        VStack(spacing: 7) {
            pageActionRow(
                title: KairoL10n.string("settings.models.section"),
                systemImage: "cpu",
                tint: KairoDesign.teal
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    selectedSection = .models
                    isMenuPresented = false
                    isPageActionsPresented = false
                    isChatDestructiveActionsExpanded = false
                }
            }
            .accessibilityIdentifier("root.page-actions.models")

            Divider()
                .padding(.horizontal, 8)

            pageActionRow(
                title: KairoL10n.string("chat.thread.action.privateNew"),
                systemImage: "lock",
                tint: KairoDesign.ink
            ) {
                triggerChatChromeAction(.newPrivateThread)
            }

            pageActionRow(
                title: KairoL10n.string("chat.thread.action.fork"),
                systemImage: "arrow.triangle.branch",
                tint: KairoDesign.teal
            ) {
                triggerChatChromeAction(.fork)
            }

            pageActionRow(
                title: KairoL10n.string("chat.thread.action.compact"),
                systemImage: "rectangle.compress.vertical",
                tint: KairoDesign.blue
            ) {
                triggerChatChromeAction(.compact)
            }

            Divider()
                .padding(.horizontal, 8)

            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                    isChatDestructiveActionsExpanded.toggle()
                }
            } label: {
                pageActionDisclosureRowContent(
                    title: KairoL10n.string("chat.thread.action.deleteOptions"),
                    systemImage: "trash",
                    tint: KairoDesign.red,
                    isExpanded: isChatDestructiveActionsExpanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("root.page-actions.delete-options")

            if isChatDestructiveActionsExpanded {
                pageActionRow(
                    title: KairoL10n.string("chat.thread.action.clear"),
                    systemImage: "trash",
                    tint: KairoDesign.red
                ) {
                    triggerChatChromeAction(.clear)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                pageActionRow(
                    title: KairoL10n.string("chat.thread.action.delete"),
                    systemImage: "trash.slash",
                    tint: KairoDesign.red
                ) {
                    triggerChatChromeAction(.delete)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .frame(width: 190)
        .background(KairoDesign.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 14, x: 0, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.page-actions.palette")
    }

    private func triggerChatChromeAction(_ action: ChatChromeActionKind) {
        selectedSection = .chat
        chatChromeActionRequest = ChatChromeActionRequest(kind: action)
        isPageActionsPresented = false
        isChatDestructiveActionsExpanded = false
    }

    private func pageActionRow(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            pageActionRowContent(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func pageActionRowContent(
        title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(KairoDesign.softSurface.opacity(0.55), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func pageActionDisclosureRowContent(
        title: String,
        systemImage: String,
        tint: Color,
        isExpanded: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(KairoDesign.softSurface.opacity(0.55), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func navigationMenu(safeAreaInsets: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("root.menu.sheet")

                    drawerNavigationContent
                }
                .padding(.horizontal, 18)
                .padding(.top, max(safeAreaInsets.top, 0) + 8)
                .padding(.bottom, max(safeAreaInsets.bottom, 0) + 24)
            }
        }
        .background {
            Self.fullScreenBackground
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KairoL10n.string("root.menu.accessibility"))
        .accessibilityIdentifier("root.drawer")
        .task {
            await loadDrawerChatThreads()
        }
    }

    @ViewBuilder
    private var drawerNavigationContent: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                drawerNavigationStack
            }
        } else {
            drawerNavigationStack
        }
    }

    private var drawerNavigationStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            chatDrawerSection

            navigationGroup(
                title: KairoL10n.string("root.menu.group.primary"),
                sections: [.assets, .pages]
            )

            navigationGroup(
                title: KairoL10n.string("root.menu.group.system"),
                sections: [.models, .access, .settings]
            )

            advancedNavigationSection
        }
    }

    private var chatDrawerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("root.menu.chat.section"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                Button {
                    triggerChatChromeAction(.newThread)
                    closeDrawer()
                } label: {
                    drawerRowContent(
                        title: KairoL10n.string("chat.new"),
                        subtitle: nil,
                        systemImage: "square.and.pencil",
                        tint: KairoDesign.blue
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("root.drawer.chat.new")

                let visibleThreads = isDrawerChatHistoryExpanded ? drawerChatThreads : Array(drawerChatThreads.prefix(3))
                if !visibleThreads.isEmpty {
                    Divider()
                        .padding(.leading, 54)

                    ForEach(visibleThreads) { thread in
                        Button {
                            triggerChatChromeAction(.selectThread(thread.id))
                            closeDrawer()
                        } label: {
                            drawerChatThreadRowContent(
                                title: thread.title,
                                subtitle: thread.lastMessagePreview
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("root.drawer.chat.thread")

                        if thread.id != visibleThreads.last?.id || drawerChatThreads.count > 3 {
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }

                if drawerChatThreads.count > 3 {
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                            isDrawerChatHistoryExpanded.toggle()
                        }
                    } label: {
                        drawerChatThreadRowContent(
                            title: KairoL10n.string(isDrawerChatHistoryExpanded ? "root.menu.chat.showLess" : "root.menu.chat.showMore"),
                            subtitle: KairoL10n.string("root.menu.chat.history.subtitle", Int64(drawerChatThreads.count)),
                            systemImage: isDrawerChatHistoryExpanded ? "chevron.up" : "chevron.down"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("root.drawer.chat.show-more")
                }
            }
            .padding(.vertical, 4)
            .rootNavigationGlassSurface(tint: KairoDesign.blue, isInteractive: true)
        }
    }

    private func navigationRow(_ section: RootSection) -> some View {
        Button {
            selectedSection = section
            isPageActionsPresented = false
            if section.isAdvancedNavigationSection {
                isAdvancedNavigationExpanded = true
            }
            closeDrawer()
        } label: {
            drawerRowContent(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                tint: section.tint,
                isSelected: selectedSection == section
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("root.drawer.\(section.rawValue)")
    }

    private func drawerRowContent(
        title: String,
        subtitle: String?,
        systemImage: String,
        tint: Color,
        isSelected: Bool = false
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(0.12))
            }
        }
        .contentShape(Rectangle())
    }

    private func drawerChatThreadRowContent(
        title: String,
        subtitle: String,
        systemImage: String = "circle.fill"
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: systemImage)
                .font(systemImage == "circle.fill" ? .system(size: 7, weight: .semibold) : .caption.weight(.bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(KairoDesign.muted)
                .frame(width: 20, height: 24)
                .padding(.leading, 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink.opacity(0.92))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func loadDrawerChatThreads() async {
        do {
            drawerChatThreads = try await environment.chatFeatureDependencies.historyStore.listThreads(limit: 12)
        } catch {
            drawerChatThreads = []
        }
    }

    private func navigationGroup(title: String, sections: [RootSection]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(sections) { section in
                    navigationRow(section)
                    if section != sections.last {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
            .padding(.vertical, 4)
            .rootNavigationGlassSurface(tint: sections.first?.tint ?? KairoDesign.muted, isInteractive: true)
        }
    }

    private var advancedNavigationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                    isAdvancedNavigationExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(KairoL10n.string("root.menu.group.advanced"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isAdvancedNavigationExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("root.drawer.advanced.toggle")

            if isAdvancedNavigationExpanded {
                VStack(spacing: 0) {
                    ForEach(RootSection.advancedNavigationSections) { section in
                        navigationRow(section)
                        if section != RootSection.advancedNavigationSections.last {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .padding(.vertical, 4)
                .rootNavigationGlassSurface(tint: KairoDesign.muted, isInteractive: true)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(RootSection.advancedNavigationSections.map(\.shortTitle).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rootNavigationGlassSurface(tint: KairoDesign.muted, isInteractive: true)
                    .accessibilityIdentifier("root.drawer.advanced.summary")
            }
        }
    }
}

private enum RootSection: String, CaseIterable, Identifiable {
    case chat
    case wiki
    case assets
    case pages
    case categories
    case memory
    case shortcuts
    case access
    case models
    case performance
    case settings

    var id: String { rawValue }

    static let advancedNavigationSections: [RootSection] = [.wiki, .categories, .memory]

    var title: String {
        switch self {
        case .chat:
            return KairoL10n.string("root.section.chat.title")
        case .wiki:
            return KairoL10n.string("root.section.wiki.title")
        case .assets:
            return KairoL10n.string("root.section.assets.title")
        case .pages:
            return KairoL10n.string("root.section.pages.title")
        case .categories:
            return KairoL10n.string("root.section.categories.title")
        case .memory:
            return KairoL10n.string("root.section.memory.title")
        case .shortcuts:
            return KairoL10n.string("root.section.shortcuts.title")
        case .access:
            return KairoL10n.string("root.section.access.title")
        case .models:
            return KairoL10n.string("root.section.models.title")
        case .performance:
            return KairoL10n.string("root.section.performance.title")
        case .settings:
            return KairoL10n.string("root.section.settings.title")
        }
    }

    var subtitle: String {
        switch self {
        case .chat:
            return KairoL10n.string("root.section.chat.subtitle")
        case .wiki:
            return KairoL10n.string("root.section.wiki.subtitle")
        case .assets:
            return KairoL10n.string("root.section.assets.subtitle")
        case .pages:
            return KairoL10n.string("root.section.pages.subtitle")
        case .categories:
            return KairoL10n.string("root.section.categories.subtitle")
        case .memory:
            return KairoL10n.string("root.section.memory.subtitle")
        case .shortcuts:
            return KairoL10n.string("root.section.shortcuts.subtitle")
        case .access:
            return KairoL10n.string("root.section.access.subtitle")
        case .models:
            return KairoL10n.string("root.section.models.subtitle")
        case .performance:
            return KairoL10n.string("root.section.performance.subtitle")
        case .settings:
            return KairoL10n.string("root.section.settings.subtitle")
        }
    }

    var shortTitle: String {
        switch self {
        case .chat:
            return KairoL10n.string("root.section.chat.shortTitle")
        case .wiki:
            return KairoL10n.string("root.section.wiki.shortTitle")
        case .assets:
            return KairoL10n.string("root.section.assets.shortTitle")
        case .pages:
            return KairoL10n.string("root.section.pages.shortTitle")
        case .categories:
            return KairoL10n.string("root.section.categories.shortTitle")
        case .memory:
            return KairoL10n.string("root.section.memory.shortTitle")
        case .shortcuts:
            return KairoL10n.string("root.section.shortcuts.shortTitle")
        case .access:
            return KairoL10n.string("root.section.access.shortTitle")
        case .models:
            return KairoL10n.string("root.section.models.shortTitle")
        case .performance:
            return KairoL10n.string("root.section.performance.shortTitle")
        case .settings:
            return KairoL10n.string("root.section.settings.shortTitle")
        }
    }

    var chromeTitle: String {
        switch self {
        case .chat:
            return KairoL10n.string("root.section.chat.chromeTitle")
        default:
            return shortTitle
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "message.fill"
        case .wiki:
            return "sparkle.magnifyingglass"
        case .assets:
            return "archivebox.fill"
        case .pages:
            return "doc.richtext.fill"
        case .categories:
            return "folder.fill"
        case .memory:
            return "brain.head.profile"
        case .shortcuts:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .access:
            return "iphone"
        case .models:
            return "cpu"
        case .performance:
            return "speedometer"
        case .settings:
            return "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .wiki, .assets, .pages, .categories, .memory, .access:
            return KairoDesign.teal
        case .chat, .models, .performance:
            return KairoDesign.blue
        case .shortcuts:
            return KairoDesign.amber
        case .settings:
            return KairoDesign.muted
        }
    }
}

private extension RootSection {
    var isAdvancedNavigationSection: Bool {
        Self.advancedNavigationSections.contains(self)
    }

    init(_ section: KairoURLSection) {
        switch section {
        case .chat:
            self = .chat
        case .wiki:
            self = .wiki
        case .assets:
            self = .assets
        case .pages:
            self = .pages
        case .categories:
            self = .categories
        case .memory:
            self = .memory
        case .shortcuts:
            self = .shortcuts
        case .access:
            self = .access
        case .models:
            self = .models
        case .performance:
            self = .performance
        case .settings:
            self = .settings
        }
    }
}

private extension View {
    @ViewBuilder
    func glassCircleControl() -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .foregroundStyle(KairoDesign.ink)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(KairoDesign.elevatedSurface.opacity(0.12)).interactive(), in: .circle)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.34), radius: 10, x: 0, y: 6)
        } else {
            self
                .foregroundStyle(KairoDesign.ink)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(KairoDesign.elevatedSurface.opacity(0.72))
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 12, x: 0, y: 7)
        }
    }

    @ViewBuilder
    func glassCapsuleControl() -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(KairoDesign.elevatedSurface.opacity(0.12)), in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.34), radius: 10, x: 0, y: 6)
        } else {
            self
                .background {
                    Capsule()
                        .fill(KairoDesign.elevatedSurface.opacity(0.72))
                }
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 12, x: 0, y: 7)
        }
    }

    @ViewBuilder
    func rootNavigationGlassSurface(tint: Color, isInteractive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 18))
                    .overlay {
                        shape.stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: KairoDesign.shadow.opacity(0.28), radius: 12, x: 0, y: 7)
            } else {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: 18))
                    .overlay {
                        shape.stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: KairoDesign.shadow.opacity(0.24), radius: 10, x: 0, y: 6)
            }
        } else {
            self
                .background {
                    shape.fill(KairoDesign.elevatedSurface.opacity(0.72))
                }
                .overlay {
                    shape.stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 12, x: 0, y: 7)
        }
    }
}
#endif
