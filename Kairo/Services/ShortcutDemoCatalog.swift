import Foundation

public struct ShortcutDemoCatalog: Codable, Equatable, Sendable {
    public var recipes: [ShortcutDemoRecipe]

    public init(recipes: [ShortcutDemoRecipe]) {
        self.recipes = recipes
    }

    public func recipe(id: String) -> ShortcutDemoRecipe? {
        recipes.first { $0.id == id }
    }

    public static let `default` = ShortcutDemoCatalog(recipes: [
        ShortcutDemoRecipe(
            id: "daily-briefing",
            title: "Daily Briefing",
            summary: "Turn a morning Shortcut into a compact briefing with suggested actions.",
            triggerSummary: "Time automation at 8:30 AM or a manual Shortcut button.",
            setupNotes: [
                "Pass calendar notes, reminders, or typed agenda text into Kairo.",
                "Show the returned briefing text and optionally send a notification."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Create Daily Briefing with Kairo",
                    nodeKind: .dailyBriefing,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Morning agenda, reminders, or notes selected by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["displayText", "fields.briefing", "fields.taskCount"],
                        optionalFields: ["tasks"],
                        description: "Briefing text plus suggested task drafts for downstream Shortcut actions."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Today's agenda:
                        Action: Review HomeKit automation proposal
                        Reminder: Send Shortcut demo to beta tester
                        """,
                        sourceName: "Morning Shortcut",
                        variables: ["shortcutRecipeID": "daily-briefing"]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "save-shared-text",
            title: "Save Shared Text",
            summary: "Capture text from Share Sheet, save it as Kairo memory, then extract follow-up tasks.",
            triggerSummary: "Share Sheet or Shortcut Input from Notes, Safari, Files, or any app that shares text.",
            setupNotes: [
                "Use Shortcut Input as the text passed to Save to Kairo Memory.",
                "Pass the same text to Extract Kairo Tasks before showing confirmation."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Save to Kairo Memory",
                    nodeKind: .saveMemory,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Shared text or URL content explicitly selected by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["memoryID", "fields.taskCount"],
                        optionalFields: ["tasks"],
                        description: "Saved memory identifier plus extracted task drafts."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        User research note: testers want a visible model selector.
                        TODO: Add screenshot to GitHub README
                        """,
                        sourceName: "Share Sheet",
                        variables: ["shortcutRecipeID": "save-shared-text"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Extract Kairo Tasks",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "The same shared text, or the saved memory summary."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.taskCount"],
                        optionalFields: ["tasks", "reminderDrafts"],
                        description: "Task and reminder drafts only; no calendar or reminder write is executed."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "TODO: Add screenshot to GitHub README",
                        sourceName: "Share Sheet",
                        variables: ["shortcutRecipeID": "save-shared-text"]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "screenshot-to-reminders",
            title: "Screenshot to Reminders",
            summary: "Extract text from a screenshot, turn action lines into reminder drafts, and let the user confirm writes.",
            triggerSummary: "Manual Shortcut from a selected photo or screenshot.",
            setupNotes: [
                "Use Apple's Extract Text from Image action before Kairo.",
                "Use Kairo output as drafts, then confirm before creating real reminders."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Extract Kairo Tasks",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "OCR text from a user-selected screenshot."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.taskCount"],
                        optionalFields: ["tasks", "reminderDrafts"],
                        description: "Extracted task drafts for the next Shortcut step."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Screenshot OCR:
                        Action: File expense report
                        Reminder: Book client follow-up
                        """,
                        sourceName: "Screenshot OCR",
                        variables: ["shortcutRecipeID": "screenshot-to-reminders"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Create Reminder Drafts",
                    nodeKind: .createReminderDraft,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Task text from OCR or a previous Kairo extraction step."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.reminderDraftCount"],
                        optionalFields: ["reminderDrafts"],
                        description: "Reminder drafts that still require an explicit confirmation/write step."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Action: File expense report
                        Reminder: Book client follow-up
                        """,
                        sourceName: "Screenshot OCR",
                        variables: ["shortcutRecipeID": "screenshot-to-reminders"]
                    )
                )
            ]
        )
    ])
}

public struct ShortcutDemoRecipe: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var triggerSummary: String
    public var setupNotes: [String]
    public var steps: [ShortcutDemoStep]

    public init(
        id: String,
        title: String,
        summary: String,
        triggerSummary: String,
        setupNotes: [String],
        steps: [ShortcutDemoStep]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.triggerSummary = triggerSummary
        self.setupNotes = setupNotes
        self.steps = steps
    }

    public var settingsStepSummary: String {
        let countLabel = steps.count == 1 ? "1 step" : "\(steps.count) steps"
        let nodePath = steps.map { $0.nodeKind.rawValue }.joined(separator: " -> ")
        return "\(countLabel): \(nodePath)"
    }

    public var settingsContractSummary: String {
        "\(settingsInputSummary); \(settingsOutputSummary)"
    }

    public var settingsInputSummary: String {
        let fields = uniqueFields { $0.inputContract.fields }
        return "Input: \(fields.joined(separator: ", "))"
    }

    public var settingsOutputSummary: String {
        let fields = uniqueFields { $0.outputContract.fields }
        return "Output: \(fields.joined(separator: ", "))"
    }

    public var settingsSampleInputPreview: String {
        steps.first?.sampleInput.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func uniqueFields(_ fields: (ShortcutDemoStep) -> [String]) -> [String] {
        var seen: Set<String> = []
        var values: [String] = []
        for field in steps.flatMap(fields) where !seen.contains(field) {
            seen.insert(field)
            values.append(field)
        }
        return values
    }
}

public struct ShortcutDemoStep: Codable, Equatable, Sendable {
    public var shortcutActionTitle: String
    public var nodeKind: ShortcutNodeKind
    public var inputContract: ShortcutNodeContract
    public var outputContract: ShortcutNodeContract
    public var sampleInput: ShortcutNodeInput

    public init(
        shortcutActionTitle: String,
        nodeKind: ShortcutNodeKind,
        inputContract: ShortcutNodeContract,
        outputContract: ShortcutNodeContract,
        sampleInput: ShortcutNodeInput
    ) {
        self.shortcutActionTitle = shortcutActionTitle
        self.nodeKind = nodeKind
        self.inputContract = inputContract
        self.outputContract = outputContract
        self.sampleInput = sampleInput
    }
}

public struct ShortcutNodeContract: Codable, Equatable, Sendable {
    public var requiredFields: [String]
    public var optionalFields: [String]
    public var description: String

    public init(requiredFields: [String], optionalFields: [String] = [], description: String) {
        self.requiredFields = requiredFields
        self.optionalFields = optionalFields
        self.description = description
    }

    public var fields: [String] {
        requiredFields + optionalFields
    }
}
