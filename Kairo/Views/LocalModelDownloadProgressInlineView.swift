#if canImport(SwiftUI)
import SwiftUI

struct LocalModelDownloadProgressInlineView: View {
    let progress: LocalModelDownloadProgressState
    let modelID: String
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(progress.displayText, value: progress.fractionCompleted)
                .font(.caption)
                .accessibilityIdentifier("settings.models.\(modelID).download-progress")

            if progress.allowsCancellation {
                Button("Cancel Download", role: .cancel, action: onCancel)
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.models.\(modelID).download-active-cancel")
            }
        }
    }
}
#endif
