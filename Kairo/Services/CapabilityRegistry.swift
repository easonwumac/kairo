import Foundation

public struct CapabilityRegistry: Sendable {
    public var capabilities: [Capability]

    public init(capabilities: [Capability] = CapabilityRegistry.defaultCapabilities) {
        self.capabilities = capabilities
    }

    public static let defaultCapabilities: [Capability] = [
        Capability(
            key: .chat,
            displayName: "Chat",
            description: "和 Kairo 對話，查詢記憶與規劃任務。",
            permission: .none,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .memory,
            displayName: "Memory",
            description: "儲存、搜尋、編輯與刪除使用者選擇交給 Kairo 的記憶。",
            permission: .none,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .shareExtension,
            displayName: "Share Extension",
            description: "從其他 App 分享內容到 Kairo。",
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .appIntents,
            displayName: "App Intents & Shortcuts",
            description: "讓 Siri 與捷徑呼叫 Kairo 支援的動作。",
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .integrationRegistry,
            displayName: "Integration Registry",
            description: "記錄 App Intents、Shortcuts、URL schemes 與 OAuth connector metadata，避免誇大跨 App 能力。",
            permission: .userInitiated,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .backgroundTasks,
            displayName: "Background Task Policy",
            description: "規劃 BGTaskScheduler 可接受的有限背景刷新/處理工作，不宣稱常駐 daemon。",
            permission: .entitlement,
            status: .available,
            isMVP: true
        ),
        Capability(
            key: .notifications,
            displayName: "Notifications",
            description: "傳送 briefing、確認請求與提醒通知。",
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .calendar,
            displayName: "Calendar",
            description: "讀取授權行事曆並建立行事曆草稿。",
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .reminders,
            displayName: "Reminders",
            description: "建立與整理提醒事項。",
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .photos,
            displayName: "Photos",
            description: "處理使用者選取的圖片或截圖。",
            permission: .userInitiated,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .documents,
            displayName: "Documents",
            description: "處理使用者選取的文件。",
            permission: .userInitiated,
            status: .unknown,
            isMVP: true
        ),
        Capability(
            key: .homeKit,
            displayName: "HomeKit",
            description: "在 HomeKit 權限與使用者確認後執行家庭場景或配件控制。",
            permission: .runtimePrompt,
            status: .unknown,
            isMVP: false
        ),
        Capability(
            key: .externalConnectors,
            displayName: "External Connectors",
            description: "透過 OAuth 連接 Gmail、Microsoft 365、Notion 等外部服務。",
            permission: .oauth,
            status: .unknown,
            isMVP: false
        )
    ]
}
