# App Store Readiness

Kairo 的上架策略是：成為一個強大的 iOS Agent，但只使用 App Store 允許的公開 API、使用者授權、App sandbox、App Intents、Shortcuts、Share Extension、通知、BackgroundTasks、官方 OAuth/API 整合與本機模型資產。

## 上架定位

推薦描述：

> Kairo is a private iPhone agent with memory, chat history, share-sheet ingestion, Shortcuts automation, local fallback models, and confirmation-based actions across iOS-approved capabilities.

避免描述：

- controls your entire iPhone
- reads all apps
- watches your screen in the background
- automates any app UI
- bypasses permissions
- ChatGPT account takeover / web session reuse

## App Review Checklist

### 1. Public API only

- [ ] 不使用 private API。
- [ ] 不使用越獄能力。
- [ ] 不宣稱能讀取其他 App 私有資料。
- [ ] 不宣稱能任意點擊/操控其他 App UI。
- [ ] 不把 XCUITest/Appium/WebDriverAgent 作為 App Store runtime 功能。

### 2. 權限與 purpose strings

- [ ] Calendar / Reminders 使用 EventKit 且有清楚 purpose string。
- [ ] Notifications 使用 UserNotifications，明確說明用途。
- [ ] Photos / Documents 以使用者選取為主，不預設要求全庫存取。
- [ ] HomeKit 只在有明確家庭控制 use case、entitlement、purpose copy 與 confirmation flow 後啟用。
- [ ] Contacts / Location / Health 等高敏感權限只在功能需要時要求。
- [ ] 權限被拒絕時有 fallback UI。

### 3. Memory privacy

- [ ] Memory Center 可查看、編輯、刪除記憶。
- [ ] Private chat 不寫入長期記憶。
- [ ] 刪除記憶會刪除 JSON/DB、附件 reference、derived summaries、embedding/index。
- [ ] 敏感資料預設不送雲端。
- [ ] OpenAI/API key 只存 Keychain。

### 4. AI action safety

- [ ] 所有寫入或外部操作都有 action preview。
- [ ] tier1/tier2/tier3 action 需要使用者確認。
- [ ] 不支援的 iOS 操作用 unsupportedSandboxAction 清楚說明。
- [ ] 發送訊息、Email、付款、刪除資料等高風險操作預設不自動執行。
- [ ] Audit log 不保存完整敏感 payload，除非使用者同意。

### 5. Share Extension

- [ ] Extension 只匯入使用者主動分享的內容。
- [ ] Extension 不執行高風險 agent action。
- [ ] Extension 將內容放入 App Group queue，由主 App 讓使用者確認。
- [ ] Extension 有時間/記憶體限制下的 fallback。

### 6. Shortcuts / App Intents

- [x] Core registry lists implemented App Intent identifiers for all current Shortcut nodes.
- [x] Core Shortcuts handoff builder encodes input and parses structured callback output.
- [x] Settings UI lists official Shortcut demo recipes with input/output contracts.
- [ ] App Intents 描述準確。
- [ ] Intent action 不隱藏高風險副作用。
- [ ] 可回傳 structured output 給 Shortcuts。
- [ ] 高風險 action 仍遵守 confirmation policy。

### 6.5 Skill management

- [x] Core `AgentSkillCatalog` exposes installed skills/tools to prompt context.
- [x] Access UI shows installed skills in a Skill Manager section.
- [x] Downloadable skill manifests require signature metadata and SHA-256 checksum verification before install.
- [x] File-backed skill manager core supports install, disable, enable, remove, and reload.
- [ ] Marketplace signatures are verified against a real public-key trust store.
- [ ] Skill marketplace website shows permissions, risk tier, version, author, and changelog before install.
- [ ] User-created skills require explicit capability selection and confirmation policy.
- [ ] Skill install/update/remove flows are covered by UI/e2e tests.

### 7. Background tasks

- [ ] 不宣稱常駐 daemon。
- [ ] 只用合法 background modes / BGTaskScheduler。
- [ ] Background work 可被 iOS 延遲或取消。
- [ ] 所有 background work 有 expiration handling。
- [ ] 使用者可關閉提醒、sync、background refresh。

### 8. Model downloads

- [ ] 模型下載由使用者明確觸發。
- [x] Settings UI 顯示本機模型 catalog/status rows 與 download/select affordances。
- [x] Settings UI 顯示 provider route preference，可選 Automatic / Prefer Local / Prefer Cloud / Local Only。
- [x] Settings UI 可刪除已安裝模型並清除 selected-model state。
- [ ] 顯示模型大小、授權、用途、刪除方式。
- [x] Core downloader supports HTTPS + checksum verification.
- [x] Core settings can persist and validate the user-selected installed model.
- [ ] Production signed catalog、真實 downloader wiring、progress/cancel UI。
- [ ] 模型存在 Application Support，不進 iCloud backup，或有明確策略。
- [ ] 本機模型不執行任意程式碼，只作為 app binary 內 inference engine 的資料資產。

### 9. OpenAI / ChatGPT auth

- [x] Core OAuth connector service builds authorization URLs and stores provider-namespaced token sets.
- [x] Core OAuth login center reports connector status and builds configured authorization sessions.
- [x] Settings UI lists OAuth connector readiness without exposing token values.
- [ ] 支援 API key 或官方 OAuth/connector。
- [ ] 不保存 ChatGPT web cookie。
- [ ] 不爬取 ChatGPT web session。
- [ ] Token 存 Keychain。
- [ ] 可登出並刪除 tokens。

### 10. Account and deletion

- [ ] 若有 Kairo backend，提供 account deletion。
- [ ] 提供資料匯出。
- [ ] 提供資料刪除證明與流程。
- [ ] Privacy policy 與 App Privacy Labels 一致。

## Beta acceptance criteria

- [ ] `swift test` 通過。
- [x] Core UI e2e smoke scenarios and XCUITest target are scaffolded.
- [ ] Simulator/real-device XCUITest smoke flow passes.
- [ ] 真機可開啟 Chat / Memory / Access / Settings。
- [ ] Chat history app 重啟後仍存在。
- [ ] Share Extension 可匯入文字、URL、圖片、PDF/file metadata。
- [ ] App Intent 可 Ask / Save / Search。
- [ ] Reminder / Calendar permission flow 可用。
- [ ] HomeKit control action 只在授權與確認後執行；未授權時顯示 fallback。
- [ ] OpenAI API key 可存入/刪除 Keychain。
- [ ] 無 API key 時有本機 fallback 或清楚錯誤。
- [ ] 不支援的跨 App 操作會顯示安全替代方案。
- [ ] Secret scan 無真實 credential。

## Review notes draft

Kairo uses only public APIs and user-selected data. It cannot and does not read other apps' private containers, control arbitrary app UI, or bypass iOS permissions. Shared content enters Kairo only through Share Extension, document/photo pickers, App Intents/Shortcuts, or official OAuth APIs. Any write or external action is previewed and requires user confirmation according to the app safety policy.
