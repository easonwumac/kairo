#if canImport(SwiftUI)
import SwiftUI

public struct RootView: View {
    private let environment: KairoEnvironment
    private let rootDependencies: RootFeatureDependencies
    private let settingsMode: SettingsViewMode
    @State private var selectedSection: RootSection = .chat
    @State private var isMenuPresented = false

    public init(
        environment: KairoEnvironment = .preview(),
        initialSection: String? = nil,
        settingsMode: SettingsViewMode = .all
    ) {
        self.environment = environment
        self.rootDependencies = environment.rootFeatureDependencies
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

                selectedContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                rootHeader(topInset: safeAreaInsets.top)
                    .zIndex(5)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                if isMenuPresented {
                    drawerOverlay(safeAreaInsets: safeAreaInsets, containerWidth: proxy.size.width)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Self.fullScreenBackground.ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.fullScreenBackground.ignoresSafeArea())
        .onOpenURL { url in
            guard let openURLHandler = rootDependencies.openURLHandler else { return }
            Task {
                try? await openURLHandler.handle(url)
            }
        }
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
                    KairoDesign.blue.opacity(0.26),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            LinearGradient(
                colors: [
                    KairoDesign.teal.opacity(0.10),
                    Color.clear,
                    Color.black.opacity(0.18)
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
            ChatView(dependencies: environment.chatFeatureDependencies)
        case .memory:
            MemoryCenterView(dependencies: environment.memoryFeatureDependencies)
        case .shortcuts:
            AutomationsView(dependencies: environment.automationsFeatureDependencies)
        case .access:
            PermissionHubView(dependencies: environment.accessFeatureDependencies)
        case .models:
            SettingsView(
                dependencies: environment.settingsFeatureDependencies,
                mode: .modelsOnly,
                deletionAPI: nil
            )
        case .settings:
            SettingsView(
                dependencies: environment.settingsFeatureDependencies,
                mode: settingsMode
            )
        }
    }

    private func rootHeader(topInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    isMenuPresented = true
                }
            } label: {
                Label(KairoL10n.string("root.menu"), systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.title.weight(.semibold))
                    .glassCircleControl()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(KairoL10n.string("root.menu.open"))
            .accessibilityIdentifier("root.drawer.toggle")

            Text(selectedSection.chromeTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(1)
                .padding(.horizontal, 24)
                .frame(height: 58)
                .glassCapsuleControl()
                .accessibilityLabel(selectedSection.title)
                .accessibilityIdentifier("root.current-section")

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    isMenuPresented = true
                }
            } label: {
                Label(KairoL10n.string("root.moreActions"), systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.bold))
                    .glassCircleControl()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(KairoL10n.string("root.moreActions"))
            .accessibilityIdentifier("root.page-actions")
        }
        .padding(.horizontal, 16)
        .padding(.top, max(topInset, 0) + 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.safe-area-header")
    }

    private func drawerOverlay(safeAreaInsets: EdgeInsets, containerWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            navigationMenu(safeAreaInsets: safeAreaInsets)
                .frame(width: containerWidth, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(KairoDesign.background)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isMenuPresented = false
        }
    }

    private func navigationMenu(safeAreaInsets: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("root.menu.sheet")

                    HStack(spacing: 12) {
                        KairoMark(size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(KairoL10n.string("root.menu.title"))
                                .font(.title3.bold())
                            Text(KairoL10n.string("root.menu.subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            closeDrawer()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(KairoL10n.string("root.menu.close"))
                        .accessibilityIdentifier("root.drawer.close")
                    }

                    navigationGroup(
                        title: KairoL10n.string("root.menu.group.primary"),
                        sections: [.chat, .memory, .shortcuts]
                    )

                    navigationGroup(
                        title: KairoL10n.string("root.menu.group.system"),
                        sections: [.access, .models, .settings]
                    )

                    Text(KairoL10n.string("root.menu.privacyNote"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.top, max(safeAreaInsets.top, 0) + 8)
                .padding(.bottom, max(safeAreaInsets.bottom, 0) + 24)
            }
        }
        .background {
            ZStack(alignment: .leading) {
                Self.fullScreenBackground
                Rectangle()
                    .fill(KairoDesign.teal.opacity(0.16))
                    .frame(width: 10)
                    .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(KairoL10n.string("root.menu.accessibility"))
        .accessibilityIdentifier("root.drawer")
    }

    private func navigationRow(_ section: RootSection) -> some View {
        Button {
            selectedSection = section
            closeDrawer()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: section.systemImage)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selectedSection == section ? section.tint : .secondary)
                    .frame(width: 30, height: 30)

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

    private func navigationGroup(title: String, sections: [RootSection]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            KairoGroupedSurface {
                ForEach(sections) { section in
                    navigationRow(section)
                    if section != sections.last {
                        Divider()
                            .padding(.leading, 46)
                    }
                }
            }
        }
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
            return KairoL10n.string("root.section.chat.title")
        case .memory:
            return KairoL10n.string("root.section.memory.title")
        case .shortcuts:
            return KairoL10n.string("root.section.shortcuts.title")
        case .access:
            return KairoL10n.string("root.section.access.title")
        case .models:
            return KairoL10n.string("root.section.models.title")
        case .settings:
            return KairoL10n.string("root.section.settings.title")
        }
    }

    var subtitle: String {
        switch self {
        case .chat:
            return KairoL10n.string("root.section.chat.subtitle")
        case .memory:
            return KairoL10n.string("root.section.memory.subtitle")
        case .shortcuts:
            return KairoL10n.string("root.section.shortcuts.subtitle")
        case .access:
            return KairoL10n.string("root.section.access.subtitle")
        case .models:
            return KairoL10n.string("root.section.models.subtitle")
        case .settings:
            return KairoL10n.string("root.section.settings.subtitle")
        }
    }

    var shortTitle: String {
        switch self {
        case .chat:
            return KairoL10n.string("root.section.chat.shortTitle")
        case .memory:
            return KairoL10n.string("root.section.memory.shortTitle")
        case .shortcuts:
            return KairoL10n.string("root.section.shortcuts.shortTitle")
        case .access:
            return KairoL10n.string("root.section.access.shortTitle")
        case .models:
            return KairoL10n.string("root.section.models.shortTitle")
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
        case .memory:
            return "brain.head.profile"
        case .shortcuts:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .access:
            return "iphone"
        case .models:
            return "cpu"
        case .settings:
            return "gearshape"
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

private extension View {
    func glassCircleControl() -> some View {
        self
            .foregroundStyle(KairoDesign.ink)
            .frame(width: 64, height: 64)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(Color.black.opacity(0.34))
                    }
            }
            .overlay {
                Circle()
                    .stroke(kairoGlassControlStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.34), radius: 22, x: 0, y: 12)
    }

    func glassCapsuleControl() -> some View {
        self
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(Color.black.opacity(0.34))
                    }
            }
            .overlay {
                Capsule()
                    .stroke(kairoGlassControlStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.34), radius: 22, x: 0, y: 12)
    }
}

private var kairoGlassControlStroke: LinearGradient {
    LinearGradient(
        colors: [
            Color.white.opacity(0.34),
            Color.white.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
#endif
