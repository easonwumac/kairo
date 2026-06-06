#if canImport(SwiftUI)
import SwiftUI

public struct PermissionHubView: View {
    @State private var pageStack: [PermissionHubPage] = []
    @State private var homeKitPreviewMessage: String?
    @State private var skillManagerMessage: String?
    @State private var manifestImportText = ""
    @State private var manifestInstallPreview: AgentSkillInstallPreview?
    @State private var isRefreshingMarketplace = false
    @State private var localSkillName = ""
    @State private var localSkillSummary = ""
    @State private var localSkillCapability: CapabilityKey = .appIntents
    @State private var localSkillConfirmationPolicy: AgentSkillConfirmationPolicy = .previewRequired
    @State private var skillSearchText = ""
    @State private var isAdvancedSkillSetupExpanded = false
    @State private var isDeveloperSkillSetupExpanded = false
    @State private var isHomeKitPreviewExpanded = false
    @State private var isAccessStatusExpanded = false
    @State private var showMorePrimaryTools = false
    @State private var expandedCapabilityDetails: Set<CapabilityKey> = []
    @State private var expandedSkillDetails: Set<String> = []
    @State private var skillCatalog: AgentSkillCatalog
    @State private var accessToolSummaries: [KairoAccessToolSummary] = []
    @State private var accessIntegrationSummaries: [KairoAccessIntegrationSummary] = []
    @State private var capabilityPolicies: [CapabilityKey: CapabilityToolPolicy] = [:]

    private let registry: any CapabilityRegistryProviding
    private let homeKitDemoCatalog = HomeKitControlDemoCatalog.default
    private let accessAPI: (any KairoAccessAPI)?
    private let skillManagerService: AgentSkillManagerService?
    private let marketplaceCatalogService: AgentSkillMarketplaceCatalogService?
    @Binding private var rootChromeBackRequestID: Int
    private let usesRootChromeNavigation: Bool

    public init(
        dependencies: AccessFeatureDependencies,
        rootChromeBackRequestID: Binding<Int> = .constant(0),
        usesRootChromeNavigation: Bool = false
    ) {
        self.accessAPI = dependencies.accessAPI
        self.skillManagerService = dependencies.skillManagerService
        self.marketplaceCatalogService = dependencies.marketplaceCatalogService
        self.registry = dependencies.capabilityRegistry
        self._rootChromeBackRequestID = rootChromeBackRequestID
        self.usesRootChromeNavigation = usesRootChromeNavigation
        _skillCatalog = State(initialValue: dependencies.initialSkillCatalog)
    }

    public init(
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples,
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry()
    ) {
        self.init(
            dependencies: AccessFeatureDependencyFactory().makeDependencies(
                skillManagerService: skillManagerService,
                marketplaceCatalogService: marketplaceCatalogService,
                initialSkillCatalog: initialSkillCatalog,
                capabilityRegistry: capabilityRegistry
            ),
            rootChromeBackRequestID: .constant(0),
            usesRootChromeNavigation: false
        )
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    if let activePage {
                        pageView(for: activePage)
                    } else {
                        hubHome
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
                .padding(.bottom, 32)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .kairoHiddenNavigationChrome()
            .task {
                await loadAccessData()
            }
            .preference(key: RootChromePreferenceKey.self, value: rootChromeContext)
            .onChange(of: rootChromeBackRequestID) { _, _ in
                popPage()
            }
        }
    }

    private var activePage: PermissionHubPage? {
        pageStack.last
    }

    private var rootChromeContext: RootChromeContext {
        guard usesRootChromeNavigation, let activePage else {
            return .standard
        }
        return RootChromeContext(
            leadingAction: .back,
            title: activePage.title
        )
    }

    private var hubHome: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionHubEntryCard(
                title: KairoL10n.string("access.capabilities.section"),
                subtitle: KairoL10n.string("access.capabilities.entry.subtitle"),
                systemImage: "iphone.gen3",
                tint: KairoDesign.blue
            ) {
                pushPage(.phoneActions)
            }

