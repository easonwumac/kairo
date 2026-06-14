import XCTest
@testable import KairoCore

final class InfoPageFeatureTests: XCTestCase {
    actor StubAssetUnderstandingModel: AssetUnderstandingModel {
        private var replies: [String]
        private(set) var prompts: [String] = []

        init(replies: [String]) {
            self.replies = replies
        }

        func complete(prompt: String) async throws -> String {
            prompts.append(prompt)
            guard !replies.isEmpty else { return "{}" }
            return replies.removeFirst()
        }
    }

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

    func testInfoPageSearchMatchesSmallTypos() async throws {
        let page = InfoPage(
            title: "Airport pickup plan",
            category: .travel,
            templateID: .travel,
            summary: "Hong Kong arrival details"
        )
        let store = InMemoryInfoPageStore(seed: [page])

        let results = try await store.search(query: "airprt", limit: 10)

        XCTAssertEqual(results.map(\.id), [page.id])
    }

    func testInfoPageSearchRanksExactMatchesBeforeFuzzyMatches() async throws {
        let fuzzy = InfoPage(
            title: "Airprt pickup plan",
            category: .travel,
            templateID: .travel,
            summary: "Hong Kong arrival details",
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let exact = InfoPage(
            title: "Airport transfer",
            category: .travel,
            templateID: .travel,
            summary: "Airport handoff checklist",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let store = InMemoryInfoPageStore(seed: [fuzzy, exact])

        let results = try await store.search(query: "airport", limit: 10)

        XCTAssertEqual(results.map(\.id), [exact.id, fuzzy.id])
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

        XCTAssertEqual(minimum.id, LocalModelManifest.gemma4E2BQATQ4_0.id)
        XCTAssertEqual(minimum.recommendedRole, .minimumVisionExtraction)
        XCTAssertTrue(minimum.requiresVisionInput)
        XCTAssertTrue(minimum.expectedTemplateCoverage.contains(.travel))
        XCTAssertEqual(minimum.downloadableModelID, LocalModelManifest.gemma4E2BQATQ4_0.id)

        XCTAssertEqual(preferred.id, LocalModelManifest.gemma4E4BQATQ4_0.id)
        XCTAssertEqual(preferred.recommendedRole, .preferredOnDeviceExtraction)
        XCTAssertEqual(Set(preferred.expectedTemplateCoverage), Set(InfoPageTemplateID.allCases))
        XCTAssertGreaterThan(preferred.minimumAcceptedScore, minimum.minimumAcceptedScore)
        XCTAssertEqual(preferred.downloadableModelID, LocalModelManifest.gemma4E4BQATQ4_0.id)

        let fallback = try XCTUnwrap(InfoPageModelEvaluationCatalog.candidates.first { $0.id == LocalModelManifest.qwen25HalfBInstruct.id })
        XCTAssertEqual(fallback.recommendedRole, .fallbackTextExtraction)
        XCTAssertFalse(fallback.requiresVisionInput)
        XCTAssertEqual(fallback.downloadableModelID, LocalModelManifest.qwen25HalfBInstruct.id)

        let qwenVision = try XCTUnwrap(InfoPageModelEvaluationCatalog.candidates.first { $0.id == LocalModelManifest.qwen25VLThreeBInstruct.id })
        XCTAssertEqual(qwenVision.recommendedRole, .minimumVisionExtraction)
        XCTAssertTrue(qwenVision.requiresVisionInput)
        XCTAssertEqual(qwenVision.downloadableModelID, LocalModelManifest.qwen25VLThreeBInstruct.id)

        let qwenTwoB = try XCTUnwrap(InfoPageModelEvaluationCatalog.candidates.first { $0.id == LocalModelManifest.qwen25OneAndHalfBInstruct.id })
        XCTAssertEqual(qwenTwoB.recommendedRole, .fallbackTextExtraction)
        XCTAssertFalse(qwenTwoB.requiresVisionInput)
        XCTAssertEqual(qwenTwoB.downloadableModelID, LocalModelManifest.qwen25OneAndHalfBInstruct.id)
    }

    func testAssetUnderstandingPipelineRetriesInvalidJSONAndValidatesStructuredDraft() async throws {
        let folder = KnowledgeAssetFolder(name: "Hong Kong Travel")
        let asset = KnowledgeAsset(
            title: "airport-pickup.png",
            kind: .screenshot,
            source: .shareExtension,
            attachments: [],
            extractedText: "香港機場接送已預訂，去程接機 10:30，尚未看到回程安排。",
            generatedDescription: "Apple Vision OCR found airport pickup details.",
            summary: "Hong Kong pickup booking",
            tags: ["travel"]
        )
        let validJSON = """
        {
          "createInfoPage": true,
          "title": "Hong Kong Travel",
          "templateID": "travel",
          "category": "travel",
          "summary": "Hong Kong airport pickup is booked, but return trip details are missing.",
          "facts": [
            {"label": "destination", "value": "Hong Kong", "sourceAssetID": "\(asset.id.uuidString)"},
            {"label": "bookingStatus", "value": "Outbound pickup booked", "sourceAssetID": "\(asset.id.uuidString)"}
          ],
          "timeline": [
            {"title": "Airport pickup", "note": "Pickup at 10:30", "sourceAssetID": "\(asset.id.uuidString)"}
          ],
          "reminderDrafts": [
            {"title": "Confirm Hong Kong return trip", "dueDateText": "before departure", "needsUserConfirmation": true}
          ],
          "folderName": "Hong Kong Travel",
          "confidence": 0.91,
          "missingInfo": ["return trip"],
          "sourceAssetIDs": ["\(asset.id.uuidString)"]
        }
        """
        let model = StubAssetUnderstandingModel(replies: ["not json", validJSON])
        let pipeline = AssetUnderstandingPipeline(model: model)

        let result = await pipeline.understand(AssetUnderstandingRequest(
            assets: [asset],
            folders: [folder],
            minimumConfidence: 0.72,
            maximumAttempts: 2
        ))
        let prompts = await model.prompts
        let page = result.draft.makeInfoPage()

        XCTAssertEqual(result.status, .validated)
        XCTAssertEqual(result.attempts, 2)
        XCTAssertTrue(result.shouldAutoCreateInfoPage)
        XCTAssertTrue(prompts[0].contains("Output one JSON object only"))
        XCTAssertTrue(prompts[1].contains("Output must be one valid JSON object."))
        XCTAssertEqual(result.draft.templateID, .travel)
        XCTAssertEqual(result.draft.folderName, "Hong Kong Travel")
        XCTAssertEqual(result.draft.facts.map(\.label), ["destination", "bookingStatus"])
        XCTAssertEqual(page.assetIDs, [asset.id])
        XCTAssertTrue(page.actionDrafts.allSatisfy(\.requiresConfirmation))
    }

    func testAssetUnderstandingPromptBuilderUsesStagedSchemaPipelineForSmallModels() {
        let asset = KnowledgeAsset(
            title: "afm-url.txt",
            kind: .url,
            source: .shareExtension,
            attachments: [],
            extractedText: "pageTitle: AFM prompt stability\npageText: Small models perform better with staged schema prompts.",
            summary: "AFM prompt notes"
        )

        let prompt = AssetUnderstandingPromptBuilder.initialPrompt(for: AssetUnderstandingRequest(
            assets: [asset],
            folders: [KnowledgeAssetFolder(name: "Research")],
            minimumConfidence: 0.72,
            maximumAttempts: 2
        ))

        XCTAssertTrue(prompt.contains("classifyAsset"))
        XCTAssertTrue(prompt.contains("extractFacts"))
        XCTAssertTrue(prompt.contains("composeInfoPageJSON"))
        XCTAssertTrue(prompt.contains("Output one JSON object only"))
        XCTAssertTrue(prompt.contains("needsUserConfirmation=true"))
        XCTAssertTrue(prompt.contains("pageText exists"))
        XCTAssertTrue(prompt.contains(asset.id.uuidString))
        XCTAssertTrue(prompt.contains("Research"))
    }

    func testAssetUnderstandingPipelineCanRunThreeStageModelCallsBeforeValidation() async throws {
        let asset = KnowledgeAsset(
            title: "afm-url.txt",
            kind: .url,
            source: .shareExtension,
            attachments: [],
            extractedText: "pageTitle: AFM prompt stability\npageText: Small models perform better with staged schema prompts.",
            summary: "AFM prompt notes",
            tags: ["afm", "prompt"]
        )
        let classificationJSON = """
        {"bestTemplateID":"generalNote","bestCategory":"generalNote","confidence":0.84,"candidateCategories":[],"missingInfo":[]}
        """
        let factsJSON = """
        {"assetDescription":"URL notes about AFM prompt stability.","ocrSummary":"Small models perform better with staged schema prompts.","keywords":["afm","prompt","schema"],"facts":[{"label":"topic","value":"AFM prompt stability","sourceAssetID":"\(asset.id.uuidString)"}],"timeline":[],"reminderDrafts":[],"missingInfo":[]}
        """
        let finalJSON = """
        {
          "createInfoPage": true,
          "title": "AFM Prompt Stability",
          "templateID": "generalNote",
          "category": "generalNote",
          "assetDescription": "URL notes about AFM prompt stability.",
          "ocrSummary": "Small models perform better with staged schema prompts.",
          "keywords": ["afm", "prompt", "schema"],
          "summary": "AFM prompt stability improves when asset understanding is split into staged schema tasks.",
          "facts": [
            {"label": "topic", "value": "AFM prompt stability", "sourceAssetID": "\(asset.id.uuidString)"}
          ],
          "timeline": [],
          "reminderDrafts": [],
          "folderName": null,
          "confidence": 0.84,
          "missingInfo": [],
          "sourceAssetIDs": ["\(asset.id.uuidString)"]
        }
        """
        let model = StubAssetUnderstandingModel(replies: [classificationJSON, factsJSON, finalJSON])
        let pipeline = AssetUnderstandingPipeline(model: model)

        let result = await pipeline.understand(AssetUnderstandingRequest(
            assets: [asset],
            maximumAttempts: 1,
            executionMode: .staged
        ))
        let prompts = await model.prompts

        XCTAssertEqual(result.status, .validated)
        XCTAssertTrue(result.shouldAutoCreateInfoPage)
        XCTAssertEqual(result.attempts, 1)
        XCTAssertEqual(prompts.count, 3)
        XCTAssertTrue(prompts[0].contains("Stage classifyAsset"))
        XCTAssertTrue(prompts[1].contains("Stage extractFacts"))
        XCTAssertTrue(prompts[1].contains(classificationJSON))
        XCTAssertTrue(prompts[2].contains("Stage composeInfoPageJSON"))
        XCTAssertTrue(prompts[2].contains(factsJSON))
    }

    func testAssetUnderstandingRepairPromptPreservesStagedPipelineAndValidationErrors() {
        let asset = KnowledgeAsset(
            title: "broken.txt",
            kind: .text,
            source: .chat,
            attachments: [],
            extractedText: "Remember to confirm the receipt.",
            summary: "Receipt note"
        )

        let prompt = AssetUnderstandingPromptBuilder.repairPrompt(
            for: AssetUnderstandingRequest(assets: [asset], maximumAttempts: 2),
            issues: [.invalidJSON, .reminderWithoutConfirmation("Confirm receipt")]
        )

        XCTAssertTrue(prompt.contains("Re-run only the failing staged pipeline work"))
        XCTAssertTrue(prompt.contains("Output must be one valid JSON object."))
        XCTAssertTrue(prompt.contains("reminderDraft Confirm receipt must set needsUserConfirmation=true."))
        XCTAssertTrue(prompt.contains("classifyAsset"))
        XCTAssertTrue(prompt.contains("composeInfoPageJSON"))
    }

    func testAssetUnderstandingPipelineRequiresUserChoiceForMultipleCategoryCandidates() async throws {
        let asset = KnowledgeAsset(
            title: "flower-photo.jpg",
            kind: .image,
            source: .chat,
            attachments: [],
            extractedText: "",
            generatedDescription: "Apple Vision labels: flower, plant, outdoor",
            summary: "Flower photo",
            tags: ["image"]
        )
        let json = """
        {
          "createInfoPage": true,
          "title": "Flower Reference",
          "templateID": "generalNote",
          "category": "generalNote",
          "assetDescription": "A flower photo with plant-related visual labels.",
          "ocrSummary": "",
          "keywords": ["flower", "plant", "photo"],
          "candidateCategories": [
            {"folderName": "Learning", "templateID": "generalNote", "category": "generalNote", "confidence": 0.62, "reason": "Could be a plant reference."},
            {"folderName": "Ideas", "templateID": "generalNote", "category": "generalNote", "confidence": 0.58, "reason": "Could be saved as visual inspiration."}
          ],
          "summary": "A flower image that may be useful as a plant reference or visual inspiration.",
          "facts": [
            {"label": "topic", "value": "Flower photo", "sourceAssetID": "\(asset.id.uuidString)"}
          ],
          "timeline": [],
          "reminderDrafts": [],
          "folderName": "Learning",
          "confidence": 0.74,
          "missingInfo": [],
          "sourceAssetIDs": ["\(asset.id.uuidString)"]
        }
        """
        let model = StubAssetUnderstandingModel(replies: [json])
        let pipeline = AssetUnderstandingPipeline(model: model)

        let result = await pipeline.understand(AssetUnderstandingRequest(
            assets: [asset],
            folders: [
                KnowledgeAssetFolder(name: "Learning"),
                KnowledgeAssetFolder(name: "Ideas")
            ],
            minimumConfidence: 0.72,
            maximumAttempts: 1
        ))

        XCTAssertEqual(result.status, .validated)
        XCTAssertTrue(result.requiresCategoryChoice)
        XCTAssertFalse(result.shouldAutoCreateInfoPage)
        XCTAssertEqual(result.draft.assetDescription, "A flower photo with plant-related visual labels.")
        XCTAssertEqual(result.draft.keywords ?? [], ["flower", "plant", "photo"])
        XCTAssertEqual(result.draft.candidateCategories?.map(\.folderName), ["Learning", "Ideas"])
    }

    func testAssetUnderstandingPipelineFallsBackWhenDraftCannotPassSafetyValidation() async throws {
        let asset = KnowledgeAsset(
            title: "unknown-note.txt",
            kind: .text,
            source: .chat,
            attachments: [],
            extractedText: "Remember to check the trip later.",
            summary: "Trip note"
        )
        let unsafeJSON = """
        {
          "createInfoPage": true,
          "title": "Trip",
          "templateID": "travel",
          "category": "travel",
          "summary": "<html>Trip page</html>",
          "facts": [
            {"label": "destination", "value": "Unknown", "sourceAssetID": "\(asset.id.uuidString)"}
          ],
          "timeline": [],
          "reminderDrafts": [
            {"title": "Book return trip", "needsUserConfirmation": false}
          ],
          "folderName": "Not Existing",
          "confidence": 0.41,
          "missingInfo": [],
          "sourceAssetIDs": ["\(asset.id.uuidString)"]
        }
        """
        let model = StubAssetUnderstandingModel(replies: [unsafeJSON])
        let pipeline = AssetUnderstandingPipeline(model: model)

        let result = await pipeline.understand(AssetUnderstandingRequest(
            assets: [asset],
            folders: [KnowledgeAssetFolder(name: "Travel")],
            minimumConfidence: 0.72,
            maximumAttempts: 1
        ))

        XCTAssertEqual(result.status, .needsReview)
        XCTAssertFalse(result.shouldAutoCreateInfoPage)
        XCTAssertEqual(result.draft.createInfoPage, false)
        XCTAssertTrue(result.validationIssues.contains(.confidenceTooLow(0.41)))
        XCTAssertTrue(result.validationIssues.contains(.unknownFolder("Not Existing")))
        XCTAssertTrue(result.validationIssues.contains(.missingRequiredFact("bookingStatus")))
        XCTAssertTrue(result.validationIssues.contains(.unsafeGeneratedMarkup))
        XCTAssertTrue(result.validationIssues.contains(.reminderWithoutConfirmation("Book return trip")))
    }
}
