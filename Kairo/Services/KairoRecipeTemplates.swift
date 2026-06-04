import Foundation

public enum KairoRecipeTemplateFactory {
    public static func sampleCatalog(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipeCatalog {
        KairoRecipeCatalog(recipes: [
            dailyBriefing(now: now),
            meetingPrep(now: now),
            sharedTextToTasks(now: now)
        ])
    }

    public static func dailyBriefing(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "daily-briefing",
            title: "Daily Briefing",
            summary: "Create a concise morning briefing from Kairo-owned context and return draft actions.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .dailyTime(hour: 8, minute: 30),
            steps: [
                KairoRecipeStep(
                    id: "ask-kairo",
                    title: "Draft briefing",
                    kind: .askKairo,
                    input: .literal("Create a concise daily briefing from calendar, reminders, and Kairo memory. If unavailable, ask user to connect capabilities.")
                ),
                KairoRecipeStep(
                    id: "enqueue-draft",
                    title: "Create briefing draft",
                    kind: .enqueueActionDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.memory, .aiProvider, .notifications],
            riskTier: .tier1Draft,
            cloudPolicy: .askEachTime,
            isEnabled: true
        )
    }

    public static func meetingPrep(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "meeting-prep",
            title: "Meeting Prep",
            summary: "Search Kairo memory and prepare a short meeting brief.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .beforeCalendarEvent(minutes: 30),
            steps: [
                KairoRecipeStep(
                    id: "search-memory",
                    title: "Search meeting memory",
                    kind: .searchMemory,
                    input: .literal("upcoming meeting")
                ),
                KairoRecipeStep(
                    id: "ask-kairo",
                    title: "Prepare meeting brief",
                    kind: .askKairo,
                    input: .literal("Prepare a meeting brief from the matching Kairo memory. Include open questions and follow-ups.")
                )
            ],
            requiredCapabilities: [.memory, .aiProvider, .calendar],
            riskTier: .tier1Draft,
            cloudPolicy: .askEachTime,
            isEnabled: true
        )
    }

    public static func sharedTextToTasks(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "shared-text-to-tasks",
            title: "Shared Text to Tasks",
            summary: "Summarize shared text and turn action lines into reminder drafts.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .shareSheet,
            steps: [
                KairoRecipeStep(
                    id: "summarize",
                    title: "Summarize shared text",
                    kind: .summarizeText,
                    input: .sharedContent
                ),
                KairoRecipeStep(
                    id: "extract",
                    title: "Extract tasks",
                    kind: .extractTasks,
                    input: .sharedContent
                ),
                KairoRecipeStep(
                    id: "reminder-drafts",
                    title: "Create reminder drafts",
                    kind: .createReminderDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.shareExtension, .reminders],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
    }

}
