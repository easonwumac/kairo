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

Live app wiring uses `FileBackedAuditLogger` at `KairoPaths.auditLogURL`. Audit records are metadata-only: action kind, related memory ids, capability keys, cloud/local model use, confirmation state, and result. They do not persist full action payloads, message bodies, tokens, or attachment contents.

## Agent skills

`AgentSkillCatalog` packages usable capabilities as managed skills. A skill can bind to an `AgentAction`, a Shortcut recipe, an OAuth connector, a local model, or a marketplace manifest. Installed skills are included in `CapabilityPromptContextBuilder` so the model sees named tools it may propose, including whether each skill requires confirmation.

`AgentToolInvocationPlanner` provides a deterministic preview layer before execution. It maps user text to installed Shortcut/HomeKit/custom skills and official OAuth connector metadata, ignores disabled skills, and blocks tool-use candidates when local/no-tool routing is active. Shortcut and OAuth matches remain handoff/connector candidates; action-backed skills can contribute `AgentAction` previews to `AgentCore.respond(to:)`, where they are merged with model-proposed actions and filtered through `SafetyPolicyEngine` before the chat UI displays them. `AICompletionResponse` and `ChatMessage` carry `toolCandidates` separately from `proposedActions`; old chat JSON without that field decodes to an empty candidate list.

`AgentSkillManifest` is the package boundary for downloadable skills. It requires signature metadata, verifies a SHA-256 checksum over the skill payload, and can verify P-256 signatures against `AgentSkillManifestTrustStore` before `AgentSkillManagerService` installs it. `AgentSkillManagerService.previewInstall(jsonString:)` is the app-facing import path for signed JSON manifests: it validates the manifest and returns installed version, incoming version, package version, changelog, and whether the change is install, reinstall, update, or blocked downgrade. Confirmed installs reject semantic version downgrades for an existing skill id, while allowing same-version reinstalls and newer updates. `AgentSkillCatalog.default` maps every official `ShortcutDemoCatalog` recipe into a built-in installed Shortcut skill, and `FileBackedAgentSkillStore` persists marketplace, user-created, and built-in skill overrides, including disabled state, so prompt context can later be derived from the user's actual installed tool set.

The Access Skill Manager is the first app-facing surface for installed, available, and disabled skills. In live app wiring, `KairoEnvironment` creates a `FileBackedAgentSkillStore` at `KairoPaths.agentSkillStoreURL` and injects `AgentSkillManagerService` into `PermissionHubView`; preview mode still falls back to a local sample catalog. `KairoEnvironment.uiTesting(resetPersistentState:)` provides a deterministic file-backed Skill Manager plus static marketplace HTTP responses so XCUITest can exercise refresh, disable/enable, manifest preview, confirm install, and HomeKit preview without network dependency. Access includes a signed manifest JSON preview control and a separate confirm install action for the previewed manifest. It is intentionally metadata-first: showing skills, capabilities, source, installation state, and confirmation requirements does not bypass iOS permissions. Downloadable marketplace skills still need production key rotation/revocation metadata and compatibility gates before production distribution.

`Website/skills` is the static marketplace seed. It contains `skills.json`, card artwork, and signed manifest examples mirrored to `https://github.com/easonwumac/kairo-skills` for live skill updates, while this app repo keeps reference tests for the expected catalog and manifest shape.

`AgentSkillMarketplaceCatalogService.defaultStandaloneRepository` fetches `https://easonwumac.github.io/kairo-skills/skills.json`, resolves relative manifest URLs against that catalog URL, maps remote entries into available `AgentSkill` values, and downloads a selected skill's signed manifest for preview. `PermissionHubView` can refresh that catalog through an injected service and merges remote marketplace skills without overwriting already installed or disabled local skill state. Tapping Install on a downloadable marketplace skill fetches its manifest, asks `AgentSkillManagerService` for an install preview, and still requires the separate confirm install action.

`Website/models` is the static model-catalog seed intended for the planned `https://github.com/easonwumac/kairo-models` repository. It contains `models.json` and a small GitHub Pages index, but no model weights. `LocalModelCatalogService.defaultStandaloneRepository` fetches `https://easonwumac.github.io/kairo-models/models.json`, validates HTTPS download URLs and SHA-256 metadata, and merges remote entries with the built-in fallback catalog. Settings exposes a visible Refresh Catalog control and source label; model downloads still require a separate user-triggered Download action. `LocalModelExternalCommandRuntime` is the development validation bridge for downloaded local models: macOS can call an injected `llama-cli` or MLX-style command runner and parse reply/benchmark token rates, while iOS stays explicit about the missing production inference runtime until an App Store-compatible engine is wired.

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
