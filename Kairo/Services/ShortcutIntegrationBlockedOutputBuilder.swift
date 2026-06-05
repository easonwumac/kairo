import Foundation

public enum ShortcutIntegrationBlockedOutputSourceNamePolicy: Sendable {
    case omitWhenMissing
    case includeEmptyWhenMissing
}

public protocol ShortcutIntegrationBlockedOutputBuilding: Sendable {
    func blockedOutput(
        kind: ShortcutNodeKind,
        input: ShortcutNodeInput,
        skillID: AppIntegrationSkillID,
        displayText: String,
        fields: [String: String],
        sourceNamePolicy: ShortcutIntegrationBlockedOutputSourceNamePolicy
    ) -> ShortcutNodeOutput
}

public struct DefaultShortcutIntegrationBlockedOutputBuilder: ShortcutIntegrationBlockedOutputBuilding {
    public init() {}

    public func blockedOutput(
        kind: ShortcutNodeKind,
        input: ShortcutNodeInput,
        skillID: AppIntegrationSkillID,
        displayText: String,
        fields: [String: String],
        sourceNamePolicy: ShortcutIntegrationBlockedOutputSourceNamePolicy = .omitWhenMissing
    ) -> ShortcutNodeOutput {
        var outputFields = input.variables
        switch (input.sourceName, sourceNamePolicy) {
        case (.some(let sourceName), _):
            outputFields["sourceName"] = sourceName
        case (.none, .includeEmptyWhenMissing):
            outputFields["sourceName"] = ""
        case (.none, .omitWhenMissing):
            break
        }
        outputFields[ShortcutNodeInput.integrationSkillIDVariableKey] = skillID.rawValue
        outputFields["success"] = "false"
        for (key, value) in fields {
            outputFields[key] = value
        }

        return ShortcutNodeOutput(
            kind: kind,
            displayText: displayText,
            fields: outputFields
        )
    }
}
