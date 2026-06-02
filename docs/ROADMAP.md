# Roadmap

## Phase 0：專案骨架

- 建 repo。
- 建 docs。
- 建 Swift source scaffold。
- 定義 capability matrix。
- 定義 memory schema。
- 定義 safety policy。
- 定義 OpenAI provider abstraction。

## Phase 1：本機 Agent MVP

- SwiftUI App shell。
- Chat screen。
- Memory Center。
- SwiftData/Core Data persistence。
- Keychain credential store。
- Local search。
- OpenAI API key 模式。

## Phase 2：iOS 入口

- Share Extension。
- App Intents。
- Shortcuts actions。
- UserNotifications。
- EventKit reminders/calendar。
- Files / Photos picker。

## Phase 3：安全與權限中心

- Permission Hub。
- Capability Catalog。
- Action Preview。
- Confirmation flow。
- Audit Log。
- Memory delete/export。

## Phase 4：外部服務

優先選一個：

- Google Calendar + Gmail
- 或 Microsoft 365

加上 OAuth、sync、briefing、draft reply。

## Phase 5：雲端與同步

- Kairo account。
- Sign in with Apple。
- Optional CloudKit sync 或自建 backend。
- pgvector / object storage。
- APNs。
- Rate limit / billing。

## Phase 6：進階 Agent

- Local embeddings。
- Sensitive data classifier。
- More App Intents。
- Widget。
- Shortcuts recipes。
- Local model experiments。

## Phase 7：Skill 管理與 marketplace

- 把可操作能力封裝成 `AgentSkill`。
- 讓 model prompt context 明確看到 installed skills/tools。
- `AgentToolInvocationPlanner` 將 user request 映射到 installed skill/OAuth connector preview candidates；chat 會顯示 Shortcut/OAuth tool candidates，action-backed skills 仍走 confirmation-gated safety policy。
- Skill manifest：signature metadata、SHA-256 checksum、public-key verification、file-backed lifecycle。
- Live app environment-backed Skill Manager state。
- Signed manifest JSON import in Access。
- Skill version downgrade protection。
- Skill update preview：installed version、incoming version、changelog、confirm before replace。
- Skill Manager UI：install / disable / enable / remove / inspect permissions。
- 官方 Shortcut demo recipes 與 HomeKit controls 已映射為 built-in skills，並可透過 file-backed manager 持久化狀態。
- `--ui-testing` deterministic Skill Manager：static marketplace refresh/install preview、disable/enable、chat action preview、chat Shortcut tool candidate、HomeKit preview e2e source coverage。
- 使用者可新增自訂 skill manifest。
- Skill marketplace website：搜尋、分類、權限、風險、版本與下載。
- 獨立 `kairo-skills` GitHub repo：專門放可更新 skill catalog、manifest、GitHub Pages。
- Model catalog backend seed：`Website/models` + `LocalModelCatalogService`，準備鏡像到獨立 `kairo-models` repo，讓 app 以可見刷新取得 downloadable model list 與 runtime benchmark metadata。
- Trust-store key rotation/revocation、checksum、compatibility gates。
