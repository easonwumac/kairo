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
│ - Integration Registry               │
│ - Agent Skill Catalog                │
│ - Background Task Policy             │
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
│ - IntegrationRegistry                │
│ - AgentSkillCatalog                  │
│ - BackgroundTaskPolicy               │
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

## Agent skills

`AgentSkillCatalog` packages usable capabilities as managed skills. A skill can bind to an `AgentAction`, a Shortcut recipe, an OAuth connector, a local model, or a future marketplace manifest. Installed skills are included in `CapabilityPromptContextBuilder` so the model sees named tools it may propose, including whether each skill requires confirmation.

The Access Skill Manager is the first app-facing surface for installed skills. It is intentionally metadata-first: showing skills, capabilities, source, installation state, and confirmation requirements does not bypass iOS permissions. Downloadable marketplace skills should later use signed manifests, checksums, compatibility gates, and explicit install/update/remove flows.

## Modules

- `Models`：Memory、Action、Permission、Audit、AI request/response。
- `Services`：資料儲存、模型呼叫、權限、iOS action、通知、憑證。
- `Views`：Chat、Memory Center、Permission Hub、Action Preview。
- `Intents`：App Intents / Shortcuts。
- `Extensions`：Share Extension。
- `Shared`：可在 app/extension 共用的型別。

## Integration registry

`IntegrationRegistry` is metadata, not a permission bypass. It records supported and planned surfaces for popular apps:

- App Intents / Shortcuts for user-configured automation.
- URL schemes and universal links for visible handoff only.
- Share Extension and document picker intake for user-selected content.
- OAuth connector metadata for official APIs, scopes, token-exchange expectations, and data boundaries.

The agent prompt context includes this registry so model plans can choose safe handoff/API paths and produce `unsupportedSandboxAction` when a user asks for private cross-app access.

## Background task policy

`BackgroundTaskPolicy` describes BGTaskScheduler-compatible work:

- `com.kairo.app.refresh` maps to bounded `BGAppRefreshTaskRequest` style work such as importing queued shared items.
- `com.kairo.app.processing.local-model` maps to user-approved bounded model maintenance.
- `com.kairo.app.processing.connectors` maps to OAuth connector sync checkpoints.

Kairo must not claim always-on background execution. iOS chooses launch timing, may skip launches, and can expire work. Every task needs checkpointing, expiration handling, and user-visible recovery/rescheduling.

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
