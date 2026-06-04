#if canImport(SwiftUI)
import SwiftUI

struct ShareImportBanner: View {
    let notice: String
    let canSend: Bool
    let send: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label(notice, systemImage: "square.and.arrow.down.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(action: send) {
                Text("Send to Chat")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(!canSend)
            .accessibilityIdentifier("chat.share-import.send")
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.share-import.banner")
    }
}
#endif
