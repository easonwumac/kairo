#if canImport(SwiftUI)
import SwiftUI

struct OnboardingView: View {
    let assetAPI: any KairoKnowledgeAssetAPI
    let openModelSettings: () -> Void
    let finish: () -> Void

    @State private var selectedCategoryIDs = Set(KairoOnboarding.defaultCategories.prefix(8).map(\.id))
    @State private var showRequiredSetupNotice = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            KairoDesign.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    setupCard
                    categoriesCard
                    finishRow
                }
                .padding(.horizontal, 18)
                .padding(.top, 42)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(KairoAppearancePreference.current.colorScheme)
        .accessibilityIdentifier("onboarding.screen")
    }

    private var hero: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(KairoDesign.softSurface.opacity(0.72))
                        .frame(height: 116)
                    HStack(spacing: 14) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(KairoDesign.teal)
                            .frame(width: 58, height: 58)
                            .background(KairoDesign.elevatedSurface.opacity(0.75), in: Circle())
                        VStack(alignment: .leading, spacing: 8) {
                            onboardingMiniCard(icon: "text.viewfinder")
                            onboardingMiniCard(icon: "folder.fill")
                            onboardingMiniCard(icon: "magnifyingglass")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(KairoL10n.string("onboarding.hero.title"))
                        .font(.title.weight(.bold))
                        .foregroundStyle(KairoDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(KairoL10n.string("onboarding.hero.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("onboarding.hero")
    }

    private func onboardingMiniCard(icon: String) -> some View {
        Image(systemName: icon)
            .font(.headline.weight(.semibold))
            .foregroundStyle(KairoDesign.ink)
            .frame(width: 42, height: 28)
            .background(KairoDesign.elevatedSurface.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var setupCard: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 10) {
                Label(KairoL10n.string("onboarding.model.title"), systemImage: "cpu")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.amber)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("onboarding.model.required-notice")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.model-card")
    }

    private var categoriesCard: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 12) {
                Label(KairoL10n.string("onboarding.categories.title"), systemImage: "folder.badge.plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(KairoL10n.string("onboarding.categories.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(KairoOnboarding.defaultCategories) { category in
                        let title = KairoL10n.string(category.titleKey)
                        Button {
                            toggleCategory(category.id)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: selectedCategoryIDs.contains(category.id) ? "checkmark.circle.fill" : "circle")
                                Text(title)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedCategoryIDs.contains(category.id) ? KairoDesign.blue : KairoDesign.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(KairoDesign.softSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.category.\(category.id)")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.categories")
    }

    private var finishRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(KairoDesign.red)
                    .accessibilityIdentifier("onboarding.error")
            }
            Button {
                Task { await completeOnboarding() }
            } label: {
                Label(isSaving ? KairoL10n.string("onboarding.finish.saving") : KairoL10n.string("onboarding.finish"), systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.teal, isProminent: true))
            .disabled(isSaving)
            .accessibilityIdentifier("onboarding.finish")
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
#endif
