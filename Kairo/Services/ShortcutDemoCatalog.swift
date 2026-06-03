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
                        requiredFields: ["fields.taskCount", "fields.chainText"],
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
                        requiredFields: ["fields.taskCount", "fields.chainText"],
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
                        requiredFields: ["fields.reminderDraftCount", "fields.chainText"],
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
        ),
        ShortcutDemoRecipe(
            id: "reply-draft-from-shared-text",
            title: "Reply Draft from Shared Text",
            summary: "Turn explicitly shared email or chat text into a draft reply without sending anything automatically.",
            triggerSummary: "Share Sheet from Mail, Messages-compatible exports, Safari, or any app that shares text.",
            setupNotes: [
                "Pass shared text to Summarize with Kairo.",
                "Pass the previous Kairo output to Draft Reply and review the returned text before sending manually."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Summarize with Kairo",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Email, chat, or support request text explicitly selected by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["displayText", "fields.summary", "fields.chainText"],
                        description: "Concise context passed into the reply drafting node."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Customer email:
                        Can Kairo turn a screenshot into reminders and keep the Shortcut output structured?
                        """,
                        sourceName: "Shared Email",
                        variables: ["shortcutRecipeID": "reply-draft-from-shared-text"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Draft Reply with Kairo",
                    nodeKind: .draftReply,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Previous Kairo summary or explicit Shortcut input text."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.replyDraft"],
                        optionalFields: ["fields.replyDraftTone", "displayText"],
                        description: "Reply draft text only. The Shortcut must still ask the user before sending."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Shared Email",
                        variables: [
                            "shortcutRecipeID": "reply-draft-from-shared-text",
                            "kairoInputSource": "previousStepOutput",
                            "tone": "concise"
                        ]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "email-triage",
            title: "Email Triage",
            summary: "Summarize an email, extract follow-up tasks, and prepare a reply draft without sending.",
            triggerSummary: "Share Sheet from Mail, a copied email thread, or an Action Button Shortcut that passes selected text.",
            setupNotes: [
                "Pass the selected email text to Summarize with Kairo.",
                "Chain the output through Extract Kairo Tasks and Draft Reply.",
                "Show task and reply drafts for manual review; do not send or write reminders silently."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Summarize Email with Kairo",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Email thread text explicitly selected or shared by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["displayText", "fields.summary", "fields.chainText"],
                        description: "Compact email summary and original text for downstream Kairo nodes."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Email from vendor:
                        Please confirm the revised launch timeline by Friday.
                        Action: Send updated app screenshots
                        Reminder: Ask legal to review the OAuth wording
                        """,
                        sourceName: "Shared Email",
                        variables: ["shortcutRecipeID": "email-triage"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Extract Follow-up Tasks",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Email summary or original text passed from the previous Kairo node."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.taskCount", "fields.chainText"],
                        optionalFields: ["tasks", "reminderDrafts"],
                        description: "Follow-up task drafts plus chain text for reply drafting."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Shared Email",
                        variables: [
                            "shortcutRecipeID": "email-triage",
                            "kairoInputSource": "previousStepOutput"
                        ]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Draft Email Reply",
                    nodeKind: .draftReply,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Email text chained from the task extraction node."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.replyDraft"],
                        optionalFields: ["fields.replyDraftTone", "displayText"],
                        description: "Reply draft only. Shortcuts must still require visible user review before sending."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Shared Email",
                        variables: [
                            "shortcutRecipeID": "email-triage",
                            "kairoInputSource": "previousStepOutput",
                            "tone": "clear"
                        ]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "meeting-prep-brief",
            title: "Meeting Prep Brief",
            summary: "Search Kairo memory for meeting context, summarize it, and extract prep tasks as drafts.",
            triggerSummary: "Manual Shortcut, calendar-adjacent personal Shortcut, or Action Button flow before a meeting.",
            setupNotes: [
                "Pass the meeting title or customer name as the memory query.",
                "Use the returned brief and task drafts in visible Shortcut steps; do not write calendars or reminders without confirmation."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Search Kairo Memory",
                    nodeKind: .searchMemory,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["query"],
                        optionalFields: ["limit"],
                        description: "Meeting title, customer name, or topic provided by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.matchCount"],
                        optionalFields: ["memoryMatches"],
                        description: "Matching Kairo memory summaries for the prep brief."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        query: "Kairo launch review",
                        sourceName: "Meeting Shortcut",
                        variables: ["shortcutRecipeID": "meeting-prep-brief"],
                        limit: 5
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Summarize with Kairo",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables", "previousStepOutput"],
                        description: "Memory search output or meeting notes."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["displayText", "fields.summary", "fields.chainText"],
                        description: "Meeting prep brief returned as structured Shortcut output."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Meeting Shortcut",
                        variables: [
                            "shortcutRecipeID": "meeting-prep-brief",
                            "kairoInputSource": "previousStepOutput"
                        ]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Extract Prep Tasks",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput", "variables"],
                        description: "Meeting brief or notes that may contain action items."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.taskCount", "fields.chainText"],
                        optionalFields: ["tasks", "reminderDrafts"],
                        description: "Task drafts only; no EventKit write occurs in this demo."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        sourceName: "Meeting Shortcut",
                        variables: [
                            "shortcutRecipeID": "meeting-prep-brief",
                            "kairoInputSource": "previousStepOutput"
                        ]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "request-to-recipe-draft",
            title: "Request to Recipe Draft",
            summary: "Turn an explicit automation idea into a disabled Kairo internal recipe draft for review.",
            triggerSummary: "Share Sheet, Action Button, Siri, or a manual Shortcut that passes an automation request as text.",
            setupNotes: [
                "Pass the user's automation request into Create Kairo Recipe Draft.",
                "Use the returned recipe preview JSON for display or downstream approval steps.",
                "Review and enable the internal Kairo recipe in Kairo; this does not create Apple Shortcuts."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Create Kairo Recipe Draft",
                    nodeKind: .createRecipeDraft,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables"],
                        description: "Natural-language automation request explicitly provided by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.recipeID", "fields.recipeTitle", "fields.recipeStepCount"],
                        optionalFields: ["fields.recipePreviewJSON", "recipeDrafts", "displayText"],
                        description: "Disabled Kairo internal recipe draft metadata for review. No Apple Shortcut is created."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "每天早上整理今天事情，包含待辦和會議提醒",
                        sourceName: "Automation Idea Shortcut",
                        variables: ["shortcutRecipeID": "request-to-recipe-draft"]
                    )
                )
            ]
        ),
        ShortcutDemoRecipe(
            id: "generic-node-runner",
            title: "Generic Node Runner",
            summary: "Use one Shortcut action as a reusable Kairo node by passing node kind and JSON input.",
            triggerSummary: "Manual Shortcut node, Action Button flow, or any Shortcut that builds a JSON dictionary.",
            setupNotes: [
                "Choose Run Kairo Shortcut Node in Shortcuts.",
                "Set nodeKind to a supported Kairo node such as summarize or extractTasks.",
                "Pass ShortcutNodeInput JSON and use the returned ShortcutNodeOutput JSON in downstream steps."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Run Kairo Shortcut Node",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["nodeKind", "inputJSON"],
                        description: "A supported Kairo node kind and encoded ShortcutNodeInput JSON."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["outputJSON", "displayText"],
                        description: "Encoded ShortcutNodeOutput JSON plus a user-readable summary."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Shortcut dictionary:
                        Action: Validate generic Kairo node output
                        Reminder: Chain this output into the next Kairo node
                        """,
                        sourceName: "Generic Shortcut Node",
                        variables: [
                            "shortcutRecipeID": "generic-node-runner",
                            "nodeKind": "summarize"
                        ]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Run Kairo Shortcut Node",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["nodeKind", "inputJSON"],
                        description: "A supported Kairo node kind and encoded ShortcutNodeInput JSON."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.taskCount", "fields.chainText"],
                        optionalFields: ["tasks"],
                        description: "Task count and task drafts returned as structured JSON."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: "Action: Validate generic Kairo node output",
                        sourceName: "Generic Shortcut Node",
                        variables: [
                            "shortcutRecipeID": "generic-node-runner",
                            "nodeKind": "extractTasks",
                            "kairoInputSource": "previousStepOutput"
                        ]
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
        guard let input = steps.first?.sampleInput else {
            return ""
        }

        let text = input.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        return input.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

public struct ShortcutDemoRecipeRun: Codable, Equatable, Sendable {
    public var recipeID: String
    public var recipeTitle: String
    public var displaySummary: String
    public var steps: [ShortcutDemoStepRun]

    public init(
        recipeID: String,
        recipeTitle: String,
        displaySummary: String,
        steps: [ShortcutDemoStepRun]
    ) {
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.displaySummary = displaySummary
        self.steps = steps
    }

    public var totalTaskCount: Int {
        steps.reduce(0) { count, step in count + step.output.tasks.count }
    }

    public var totalReminderDraftCount: Int {
        steps.reduce(0) { count, step in count + step.output.reminderDrafts.count }
    }
}

public struct ShortcutDemoStepRun: Codable, Equatable, Sendable {
    public var shortcutActionTitle: String
    public var nodeKind: ShortcutNodeKind
    public var input: ShortcutNodeInput
    public var output: ShortcutNodeOutput

    public init(
        shortcutActionTitle: String,
        nodeKind: ShortcutNodeKind,
        input: ShortcutNodeInput,
        output: ShortcutNodeOutput
    ) {
        self.shortcutActionTitle = shortcutActionTitle
        self.nodeKind = nodeKind
        self.input = input
        self.output = output
    }
}

public actor ShortcutDemoRecipeRunner {
    private let runtime: ShortcutNodeRuntime

    public init(runtime: ShortcutNodeRuntime) {
        self.runtime = runtime
    }

    public func runSample(_ recipe: ShortcutDemoRecipe) async throws -> ShortcutDemoRecipeRun {
        var stepRuns: [ShortcutDemoStepRun] = []
        var previousOutput: ShortcutNodeOutput?

        for step in recipe.steps {
            var input = step.sampleInput
            if input.variables["kairoInputSource"] == "previousStepOutput",
               let previousOutput {
                input.text = Self.chainedText(from: previousOutput)
            }

            let output = try await runtime.run(step.nodeKind, input: input)
            stepRuns.append(
                ShortcutDemoStepRun(
                    shortcutActionTitle: step.shortcutActionTitle,
                    nodeKind: step.nodeKind,
                    input: input,
                    output: output
                )
            )
            previousOutput = output
        }

        return ShortcutDemoRecipeRun(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            displaySummary: Self.displaySummary(recipe: recipe, stepRuns: stepRuns),
            steps: stepRuns
        )
    }

    private static func displaySummary(recipe: ShortcutDemoRecipe, stepRuns: [ShortcutDemoStepRun]) -> String {
        let stepLabel = stepRuns.count == 1 ? "1 step" : "\(stepRuns.count) steps"
        let taskCount = stepRuns.reduce(0) { count, step in count + step.output.tasks.count }
        let reminderCount = stepRuns.reduce(0) { count, step in count + step.output.reminderDrafts.count }
        return "\(recipe.title): \(stepLabel), \(taskCount) task drafts, \(reminderCount) reminder drafts."
    }

    private static func chainedText(from output: ShortcutNodeOutput) -> String {
        if let chainText = output.fields["chainText"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !chainText.isEmpty {
            return chainText
        }

        if !output.tasks.isEmpty {
            return output.tasks
                .map { "Action: \($0.title)" }
                .joined(separator: "\n")
        }

        if !output.reminderDrafts.isEmpty {
            return output.reminderDrafts
                .map { "Reminder: \($0.title)" }
                .joined(separator: "\n")
        }

        return output.displayText
    }
}
