import Foundation

public protocol KairoRecipeStepInputResolving: Sendable {
    func resolveInput(
        _ input: StepInput,
        requestInput: String?,
        previousOutput: String
    ) -> String
}

public struct DefaultKairoRecipeStepInputResolver: KairoRecipeStepInputResolving {
    public init() {}

    public func resolveInput(
        _ input: StepInput,
        requestInput: String?,
        previousOutput: String
    ) -> String {
        switch input {
        case .literal(let text):
            return text
        case .previousStepOutput:
            return previousOutput
        case .shortcutInput, .sharedContent, .keyboardContext:
            return requestInput ?? previousOutput
        }
    }
}
