import Foundation

public extension ShortcutDemoCatalog {
    static let officialRecipes: [ShortcutDemoRecipe] = coreRecipes + communicationRecipes + phoneRecipes + webRecipes + contactRecipes + workflowRecipes + homeRecipes

    static let coreRecipes: [ShortcutDemoRecipe] = [
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
        )
    ]

    static let workflowRecipes: [ShortcutDemoRecipe] = [
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
            id: "meeting-text-to-calendar-draft",
            title: "Meeting Text to Calendar Draft",
            summary: "Turn explicit meeting text into a Calendar draft output for user-approved EventKit write steps.",
            triggerSummary: "Share Sheet, copied meeting note, Action Button, or manual Shortcut text input.",
            setupNotes: [
                "Pass the meeting title and optional ISO start/end variables into Create Calendar Draft.",
                "Show the returned calendar draft in Shortcuts or Kairo before any EventKit write.",
                "Use a later user-confirmed step if the user chooses to create the real calendar event."
            ],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Create Calendar Draft with Kairo",
                    nodeKind: .createCalendarDraft,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["sourceName", "variables.startDateISO", "variables.endDateISO"],
                        description: "Meeting or schedule text explicitly provided by the user."
                    ),
                    outputContract: ShortcutNodeContract(
                        requiredFields: ["fields.calendarDraftCount", "fields.calendarTitle", "fields.calendarRequiresConfirmation"],
                        optionalFields: ["fields.calendarStartDate", "fields.calendarEndDate", "fields.chainText", "calendarDrafts"],
                        description: "Calendar draft metadata only. No EventKit calendar write is executed by this node."
                    ),
                    sampleInput: ShortcutNodeInput(
                        text: """
                        Meeting: Kairo roadmap review
                        Agenda: confirm Shortcut node outputs and local model rollout
                        """,
                        sourceName: "Meeting Text Shortcut",
                        variables: [
                            "shortcutRecipeID": "meeting-text-to-calendar-draft",
                            "startDateISO": "2026-06-05T02:00:00Z",
                            "endDateISO": "2026-06-05T02:30:00Z"
                        ]
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
    ]
}
