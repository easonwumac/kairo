# Kairo

Kairo 是一個有記憶的 iPhone Agent：它會記住使用者選擇交給它的內容，透過 iOS 公開 API、權限授權、App Intents、Shortcuts、Share Extension、通知、行事曆/提醒事項、文件/照片選取器與外部服務 API，執行 iOS 允許的操作。

> 產品原則：**能取得合法授權與 sandbox 允許的能力，就做；不能被 iOS 公開 API 支援的跨 App 監控/控制，就不假裝可以做。**

## 一句話

一個手機級 AI Agent，擁有可編輯的長期記憶，能理解使用者分享的內容，並在使用者確認後操作 iOS 支援的功能與外部服務。

## MVP 能力

- Chat 介面：和 Agent 對話、查詢記憶、規劃任務。
- Memory Center：新增、搜尋、編輯、刪除、匯出記憶。
- Share Extension：從其他 App 分享文字、URL、PDF、圖片、截圖到 Kairo。
- App Intents / Shortcuts：讓使用者用 Siri 或捷徑觸發 Agent 動作。
- iOS permissions hub：集中管理 Contacts、Calendar、Reminders、Photos、Documents、Notifications、Location 等授權狀態。
- Action Preview：所有高風險操作先產生草稿，使用者確認後才執行。
- Audit Log：記錄 Agent 使用了哪些資料、建議了什麼、做了什麼。
- OpenAI / ChatGPT auth abstraction：支援 OpenAI API key、官方 OAuth/ChatGPT connector 預留；不使用或模擬使用者 ChatGPT 網頁 session。
- Local model fallback strategy：未來可讓使用者下載小模型，例如 Qwen 0.6B～0.8B 等級模型，作為離線、隱私敏感與雲端失敗時的 fallback。

## 明確不承諾

Kairo 不會承諾以下不被一般 iOS App Store App 支援的能力：

- 任意讀取其他 App 的私有資料。
- 偷看螢幕或背景截圖。
- 任意點擊、輸入、操控其他 App UI。
- 繞過 iOS permission prompt。
- 常駐背景 daemon。
- 未經授權讀取 Messages、Apple Mail、Notes 內部資料庫。
- 使用 private API 或 jailbreak-only 能力作為產品功能。
- 模擬 ChatGPT 網頁登入、保存 ChatGPT web cookie、爬取 ChatGPT session。

## 目前已實作

- Swift Package `KairoCore`
- `AgentCore`
- `MemoryRecord`
- `InMemoryMemoryStore`
- `JSONFileMemoryStore`
- `CredentialStore`
- `KeychainCredentialStore`
- `OpenAIProvider`
- `ChatGPTOAuthService` scaffold with PKCE authorization URL / callback validation / token storage
- `CapabilityRegistry`
- `SafetyPolicyEngine`
- `AuditLogger`
- SwiftUI scaffold：Chat、Memory、Access、Settings
- App Intents scaffold：Ask、Save、Search
- EventKit service scaffold：Calendar / Reminders
- Privacy manifest / Info.plist placeholders
- XcodeGen `project.yml`
- Unit tests

## 專案結構

```text
kairo/
├── README.md
├── Package.swift
├── project.yml
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── CAPABILITY_MATRIX.md
│   ├── AUTH_OPENAI.md
│   ├── SHORTCUTS_STRATEGY.md
│   ├── LOCAL_MODEL_FALLBACK.md
│   ├── SAFETY_AND_PRIVACY.md
│   ├── GITHUB_PUBLISHING.md
│   └── ROADMAP.md
├── Kairo/
│   ├── App/
│   ├── Models/
│   ├── Services/
│   ├── Views/
│   ├── Intents/
│   ├── Extensions/
│   └── Resources/
├── Config/
└── Tests/
```

## 開發

```bash
swift test
```

建議 iOS 版本：iOS 17+，以 SwiftUI、SwiftData/Core Data、App Intents、Share Extension、EventKit、Keychain 為主。

## GitHub 發布

發布前請先看：

```text
docs/GITHUB_PUBLISHING.md
```

基本流程：

```bash
swift test
rg -n "sk-|OPENAI_API_KEY|apiKey|password|secret|token|refresh_token|access_token" .
git init
git branch -M main
git add .
git commit -m "Initial Kairo scaffold"
gh repo create kairo --public --source . --remote origin --push
```
