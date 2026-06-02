# Architecture

## High-Level Components

```text
┌────────────────────────────────────┐
│ SwiftUI App                         │
│ - Chat                              │
│ - Memory Center                     │
│ - Permission Hub                    │
│ - Action Preview                    │
└────────────────────────────────────┘
                 │
┌────────────────▼────────────────────┐
│ Agent Core                           │
│ - Planner                            │
│ - Memory Retriever                   │
│ - Safety Policy Engine               │
│ - Capability Registry                │
│ - Audit Logger                       │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│ Services                             │
│ - AIProvider                         │
│ - MemoryStore                        │
│ - PermissionService                  │
│ - ActionExecutor                     │
│ - CredentialStore                    │
│ - NotificationService                │
│ - CalendarReminderService            │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│ iOS System Surfaces                  │
│ - App Intents / Shortcuts            │
│ - Share Extension                    │
│ - EventKit                           │
│ - UserNotifications                  │
│ - PhotosUI / DocumentPicker          │
│ - BackgroundTasks                    │
└─────────────────────────────────────┘
```

## Core Flow

1. 使用者輸入或分享內容。
2. Kairo 建立 `AgentRequest`。
3. `MemoryRetriever` 找相關記憶。
4. `AIProvider` 產生回應或 action plan。
5. `SafetyPolicyEngine` 評估 action risk。
6. 若需要確認，顯示 `ActionPreviewView`。
7. 使用者確認後，`ActionExecutor` 呼叫對應 iOS service。
8. `AuditLogger` 記錄結果。
9. 可選擇寫入新記憶。

## Modules

- `Models`：Memory、Action、Permission、Audit、AI request/response。
- `Services`：資料儲存、模型呼叫、權限、iOS action、通知、憑證。
- `Views`：Chat、Memory Center、Permission Hub、Action Preview。
- `Intents`：App Intents / Shortcuts。
- `Extensions`：Share Extension。
- `Shared`：可在 app/extension 共用的型別。

## Persistence

MVP 可先用 protocol + in-memory implementation，後續接 SwiftData/Core Data。

正式版：

- SwiftData/Core Data：metadata。
- Encrypted file storage：raw chunks。
- Keychain：secrets。
- Vector index：sqlite-vec / USearch。

## Xcode Target 建議

- `KairoApp`：主 iOS App。
- `KairoShareExtension`：Share Extension。
- `KairoWidget`：Widget。
- `KairoCore`：Swift Package / shared library。
- `KairoTests`：unit tests。
