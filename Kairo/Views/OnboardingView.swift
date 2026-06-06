#if canImport(SwiftUI)
import SwiftUI

struct OnboardingView: View {
    let assetAPI: any KairoKnowledgeAssetAPI
    let openModelSettings: () -> Void
    let finish: () -> Void

    @State private var step: OnboardingStep = .intro
    @State private var selectedCategoryIDs = Set(KairoOnboarding.defaultCategories.prefix(8).map(\.id))
    @State private var showRequiredSetupNotice = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 58)
            .padding(.bottom, 22)
        }
        .preferredColorScheme(KairoAppearancePreference.current.colorScheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.screen")
    }

    private var onboardingBackground: some View {
        ZStack {
            KairoDesign.background.ignoresSafeArea()
            Circle()
                .fill(KairoDesign.teal.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 58)
                .offset(x: -120, y: -230)
            Circle()
                .fill(KairoDesign.blue.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 72)
                .offset(x: 145, y: 210)
            LinearGradient(
                colors: [
                    KairoDesign.elevatedSurface.opacity(0.18),
                    KairoDesign.background.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            introStep
        case .categories:
            categoriesStep
        case .model:
            modelStep
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .fill(KairoDesign.elevatedSurface.opacity(0.64))
                    .frame(height: 252)
                    .overlay {
                        RoundedRectangle(cornerRadius: 42, style: .continuous)
                            .stroke(KairoDesign.line.opacity(0.72), lineWidth: 1)
                    }
                    .shadow(color: KairoDesign.shadow.opacity(0.24), radius: 30, x: 0, y: 20)

                assetConstellation
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(KairoL10n.string("onboarding.hero.title"))
            .accessibilityIdentifier("onboarding.hero")

            VStack(alignment: .leading, spacing: 10) {
                Text(KairoL10n.string("onboarding.hero.title"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(KairoDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(KairoL10n.string("onboarding.hero.subtitle"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(KairoDesign.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                onboardingFeatureRow(icon: "photo.stack.fill", titleKey: "onboarding.feature.capture")
                onboardingFeatureRow(icon: "text.viewfinder", titleKey: "onboarding.feature.understand")
                onboardingFeatureRow(icon: "magnifyingglass.circle.fill", titleKey: "onboarding.feature.retrieve")
            }

            Spacer(minLength: 0)
        }
    }

    private var assetConstellation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(KairoDesign.softSurface.opacity(0.42))
                .frame(width: 172, height: 104)
                .rotationEffect(.degrees(-8))
                .offset(x: -36, y: -6)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(KairoDesign.elevatedSurface.opacity(0.68))
                .frame(width: 126, height: 86)
                .rotationEffect(.degrees(10))
                .offset(x: 58, y: 34)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 112, height: 112)
                .background(KairoDesign.elevatedSurface.opacity(0.82), in: Circle())
                .overlay {
                    Circle()
                        .stroke(KairoDesign.line.opacity(0.8), lineWidth: 1)
                }

            onboardingOrbitIcon("calendar.badge.clock", x: -105, y: -78, tint: KairoDesign.amber)
            onboardingOrbitIcon("folder.fill", x: 116, y: -64, tint: KairoDesign.blue)
            onboardingOrbitIcon("doc.text.image.fill", x: -116, y: 82, tint: KairoDesign.violet)
            onboardingOrbitIcon("checklist", x: 102, y: 76, tint: KairoDesign.green)
        }
    }

    private func onboardingOrbitIcon(_ systemName: String, x: CGFloat, y: CGFloat, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.headline.weight(.bold))
            .foregroundStyle(tint)
            .frame(width: 48, height: 48)
            .background(KairoDesign.elevatedSurface.opacity(0.72), in: Circle())
            .overlay {
                Circle()
                    .stroke(KairoDesign.line.opacity(0.72), lineWidth: 1)
            }
            .offset(x: x, y: y)
    }

    private func onboardingFeatureRow(icon: String, titleKey: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 34, height: 34)
                .background(KairoDesign.elevatedSurface.opacity(0.62), in: Circle())
            Text(KairoL10n.string(titleKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
        }
    }

    private var categoriesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader(titleKey: "onboarding.categories.title", subtitleKey: "onboarding.categories.subtitle")

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 144), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(KairoOnboarding.defaultCategories) { category in
                        categoryButton(category)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("onboarding.categories")
        }
    }

    private func categoryButton(_ category: KairoOnboardingCategory) -> some View {
        let isSelected = selectedCategoryIDs.contains(category.id)

        return Button {
            toggleCategory(category.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.bold))
                Text(KairoL10n.string(category.titleKey))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? KairoDesign.blue : KairoDesign.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(KairoDesign.elevatedSurface.opacity(isSelected ? 0.80 : 0.46), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? KairoDesign.blue.opacity(0.32) : KairoDesign.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.category.\(category.id)")
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(titleKey: "onboarding.model.title", subtitleKey: "onboarding.model.subtitle")

            VStack(spacing: 12) {
                modelOption(icon: "person.crop.circle.badge.checkmark", titleKey: "onboarding.model.chatgpt", detailKey: "onboarding.model.chatgpt.detail")
                modelOption(icon: "arrow.down.circle.fill", titleKey: "onboarding.model.local", detailKey: "onboarding.model.local.detail")
            }
            .accessibilityIdentifier("onboarding.model-card")

            HStack(spacing: 10) {
                Button {
                    openModelSettings()
                } label: {
                    Label(KairoL10n.string("onboarding.model.open"), systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true, isCompact: true))
                .accessibilityIdentifier("onboarding.model.open")

                Button {
                    showRequiredSetupNotice = true
                } label: {
                    Text(KairoL10n.string("onboarding.model.later"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.amber, isCompact: true))
                .accessibilityIdentifier("onboarding.model.later")
            }

            if showRequiredSetupNotice {
                Label(KairoL10n.string("onboarding.model.requiredNotice"), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(KairoDesign.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .background(KairoDesign.elevatedSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityIdentifier("onboarding.model.required-notice")
            }

            Spacer(minLength: 0)
        }
    }

    private func modelOption(icon: String, titleKey: String, detailKey: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 44, height: 44)
                .background(KairoDesign.elevatedSurface.opacity(0.66), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(KairoL10n.string(titleKey))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(KairoL10n.string(detailKey))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(KairoDesign.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(KairoDesign.elevatedSurface.opacity(0.52), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KairoDesign.line.opacity(0.74), lineWidth: 1)
        }
    }

    private func stepHeader(titleKey: String, subtitleKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("onboarding.step.label", step.index, OnboardingStep.allCases.count))
                .font(.caption.weight(.bold))
                .foregroundStyle(KairoDesign.teal)
                .textCase(.uppercase)
            Text(KairoL10n.string(titleKey))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(KairoDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(KairoL10n.string(subtitleKey))
                .font(.body.weight(.medium))
                .foregroundStyle(KairoDesign.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(KairoDesign.red)
                    .accessibilityIdentifier("onboarding.error")
            }

            HStack(spacing: 10) {
                if step != .intro {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            step = step.previous
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 46, height: 46)
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
                    .accessibilityIdentifier("onboarding.back")
                }

                Button {
                    handlePrimaryAction()
                } label: {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: primaryButtonTint, isProminent: true))
                .disabled(isSaving)
                .accessibilityIdentifier(step == .model ? "onboarding.finish" : "onboarding.next")
            }
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .intro, .categories:
            return KairoL10n.string("onboarding.next")
        case .model:
            return isSaving ? KairoL10n.string("onboarding.finish.saving") : KairoL10n.string("onboarding.finish")
        }
    }

    private var primaryButtonIcon: String {
        switch step {
        case .intro, .categories:
            return "arrow.right.circle.fill"
        case .model:
            return "checkmark.circle.fill"
        }
    }

    private var primaryButtonTint: Color {
        switch step {
        case .intro:
            return KairoDesign.teal
        case .categories:
            return KairoDesign.blue
        case .model:
            return KairoDesign.teal
        }
    }

    private func handlePrimaryAction() {
        switch step {
        case .intro, .categories:
            withAnimation(.snappy(duration: 0.22)) {
                step = step.next
            }
        case .model:
            Task { await completeOnboarding() }
        }
    }

    private func toggleCategory(_ id: String) {
        if selectedCategoryIDs.contains(id) {
            selectedCategoryIDs.remove(id)
        } else {
            selectedCategoryIDs.insert(id)
        }
    }

    private func completeOnboarding() async {
        isSaving = true
        do {
            for folder in KairoOnboarding.folders(for: selectedCategoryIDs) {
                try await assetAPI.saveFolder(folder)
            }
            await MainActor.run {
                isSaving = false
                finish()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case intro
    case categories
    case model

    var index: Int { rawValue + 1 }

    var next: OnboardingStep {
        switch self {
        case .intro:
            return .categories
        case .categories:
            return .model
        case .model:
            return .model
        }
    }

    var previous: OnboardingStep {
        switch self {
        case .intro:
            return .intro
        case .categories:
            return .intro
        case .model:
            return .categories
        }
    }
}
#endif
