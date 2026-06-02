#if canImport(SwiftUI)
import SwiftUI

public struct ActionPreviewView: View {
    public let action: AgentAction
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    public init(action: AgentAction, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.action = action
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action.title).font(.title2.bold())
            Text(action.rationale).foregroundStyle(.secondary)
            Text("Risk: \(action.riskTier.rawValue)").font(.caption)

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)
                Spacer()
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
#endif