            permissionHubEntryCard(
                title: KairoL10n.string("access.skills.advanced.toggle.title"),
                subtitle: KairoL10n.string("access.skills.advanced.toggle.subtitle"),
                systemImage: "slider.horizontal.3",
                tint: KairoDesign.teal
            ) {
                pushPage(.managedTools)
            }
        }
    }

    @ViewBuilder
    private func pageView(for page: PermissionHubPage) -> some View {
        switch page {
        case .phoneActions:
            primaryToolsPage
        case .managedTools:
            managedToolsPage
        }
    }

    private func pushPage(_ page: PermissionHubPage) {
        withAnimation(.snappy(duration: 0.2)) {
            pageStack.append(page)
        }
    }

    private func popPage() {
        guard !pageStack.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            _ = pageStack.popLast()
        }
    }

    private var accessOverviewCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(KairoL10n.string("access.overview.title"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(KairoDesign.ink)
                }

                KairoStatusPill(
                    title: KairoL10n.string("access.status.ready", Int64(readyCapabilityCount)),
                    systemImage: "checkmark.circle.fill",
                    tint: KairoDesign.green
                )

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isAccessStatusExpanded.toggle()
                    }
                } label: {
                    disclosureHeader(
                        title: KairoL10n.string("access.status.details.title"),
                        isExpanded: isAccessStatusExpanded
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("access.status.details.toggle")

                if isAccessStatusExpanded {
                    HStack(spacing: 8) {
                        KairoStatusPill(
                            title: KairoL10n.string("access.status.reviewFirst"),
                            systemImage: "checkmark.shield.fill",
                            tint: KairoDesign.blue
                        )
                        KairoStatusPill(
                            title: KairoL10n.string("access.status.needsSetup", Int64(needsSetupCapabilityCount)),
                            systemImage: "wrench.and.screwdriver.fill",
                            tint: KairoDesign.amber
                        )
                    }
                    KairoStatusPill(
                        title: KairoL10n.string("access.status.unavailable", Int64(unavailableCapabilityCount)),
                        systemImage: "nosign",
                        tint: KairoDesign.red
                    )
                    .accessibilityIdentifier("access.status.unavailable")
                }
            }
        }
        .accessibilityIdentifier("access.overview.card")
    }

    private var primaryToolsPage: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                accessSectionTitle(
                    title: KairoL10n.string("access.capabilities.section")
                )
                .accessibilityIdentifier("access.capabilities.section")

                ForEach(primaryCapabilities) { capability in
                    capabilityRow(capability, forceExpanded: true)
                    if capability.key != primaryCapabilities.last?.key {
                        Divider()
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var managedToolsPage: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                skillManagerContent
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var developerSetupDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    isDeveloperSkillSetupExpanded.toggle()
                }
            } label: {
                disclosureHeader(
                    title: KairoL10n.string("access.skills.advanced.title"),
                    isExpanded: isDeveloperSkillSetupExpanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("access.skills.developer.toggle")

            if isDeveloperSkillSetupExpanded {
                Text(KairoL10n.string("access.skills.advanced.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                developerSetupContent
            }
        }
    }

    private var developerSetupContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            manifestImportControls()

            if let manifestInstallPreview {
                Divider()
                manifestPreview(manifestInstallPreview)
            }
        }
    }

    private var homeKitPreviewDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    isHomeKitPreviewExpanded.toggle()
                }
            } label: {
                disclosureHeader(
                    title: KairoL10n.string("access.homekit.demos.title"),
                    isExpanded: isHomeKitPreviewExpanded
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("access.homekit.demos.toggle")

            if isHomeKitPreviewExpanded {
                homeKitPreviewContent
            }
        }
    }

    private var skillManagerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(KairoL10n.string("access.skills.manager.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .accessibilityIdentifier("access.skills.manager")
            }

            skillSearchControls()

            if let skillManagerMessage {
                Text(skillManagerMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("access.skills.message")
            }

            ForEach(filteredSkills) { skill in
                Divider()
                skillManagerRow(skill)
            }
        }
    }

    private var homeKitPreviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(KairoL10n.string("access.homekit.demos.title"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.homekit.demos")

            ForEach(homeKitDemoCatalog.recipes) { recipe in
                homeKitDemoRow(recipe)
                if recipe.id != homeKitDemoCatalog.recipes.last?.id {
                    Divider()
                }
            }

            if let homeKitPreviewMessage {
                Text(homeKitPreviewMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func accessSectionTitle(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func permissionHubEntryCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            KairoFocusCard {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func disclosureHeader(title: String, subtitle: String? = nil, isExpanded: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func capabilityRow(_ capability: Capability, forceExpanded: Bool = false) -> some View {
        let isExpanded = expandedCapabilityDetails.contains(capability.key)

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName(for: capability.key))
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(capabilityTint(for: capability))
                .frame(width: 30, height: 30)
                .background(capabilityTint(for: capability).opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(capability.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .accessibilityIdentifier("access.capability.\(capability.key.rawValue).name")
                    Spacer(minLength: 8)
                    Text(policyLabel(for: capability))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(policyTint(for: capability))

                    if !forceExpanded {
                        Button {
                            toggleCapabilityDetails(capability.key)
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.blue)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isExpanded
                            ? KairoL10n.string("access.capability.details.hide")
                            : KairoL10n.string("access.capability.details.show")
                        )
                        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
                        .accessibilityIdentifier("access.capability.\(capability.key.rawValue).details")
                    }
                }

                capabilityPolicyPicker(capability)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func capabilityPolicyPicker(_ capability: Capability) -> some View {
        Picker(
            KairoL10n.string("access.policy.picker", capability.displayName),
            selection: Binding(
                get: { selectedPolicy(for: capability) },
                set: { newValue in
                    setCapabilityPolicy(newValue, for: capability)
                }
            )
        ) {
            ForEach(DefaultCapabilityToolPolicyProvider.choices(for: capability.permission), id: \.self) { policy in
                Text(policy.displayName).tag(policy)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("access.capability.\(capability.key.rawValue).policy")
    }

    private func toggleCapabilityDetails(_ key: CapabilityKey) {
        withAnimation(.snappy(duration: 0.2)) {
            if expandedCapabilityDetails.contains(key) {
                expandedCapabilityDetails.remove(key)
            } else {
                expandedCapabilityDetails.insert(key)
            }
        }
    }

    private func shouldShowFallbackMessage(for capability: Capability) -> Bool {
        switch capability.status {
        case .denied, .restricted, .unsupported:
            return true
        case .available, .unknown:
            return false
        }
    }

    private func selectedPolicy(for capability: Capability) -> CapabilityToolPolicy {
        DefaultCapabilityToolPolicyProvider.normalized(
            capabilityPolicies[capability.key] ?? DefaultCapabilityToolPolicyProvider.defaultPolicy(for: capability.permission),
            permission: capability.permission
        )
    }

    private func policyLabel(for capability: Capability) -> String {
        selectedPolicy(for: capability).displayName
    }

    private func policyTint(for capability: Capability) -> Color {
        switch selectedPolicy(for: capability) {
        case .allow:
            return KairoDesign.green
        case .askEveryTime:
            return KairoDesign.blue
        case .deny:
            return KairoDesign.red
        }
    }

    private func setCapabilityPolicy(_ policy: CapabilityToolPolicy, for capability: Capability) {
        let normalizedPolicy = DefaultCapabilityToolPolicyProvider.normalized(policy, permission: capability.permission)
        capabilityPolicies[capability.key] = normalizedPolicy

        Task {
            do {
                _ = try await accessAPI?.setPolicy(normalizedPolicy, for: capability.key)
                await loadAccessData()
            } catch {
                await MainActor.run {
                    capabilityPolicies[capability.key] = selectedPolicy(for: capability)
                    skillManagerMessage = KairoL10n.string("access.policy.message.updateFailed", error.localizedDescription)
                }
            }
        }
    }

    private var primaryCapabilities: [Capability] {
        let priority: [CapabilityKey] = [
            .shareExtension,
            .memory,
            .reminders,
            .calendar,
            .mail,
            .messages,
            .web,
            .location
        ]
        return priority.compactMap { key in
            registry.capabilities.first { $0.key == key }
        }
    }

    private var visiblePrimaryCapabilities: [Capability] {
        Array(primaryCapabilities.prefix(4))
    }

    private var secondaryPrimaryCapabilities: [Capability] {
        Array(primaryCapabilities.dropFirst(4))
    }

    private var readyCapabilityCount: Int {
        registry.capabilities.filter { $0.status == .available }.count
    }

    private var needsSetupCapabilityCount: Int {
        registry.capabilities.filter { capability in
            switch capability.permission {
            case .runtimePrompt, .entitlement, .oauth:
                return capability.status != .unsupported
            case .none, .userInitiated, .unsupported:
                return false
            }
        }.count
    }

    private var unavailableCapabilityCount: Int {
        registry.capabilities.filter { capability in
            switch capability.status {
            case .denied, .restricted, .unsupported:
                return true
            case .available, .unknown:
                return false
            }
        }.count
    }

    private func toolSummaries(for capabilityKey: CapabilityKey) -> [KairoAccessToolSummary] {
        accessToolSummaries.filter { summary in
            summary.capabilityStatuses.keys.contains(capabilityKey)
        }
    }

    private func integrationSummaries(for capabilityKey: CapabilityKey) -> [KairoAccessIntegrationSummary] {
        accessIntegrationSummaries.filter { summary in
            summary.capabilityStatuses.keys.contains(capabilityKey)
        }
    }

    private func iconName(for key: CapabilityKey) -> String {
        switch key {
        case .chat:
            return "message.fill"
        case .memory:
            return "brain.head.profile"
        case .shareExtension:
            return "square.and.arrow.down"
        case .appIntents:
            return "wand.and.stars"
        case .integrationRegistry, .externalConnectors:
            return "person.crop.circle.badge.checkmark"
        case .backgroundTasks:
            return "clock.arrow.circlepath"
        case .notifications:
            return "bell"
        case .calendar:
            return "calendar"
        case .reminders:
            return "checklist"
        case .contacts:
            return "person.crop.circle"
        case .mail:
            return "envelope"
        case .messages:
            return "bubble.left.and.bubble.right"
        case .phone:
            return "phone"
        case .photos:
            return "photo"
        case .documents:
            return "doc.text"
        case .web:
            return "safari"
        case .location:
            return "location"
        case .homeKit:
            return "house"
        }
    }

    private func capabilityTint(for capability: Capability) -> Color {
        switch capability.status {
        case .available:
            return KairoDesign.teal
        case .denied, .restricted, .unsupported:
            return KairoDesign.red
        case .unknown:
            return capability.isMVP ? KairoDesign.blue : .secondary
        }
    }

    private func permissionLabel(for permission: PermissionRequirement) -> String {
        switch permission {
        case .none:
            return KairoL10n.string("access.permission.none")
        case .userInitiated:
            return KairoL10n.string("access.permission.userInitiated")
        case .runtimePrompt:
            return KairoL10n.string("access.permission.runtimePrompt")
        case .entitlement:
            return KairoL10n.string("access.permission.entitlement")
        case .oauth:
            return KairoL10n.string("access.permission.oauth")
        case .unsupported:
            return KairoL10n.string("access.permission.unsupported")
        }
    }

    @ViewBuilder
    private func advancedSkillSetupToggle() -> some View {
        Button {
            withAnimation(.snappy) {
                isAdvancedSkillSetupExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(KairoDesign.blue)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(KairoL10n.string("access.skills.advanced.toggle.title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(KairoL10n.string("access.skills.advanced.toggle.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: isAdvancedSkillSetupExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("access.skills.advanced.toggle")
        .accessibilityLabel(KairoL10n.string("access.skills.advanced.toggle.title"))
        .accessibilityValue(isAdvancedSkillSetupExpanded ? KairoL10n.string("access.skills.advanced.toggle.expanded") : KairoL10n.string("access.skills.advanced.toggle.collapsed"))
    }

    @ViewBuilder
    private func manifestImportControls() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("access.skills.manifestImport.title"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.manifest-import")

            TextField(KairoL10n.string("access.skills.localCreate.namePlaceholder"), text: $localSkillName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("access.skills.local-create.name")

            TextField(KairoL10n.string("access.skills.localCreate.summaryPlaceholder"), text: $localSkillSummary, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(10)
                .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("access.skills.local-create.summary")

            Picker(KairoL10n.string("access.skills.localCreate.capability"), selection: $localSkillCapability) {
                ForEach(CapabilityKey.allCases, id: \.self) { capability in
                    Text(capability.rawValue).tag(capability)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("access.skills.local-create.capability")

            Picker(KairoL10n.string("access.skills.localCreate.confirmation"), selection: $localSkillConfirmationPolicy) {
                ForEach(AgentSkillConfirmationPolicy.allCases, id: \.self) { policy in
                    Text(policy.settingsTitle).tag(policy)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("access.skills.local-create.confirmation-policy")

            Button {
                Task {
                    await createLocalSkillDraft()
                }
            } label: {
                Label(KairoL10n.string("access.skills.localCreate.createDraft"), systemImage: "plus.circle")
            }
            .disabled(localSkillName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
            .accessibilityIdentifier("access.skills.local-create.button")

            Button {
                Task {
                    await refreshMarketplaceCatalog()
                }
            } label: {
                Label(KairoL10n.string("access.skills.marketplace.refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshingMarketplace || marketplaceCatalogService == nil)
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.teal, isCompact: true))
            .accessibilityIdentifier("access.skills.marketplace-refresh")

            TextEditor(text: $manifestImportText)
                .frame(minHeight: 84)
                .font(.caption)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("access.skills.manifest-import.text")

            Button {
                Task {
                    await previewManifestText()
                }
            } label: {
                Label(KairoL10n.string("access.skills.manifestImport.preview"), systemImage: "doc.text.magnifyingglass")
            }
            .disabled(manifestImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
            .accessibilityIdentifier("access.skills.manifest-import.button")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func skillSearchControls() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(KairoL10n.string("access.skills.search.placeholder"), text: $skillSearchText)
                .accessibilityIdentifier("access.skills.search")

            Text(skillSearchSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.search.summary")
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func createLocalSkillDraft() async {
        let request = AgentSkillDraftRequest(
            displayName: localSkillName,
            summary: localSkillSummary,
            kind: .custom,
            requiredCapabilities: [localSkillCapability],
            confirmationPolicy: localSkillConfirmationPolicy
        )

        guard let skillManagerService else {
            do {
                let draft = try previewLocalSkillDraft(from: request)
                skillCatalog = skillCatalog.replacing(draft)
                localSkillName = ""
                localSkillSummary = ""
                localSkillCapability = .appIntents
                localSkillConfirmationPolicy = .previewRequired
                manifestInstallPreview = nil
                skillManagerMessage = KairoL10n.string("access.skills.message.draftSaved", draft.displayName)
            } catch AgentSkillDraftError.emptyDisplayName {
                skillManagerMessage = KairoL10n.string("access.skills.message.skillNameRequired")
            } catch AgentSkillDraftError.missingCapabilitySelection {
                skillManagerMessage = KairoL10n.string("access.skills.message.capabilityRequired")
            } catch AgentSkillDraftError.missingConfirmationPolicy {
                skillManagerMessage = KairoL10n.string("access.skills.message.confirmationRequired")
            } catch {
                skillManagerMessage = KairoL10n.string("access.skills.message.createDraftFailed")
            }
            return
        }

        do {
            let draft = try await skillManagerService.createUserSkillDraft(request)
            skillCatalog = try await skillManagerService.catalog()
            localSkillName = ""
            localSkillSummary = ""
            localSkillCapability = .appIntents
            localSkillConfirmationPolicy = .previewRequired
            manifestInstallPreview = nil
            skillManagerMessage = KairoL10n.string("access.skills.message.draftSaved", draft.displayName)
        } catch AgentSkillDraftError.emptyDisplayName {
            skillManagerMessage = KairoL10n.string("access.skills.message.skillNameRequired")
        } catch AgentSkillDraftError.missingCapabilitySelection {
            skillManagerMessage = KairoL10n.string("access.skills.message.capabilityRequired")
        } catch AgentSkillDraftError.missingConfirmationPolicy {
            skillManagerMessage = KairoL10n.string("access.skills.message.confirmationRequired")
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.createDraftFailed")
        }
    }

    private func previewLocalSkillDraft(from request: AgentSkillDraftRequest) throws -> AgentSkill {
        let trimmedName = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AgentSkillDraftError.emptyDisplayName }
        guard !request.requiredCapabilities.isEmpty else { throw AgentSkillDraftError.missingCapabilitySelection }
        guard let confirmationPolicy = request.confirmationPolicy else { throw AgentSkillDraftError.missingConfirmationPolicy }

        let trimmedSummary = request.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackID = "user-\(trimmedName.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return AgentSkill(
            id: fallbackID,
            displayName: trimmedName,
            summary: trimmedSummary.isEmpty ? KairoL10n.string("access.skills.localCreate.defaultSummary") : trimmedSummary,
            kind: request.kind,
            source: .userCreated,
            installationStatus: .disabled,
            requiredCapabilities: request.requiredCapabilities,
            shortcutRecipeID: request.shortcutRecipeID,
            version: "local-draft",
            author: "User",
            confirmationPolicy: confirmationPolicy,
            compatibilityRequirements: request.compatibilityRequirements
        )
    }

    @ViewBuilder
    private func manifestPreview(_ manifestInstallPreview: AgentSkillInstallPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(manifestInstallPreview.summary)
                .font(.caption)
                .fontWeight(.medium)
                .accessibilityIdentifier("access.skills.manifest-preview.summary")

            Text(manifestPreviewVersionSummary(manifestInstallPreview))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("access.skills.manifest-preview.version")

            Text(manifestInstallPreview.compatibilityReport.summary)
                .font(.caption2)
                .foregroundStyle(manifestInstallPreview.compatibilityReport.isInstallable ? Color.secondary : Color.red)
                .accessibilityIdentifier("access.skills.manifest-preview.compatibility")

            ForEach(manifestInstallPreview.compatibilityReport.issues) { issue in
                Text("- \(issue.message)")
                    .font(.caption2)
                    .foregroundStyle(issue.severity == .blocking ? .red : .secondary)
                    .accessibilityIdentifier("access.skills.manifest-preview.compatibility.\(issue.kind.rawValue)")
            }

            if manifestInstallPreview.changelog.isEmpty {
                Text(KairoL10n.string("access.skills.manifestPreview.noChangelog"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("access.skills.manifest-preview.changelog.empty")
            } else {
                ForEach(manifestInstallPreview.changelog, id: \.self) { item in
                    Text("- \(item)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("access.skills.manifest-preview.changelog")
                }
            }

            Button {
                Task {
                    await confirmManifestInstall()
                }
            } label: {
                Label(KairoL10n.string("access.skills.manifestPreview.confirmInstall"), systemImage: "checkmark.circle")
            }
            .font(.caption)
            .disabled(
                manifestInstallPreview.installationChange == .downgradeBlocked
                || !manifestInstallPreview.compatibilityReport.isInstallable
            )
            .accessibilityIdentifier("access.skills.manifest-preview.confirm")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("access.skills.manifest-preview")
    }

    private func manifestPreviewVersionSummary(_ manifestInstallPreview: AgentSkillInstallPreview) -> String {
        if let installedVersion = manifestInstallPreview.installedVersion {
            return KairoL10n.string("access.skills.manifestPreview.versionUpdate", installedVersion, manifestInstallPreview.incomingVersion)
        }

        return KairoL10n.string("access.skills.manifestPreview.versionIncoming", manifestInstallPreview.incomingVersion)
    }

    @ViewBuilder
    private func skillManagerRow(_ skill: AgentSkill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                KairoStatusPill(
                    title: skill.installationStatus.rawValue,
                    systemImage: skillStatusIcon(for: skill),
                    tint: skillStatusTint(for: skill)
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                primarySkillActionButton(for: skill)

                if skill.installationStatus == .installed {
                    skillActionButton(
                        title: KairoL10n.string("access.skills.action.disable"),
                        systemImage: "pause.circle",
                        accessibilityIdentifier: "access.skill.\(skill.id).disable"
                    ) {
                        Task {
                            await disableSkill(skill)
                        }
                    }
                }

                skillActionButton(
                    title: KairoL10n.string("access.skills.action.remove"),
                    systemImage: "trash",
                    role: .destructive,
                    tint: KairoDesign.red,
                    accessibilityIdentifier: "access.skill.\(skill.id).remove"
                ) {
                    Task {
                        await removeSkill(skill)
                    }
                }
            }

            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(skill.managementSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("access.skill.\(skill.id).summary")

                    if skill.kind == .homeKitControl {
                        Text(KairoL10n.string("access.skills.homekit.previewOnly"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.amber)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("access.skill.\(skill.id).homekit-boundary")
                    }
                }
            } icon: {
                Image(systemName: skill.kind == .homeKitControl ? "house.badge.exclamationmark" : "checklist.checked")
                    .foregroundStyle(skill.kind == .homeKitControl ? KairoDesign.amber : KairoDesign.teal)
            }
            .padding(10)
            .background(KairoDesign.softSurface.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("access.skill.\(skill.id)")
    }

    @ViewBuilder
    private func primarySkillActionButton(for skill: AgentSkill) -> some View {
        switch skill.installationStatus {
        case .available:
            skillActionButton(
                title: KairoL10n.string("access.skills.action.install"),
                systemImage: "square.and.arrow.down",
                accessibilityIdentifier: "access.skill.\(skill.id).install"
            ) {
                Task {
                    await installSkill(skill)
                }
            }
        case .installed:
            if skill.source == .marketplace, skill.downloadURL != nil {
                skillActionButton(
                    title: KairoL10n.string("access.skills.action.previewUpdate"),
                    systemImage: "arrow.triangle.2.circlepath",
                    accessibilityIdentifier: "access.skill.\(skill.id).update"
                ) {
                    Task {
                        await installSkill(skill)
                    }
                }
            }
        case .disabled:
            skillActionButton(
                title: KairoL10n.string("access.skills.action.enable"),
                systemImage: "play.circle",
                accessibilityIdentifier: "access.skill.\(skill.id).enable"
            ) {
                Task {
                    await enableSkill(skill)
                }
            }
        }
    }

    private func isSkillDetailsExpanded(_ skillID: String) -> Bool {
        expandedSkillDetails.contains(skillID)
    }

    private func toggleSkillDetails(_ skillID: String) {
        if expandedSkillDetails.contains(skillID) {
            expandedSkillDetails.remove(skillID)
        } else {
            expandedSkillDetails.insert(skillID)
        }
    }

    private func skillActionButton(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        tint: Color = KairoDesign.blue,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .center)
        }
        .buttonStyle(KairoGlassButtonStyle(tint: tint, isCompact: true))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func skillStatusIcon(for skill: AgentSkill) -> String {
        switch skill.installationStatus {
        case .available:
            return "square.and.arrow.down"
        case .installed:
            return "checkmark.seal.fill"
        case .disabled:
            return "pause.circle.fill"
        }
    }

    private func skillStatusTint(for skill: AgentSkill) -> Color {
        switch skill.installationStatus {
        case .available:
            return KairoDesign.blue
        case .installed:
            return KairoDesign.green
        case .disabled:
            return KairoDesign.amber
        }
    }

    private var filteredSkills: [AgentSkill] {
        let query = normalizedSkillSearchText
        let visibleSkills = skillCatalog.skills.filter { $0.kind != .homeKitControl }
        guard !query.isEmpty else {
            return visibleSkills
        }
        return visibleSkills.filter { skillMatchesSearch($0, query: query) }
    }

    private var normalizedSkillSearchText: String {
        skillSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var skillSearchSummary: String {
        let total = skillCatalog.skills.filter { $0.kind != .homeKitControl }.count
        let filtered = filteredSkills.count
        if normalizedSkillSearchText.isEmpty {
            return KairoL10n.string("access.skills.search.summary.all", Int64(total))
        }
        if filtered == 1, let skill = filteredSkills.first {
            return KairoL10n.string("access.skills.search.summary.one", Int64(total), skill.displayName)
        }
        return KairoL10n.string("access.skills.search.summary.many", Int64(filtered), Int64(total))
    }

    private func skillMatchesSearch(_ skill: AgentSkill, query: String) -> Bool {
        [
            skill.id,
            skill.displayName,
            skill.summary,
            skill.kind.settingsTitle,
            skill.source.rawValue,
            skill.installationStatus.rawValue
        ]
            .map { $0.lowercased() }
            .contains { $0.contains(query) }
    }

    @MainActor
    private func refreshMarketplaceCatalog() async {
        guard let marketplaceCatalogService else {
            skillManagerMessage = KairoL10n.string("access.skills.message.marketplaceSourceRequired")
            return
        }

        isRefreshingMarketplace = true
        defer { isRefreshingMarketplace = false }

        do {
            let remoteCatalog = try await marketplaceCatalogService.fetchCatalog()
            skillCatalog = skillCatalog.mergingMarketplaceCatalog(remoteCatalog.catalog)
            skillManagerMessage = KairoL10n.string("access.skills.message.marketplaceLoaded", Int64(remoteCatalog.catalog.skills.count), remoteCatalog.sourceRepository.host ?? KairoL10n.string("access.skills.message.repositoryFallback"))
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.marketplaceRefreshFailed", error.localizedDescription)
        }
    }

    @MainActor
    private func previewManifestText() async {
        let trimmedManifest = manifestImportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedManifest.isEmpty else {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestEmpty")
            manifestInstallPreview = nil
            return
        }
        guard let skillManagerService else {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRequiresLiveManager")
            manifestInstallPreview = nil
            return
        }

        do {
            let preview = try await skillManagerService.previewInstall(jsonString: manifestImportText)
            manifestInstallPreview = preview
            isDeveloperSkillSetupExpanded = true
            skillManagerMessage = preview.summary
        } catch AgentSkillManifestImportError.invalidJSON {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidJSON")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidSignature")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRevokedKey")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyPendingPublication(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestPendingPublication")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyNotYetValid")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyExpired")
            manifestInstallPreview = nil
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestImportFailed")
            manifestInstallPreview = nil
        }
    }

    @MainActor
    private func confirmManifestInstall() async {
        guard let manifestInstallPreview else {
            skillManagerMessage = KairoL10n.string("access.skills.message.previewBeforeInstall")
            return
        }
        guard manifestInstallPreview.installationChange != .downgradeBlocked else {
            skillManagerMessage = manifestInstallPreview.summary
            return
        }
        guard let skillManagerService else {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRequiresLiveManager")
            return
        }

        do {
            let installed = try await skillManagerService.install(manifest: manifestInstallPreview.manifest)
            skillCatalog = try await skillManagerService.catalog()
            manifestImportText = ""
            self.manifestInstallPreview = nil
            skillManagerMessage = KairoL10n.string("access.skills.message.installedFromManifest", installed.displayName)
        } catch AgentSkillInstallError.versionDowngrade(_, let installedVersion, let incomingVersion) {
            skillManagerMessage = KairoL10n.string("access.skills.message.downgradeBlocked", installedVersion, incomingVersion)
        } catch AgentSkillInstallError.compatibilityBlocked(_, let issues) {
            skillManagerMessage = issues.map(\.message).joined(separator: "; ")
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidSignature")
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRevokedKey")
        } catch AgentSkillManifestValidationError.signingKeyPendingPublication(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestPendingPublication")
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyNotYetValid")
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyExpired")
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestImportFailed")
        }
    }

    @MainActor
    private func loadAccessData() async {
        await loadToolSummaries()
        await loadCapabilityPolicies()
        await loadSkillCatalog()
    }

    @MainActor
    private func loadToolSummaries() async {
        guard let accessAPI else { return }
        accessToolSummaries = await accessAPI.tools()
        accessIntegrationSummaries = await accessAPI.appIntegrations()
    }

    @MainActor
    private func loadCapabilityPolicies() async {
        guard let accessAPI else { return }
        var policies: [CapabilityKey: CapabilityToolPolicy] = [:]
        for capability in registry.capabilities {
            policies[capability.key] = await accessAPI.policy(for: capability.key)
        }
        capabilityPolicies = policies
    }

    @MainActor
    private func loadSkillCatalog() async {
        guard let skillManagerService else { return }

        do {
            skillCatalog = try await skillManagerService.catalog()
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.loadFailed")
        }
    }

    @MainActor
    private func installSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = KairoL10n.string("access.skills.message.installed", skill.displayName)
            return
        }

        guard let marketplaceCatalogService, skill.downloadURL != nil else {
            skillManagerMessage = KairoL10n.string("access.skills.message.signedManifestRequired", skill.displayName)
            return
        }

        do {
            let manifest = try await marketplaceCatalogService.fetchManifest(for: skill)
            let preview = try await skillManagerService.previewInstall(manifest: manifest)
            manifestInstallPreview = preview
            isDeveloperSkillSetupExpanded = true
            skillManagerMessage = preview.summary
        } catch AgentSkillManifestImportError.invalidJSON {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidJSON")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.invalidSignature {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestInvalidSignature")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.revokedSigningKey(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestRevokedKey")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyPendingPublication(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestPendingPublication")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyNotYetValid(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyNotYetValid")
            manifestInstallPreview = nil
        } catch AgentSkillManifestValidationError.signingKeyExpired(_) {
            skillManagerMessage = KairoL10n.string("access.skills.message.manifestKeyExpired")
            manifestInstallPreview = nil
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.previewFailed", skill.displayName)
            manifestInstallPreview = nil
        }
    }

    @MainActor
    private func disableSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .disabled)
            skillManagerMessage = KairoL10n.string("access.skills.message.disabled", skill.displayName)
            return
        }

        do {
            _ = try await skillManagerService.disableSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = KairoL10n.string("access.skills.message.disabled", skill.displayName)
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.disableFailed", skill.displayName)
        }
    }

    @MainActor
    private func enableSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.updatingStatus(id: skill.id, to: .installed)
            skillManagerMessage = KairoL10n.string("access.skills.message.enabled", skill.displayName)
            return
        }

        do {
            _ = try await skillManagerService.enableSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = KairoL10n.string("access.skills.message.enabled", skill.displayName)
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.enableFailed", skill.displayName)
        }
    }

    @MainActor
    private func removeSkill(_ skill: AgentSkill) async {
        guard let skillManagerService else {
            skillCatalog = skillCatalog.removingSkill(id: skill.id)
            skillManagerMessage = KairoL10n.string("access.skills.message.removed", skill.displayName)
            return
        }

        do {
            try await skillManagerService.removeSkill(id: skill.id)
            skillCatalog = try await skillManagerService.catalog()
            skillManagerMessage = KairoL10n.string("access.skills.message.removed", skill.displayName)
        } catch {
            skillManagerMessage = KairoL10n.string("access.skills.message.removeFailed", skill.displayName)
        }
    }

    @ViewBuilder
    private func homeKitDemoRow(_ recipe: HomeKitControlDemoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recipe.targetSummary)
                .font(.caption)
                .accessibilityIdentifier("access.homekit.demo.\(recipe.id)")

            Text(recipe.sandboxNotes)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(KairoL10n.string("access.homekit.demo.previewConfirmation")) {
                homeKitPreviewMessage = recipe.confirmationSummary
            }
            .accessibilityIdentifier("access.homekit.demo.\(recipe.id).confirm")
        }
        .padding(.vertical, 4)
    }
}

private struct AccessToolChipView: View {
    let summary: KairoAccessToolSummary

    var body: some View {
        Text(summary.readiness.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(chipForeground)
            .background(chipForeground.opacity(0.15), in: Capsule())
            .accessibilityLabel(summary.displayName)
            .accessibilityValue(summary.readiness.displayName)
            .accessibilityIdentifier("access.tool.\(summary.toolID.rawValue)")
    }

    private var chipForeground: Color {
        switch summary.readiness {
        case .available:
            return .green
        case .needsPermission, .needsSetup, .scaffolded:
            return .orange
        case .unavailable:
            return .red
        }
    }
}

private enum PermissionHubPage: Equatable {
    case phoneActions
    case managedTools

    var title: String {
        switch self {
        case .phoneActions:
            return KairoL10n.string("access.capabilities.section")
        case .managedTools:
            return KairoL10n.string("access.skills.advanced.toggle.title")
        }
    }
}

private struct AccessIntegrationChipView: View {
    let summary: KairoAccessIntegrationSummary

    var body: some View {
        Text(summary.readiness.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(chipForeground)
            .background(chipForeground.opacity(0.15), in: Capsule())
            .accessibilityLabel(summary.appName)
            .accessibilityValue(summary.readiness.displayName)
            .accessibilityIdentifier("access.integration.\(summary.skillID.rawValue)")
    }

    private var chipForeground: Color {
        switch summary.readiness {
        case .available:
            return .green
        case .needsPermission, .needsInstalledApp, .needsUserShortcut, .needsOAuth, .previewOnly:
            return .orange
        case .unsupported, .disabled:
            return .red
        }
    }
}
#endif
