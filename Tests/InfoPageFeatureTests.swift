import XCTest
@testable import KairoCore

final class InfoPageFeatureTests: XCTestCase {
    func testInfoPageCodableAndFileBackedStoreSearchActivePages() async throws {
        let fileURL = temporaryBackendTestFileURL(named: "info-pages.json")
        let page = InfoPage(
            title: "Hong Kong Travel",
            category: .travel,
            templateID: .travel,
            summary: "Airport pickup and return trip checklist.",
            facts: [
                InfoPageFact(label: "destination", value: "Hong Kong")
            ],
            timeline: [
                InfoPageTimelineItem(title: "Airport pickup", note: "10:30")
            ],
            assetIDs: [UUID()]
        )
        let store = try await JSONFileInfoPageStore(fileURL: fileURL)

        try await store.save(page)
        let reloaded = try await JSONFileInfoPageStore(fileURL: fileURL)
        let results = try await reloaded.search(query: "pickup Hong Kong", limit: 10)

        XCTAssertEqual(results.map(\.id), [page.id])
        XCTAssertEqual(results.first?.templateID, .travel)
        XCTAssertEqual(results.first?.facts.first?.label, "destination")
    }

    func testInfoPageStoreSoftDeleteExcludesPageFromListAndExport() async throws {
        let deleted = InfoPage(title: "Deleted", category: .generalNote, templateID: .generalNote)
        let active = InfoPage(title: "Active", category: .project, templateID: .project)
        let store = InMemoryInfoPageStore(seed: [deleted, active])

        try await store.delete(id: deleted.id)
        let listed = try await store.list(limit: 10)
        let exported = try await store.export(limit: 10)

        XCTAssertEqual(listed.map(\.id), [active.id])
        XCTAssertEqual(exported.pages.map(\.id), [active.id])
    }

    func testTemplateCatalogCoversAllDeclaredTemplatesWithSchemaAndRendererNames() throws {
        let definitions = InfoPageTemplateCatalog.all

        XCTAssertEqual(Set(definitions.map(\.id)), Set(InfoPageTemplateID.allCases))
        XCTAssertTrue(definitions.allSatisfy { !$0.htmlTemplateName.isEmpty })
        XCTAssertTrue(definitions.allSatisfy { !$0.requiredFactKeys.isEmpty })
        XCTAssertTrue(definitions.allSatisfy { !$0.suggestedReminderKeys.isEmpty })
    }

    func testTravelInfoPageGenerationLinksAssetsAndRequiresReminderConfirmation() throws {
        let asset = KnowledgeAsset(
            title: "airport-transfer.png",
            kind: .screenshot,
            source: .shareExtension,
            attachments: [],
            extractedText: "香港 機場接送 去程 已預訂 接機時間 10:30",
            summary: "Airport pickup booking",
            tags: ["travel", "airport"]
        )

        let page = InfoPageGenerator.generate(from: InfoPageGenerationInput(
            assets: [asset],
            now: Date(timeIntervalSince1970: 1_717_392_000)
        ))

        XCTAssertEqual(page.templateID, .travel)
        XCTAssertEqual(page.category, .travel)
        XCTAssertEqual(page.assetIDs, [asset.id])
        XCTAssertTrue(page.facts.contains { $0.label == "destination" && $0.value == "Hong Kong" })
        XCTAssertTrue(page.facts.contains { $0.label == "returnTrip" && $0.value == "Needs confirmation" })
        XCTAssertTrue(page.timeline.contains { $0.title == "Airport pickup" })
        XCTAssertEqual(page.reminderLinks.first?.deepLink.absoluteString, "kairo://info-page/\(page.id.uuidString)")
        XCTAssertTrue(page.actionDrafts.allSatisfy(\.requiresConfirmation))
        XCTAssertTrue(page.actionDrafts.contains { $0.kind == .createReminderDraft })
    }

    func testReminderLinkDraftFallsBackToDeepLinkInNotes() throws {
        let pageID = UUID()
        let link = ReminderLink.draft(infoPageID: pageID, title: "Confirm return trip")

        XCTAssertEqual(link.status, .draft)
        XCTAssertEqual(link.deepLink.absoluteString, "kairo://info-page/\(pageID.uuidString)")
        XCTAssertTrue(link.notesFallback.contains(link.deepLink.absoluteString))
    }

    func testModelEvaluationCatalogDefinesMinimumAndPreferredInfoPageCandidates() throws {
        let minimum = InfoPageModelEvaluationCatalog.minimumPrimaryCandidate
        let preferred = InfoPageModelEvaluationCatalog.preferredCandidate

        XCTAssertEqual(minimum.id, "gemma-4-e2b-it")
        XCTAssertEqual(minimum.recommendedRole, .minimumVisionExtraction)
        XCTAssertTrue(minimum.requiresVisionInput)
        XCTAssertTrue(minimum.expectedTemplateCoverage.contains(.travel))
        XCTAssertNil(minimum.downloadableModelID)

        XCTAssertEqual(preferred.id, "gemma-4-e4b-it")
        XCTAssertEqual(preferred.recommendedRole, .preferredOnDeviceExtraction)
        XCTAssertEqual(Set(preferred.expectedTemplateCoverage), Set(InfoPageTemplateID.allCases))
        XCTAssertGreaterThan(preferred.minimumAcceptedScore, minimum.minimumAcceptedScore)

        let fallback = try XCTUnwrap(InfoPageModelEvaluationCatalog.candidates.first { $0.id == LocalModelManifest.qwen35Tiny.id })
        XCTAssertEqual(fallback.recommendedRole, .fallbackTextExtraction)
        XCTAssertFalse(fallback.requiresVisionInput)
        XCTAssertEqual(fallback.downloadableModelID, LocalModelManifest.qwen35Tiny.id)

        let qwenVision = try XCTUnwrap(InfoPageModelEvaluationCatalog.candidates.first { $0.id == LocalModelManifest.qwen25VLThreeBInstruct.id })
        XCTAssertEqual(qwenVision.recommendedRole, .minimumVisionExtraction)
        XCTAssertTrue(qwenVision.requiresVisionInput)
        XCTAssertEqual(qwenVision.downloadableModelID, LocalModelManifest.qwen25VLThreeBInstruct.id)

        let qwenTwoB = try XCTUnwrap(InfoPageModelEvaluationCatalog.candidates.first { $0.id == LocalModelManifest.qwen35TwoB.id })
        XCTAssertEqual(qwenTwoB.recommendedRole, .fallbackTextExtraction)
        XCTAssertFalse(qwenTwoB.requiresVisionInput)
        XCTAssertEqual(qwenTwoB.downloadableModelID, LocalModelManifest.qwen35TwoB.id)
    }
}
