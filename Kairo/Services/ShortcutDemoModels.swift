import Foundation

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

    public var totalCalendarDraftCount: Int {
        steps.reduce(0) { count, step in count + step.output.calendarDrafts.count }
    }

    public var totalContactDraftCount: Int {
        steps.reduce(0) { count, step in count + step.output.contactDrafts.count }
    }

    public var totalEmailDraftCount: Int {
        steps.reduce(0) { count, step in count + step.output.emailDrafts.count }
    }

    public var totalPhoneCallHandoffCount: Int {
        steps.reduce(0) { count, step in count + step.output.phoneCallDrafts.count }
    }

    public var totalWebSearchHandoffCount: Int {
        steps.reduce(0) { count, step in count + step.output.webSearchDrafts.count }
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
