#if canImport(SwiftUI)
import SwiftUI

struct KairoBriefingStrip: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                KairoStatusPill(title: "2 shared", systemImage: "square.and.arrow.down", tint: KairoDesign.blue)
                KairoStatusPill(title: "3 reviews", systemImage: "checklist.checked", tint: KairoDesign.amber)
                KairoStatusPill(title: "Memory ready", systemImage: "books.vertical", tint: KairoDesign.teal)
                KairoStatusPill(title: "No silent writes", systemImage: "hand.raised", tint: KairoDesign.amber)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(KairoDesign.groupedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.briefing-strip")
    }
}
#endif
