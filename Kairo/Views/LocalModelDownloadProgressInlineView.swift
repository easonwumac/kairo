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
                Button(KairoL10n.string("settings.models.download.cancelActive"), role: .cancel, action: onCancel)
                    .font(.caption2)
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.muted, isCompact: true))
                    .accessibilityIdentifier("settings.models.\(modelID).download-active-cancel")
            }
        }
    }
}
#endif
