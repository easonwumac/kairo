import Foundation

public struct KairoUITestingShareImportFactory: Sendable {
    public var seedSharedTaskText: Bool

    public init(seedSharedTaskText: Bool = false) {
        self.seedSharedTaskText = seedSharedTaskText
    }

    public func makeQueue() -> ShareIngestionQueue {
        InMemoryShareIngestionQueue(seed: seedSharedTaskText ? [Self.sharedTaskItem()] : [])
    }

    public static func sharedTaskItem() -> ShareIngestionItem {
        let builder = ShareAttachmentBuilder()
        return ShareIngestionItem(
            attachments: [
                builder.text(
                    """
                    TODO: Send prototype link
                    Reminder: Book beta review meeting
                    """,
                    displayName: "Launch Notes"
                )
            ],
            sourceApplication: "UITestShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
    }
}
