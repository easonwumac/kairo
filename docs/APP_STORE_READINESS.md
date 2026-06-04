# App Store Readiness

Kairo 的上架策略是：成為一個強大的 iOS Agent，但只使用 App Store 允許的公開 API、使用者授權、App sandbox、App Intents、Shortcuts、Share Extension、通知、BackgroundTasks、官方 OAuth/API 整合與本機模型資產。

## Feature state for beta review

| Area | Status | Review note |
|---|---|---|
| Chat-first app shell | Implemented | Chat is the primary surface; support screens sit behind More. |
| Memory | Implemented | Save/search/delete/export exists behind a backend API facade; deleted JSON records can be purged from disk. |
| Share Extension ingestion | Implemented | Text/URL/image/PDF/file metadata imports into Chat through a backend API facade; extension is queue-only and action-free. |
| App Intents / Shortcut nodes | Implemented | Existing beta nodes have `schemaVersion=1` safety contracts; Kairo-owned internal recipes have backend API lifecycle/run coverage; next work is device/App Intent QA. |
| Skill Manager | Scaffolded | Access lifecycle exists; backend API facade covers catalog/effective catalog/preview/install/disable/enable/remove/user drafts with fail-closed behavior; signed marketplace install/update, compatibility-blocked install, and user-created remove flows have simulator XCUITest smoke coverage; Chat uses the live effective catalog for installed, disabled, and compatibility-blocked skill state. |
| Email / Messages / Phone / Web / Maps handoffs | Implemented | Visible handoff only, preview + explicit confirmation. |
| EventKit / Notifications / Contacts actions | Implemented | Confirmed Chat actions exist for current scope. |
| HomeKit | Scaffolded | Preview/demo/test path exists; real HomeKit entitlement/live control is not complete. |
| OAuth provider APIs | Scaffolded | Auth/callback/status scaffold exists; real provider API integrations are not complete. |
| Local model catalog/download/select/delete | Scaffolded | User-triggered download/select/delete flows exist, no model weights are bundled, download progress/cancellation/checksum/delete/runtime-unavailable/stale-state cleanup paths are package-tested, Settings now shows visible foreground download progress, an explicit cancel control, and a license-approval preview before download confirmation, local model management has a backend API facade for status/select/preference/delete/stale cleanup, and remote catalog payload signatures now fail closed against unknown/revoked/pending-publication/invalid signing keys; production signed catalog publication and real-device iOS runtime proof are still incomplete. |
| macOS/dev local model reply check | Test-only / Mock | External command validation only; not iOS runtime proof. |
| iOS production local model inference runtime | Planned | Must remain unavailable until real device/runtime evidence exists. |
| Keyboard Extension | Planned | Not built for beta. |
| Widget | Planned | Not built for beta. |
| Cross-app UI clicking / background screen watching / private app data reads | Not allowed | Must not appear in product or review claims. |

## 上架定位

推薦描述：

> Kairo is a private iPhone agent with memory, chat history, share-sheet ingestion, Shortcuts automation, local fallback models, and confirmation-based actions across iOS-approved capabilities.

避免描述：

- controls your entire iPhone
- claims access to every app's private data
- watches your screen in the background
- automates any app UI
- bypasses permissions
- ChatGPT browser account takeover or reuse of a user's browser session

## App Review Checklist

Final submission gate: `docs/APP_STORE_SUBMISSION_CHECKLIST.md`.

### Current release blocker summary

- **Real device blocked:** `xcrun devicectl list devices` on 2026-06-04 10:02 CST listed all paired physical devices as `unavailable`, so this pass did not produce real-device sign-off.
- **Copy QA scope:** Review notes avoid claiming iOS production local inference, live HomeKit control, private cross-app data reads, arbitrary UI control, reuse of a user's ChatGPT browser session, or silent Apple Shortcuts creation.
- **Privacy Labels scope:** Current privacy manifest declares no collected data and no tracking, and package source-health tests parse the privacy manifest plus entitlement/review-note boundaries. Recheck labels if analytics, backend accounts, cloud sync, crash provider collection, or connector sync are added.
- **Deletion scope:** Current deletion proof is on-device only. Backend account deletion must stay out of shipped copy unless a backend account exists.
- **Purpose string scope:** Beta app plist includes only currently exercised Calendar, Reminders, Contacts, and Notifications purpose strings; HomeKit, Location, and Photo Library purpose strings stay future-only until those capabilities ship.
- **Catalog trust scope:** App-side trust stores fail closed for unknown, revoked, pending-publication, out-of-window, unsupported, or invalid signing keys. Skill marketplace and local model release keys must remain `publicationStatus=pendingPublication` until matching standalone catalogs and public trust metadata are published. The app-repo `Website/skills/skills.json` and `Website/models/models.json` seeds are marked `catalogSignatureStatus=referenceUnsigned` and are not production signed catalog evidence. `docs/TRUST_STORE_RUNBOOK.md` and `docs/CATALOG_RELEASE_CHECKLIST.md` define the production publication and rotation/revocation gates, but production signed catalogs and release public-key material still need publication in the standalone repos.

### 1. Public API only

- [x] App Review copy QA complete for current docs: review notes do not claim private API access, jailbreak behavior, cross-app private data reads, arbitrary UI control, ChatGPT web-session scraping, or silent Apple Shortcuts creation.
- [x] 不使用越獄能力。
- [x] 不宣稱能讀取其他 App 私有資料。
- [x] 不宣稱能任意點擊/操控其他 App UI。
- [x] 不把 XCUITest/Appium/WebDriverAgent 作為 App Store runtime 功能。
- [x] Email draft handoff uses visible `mailto:` URLs only; Kairo does not read Apple Mail or send email silently.
- [x] Messages handoff uses visible `sms:` recipient URLs only; Kairo does not read Messages, insert body text through the URL, or send messages silently.
- [x] Apple Maps directions handoff uses visible `maps.apple.com` links only; Kairo does not read current location or start navigation silently.

### 2. 權限與 purpose strings

- [x] Calendar / Reminders 使用 EventKit 且有清楚 purpose string；Chat reminder/calendar actions 已使用 EventKit permission + preview + confirmation。
- [x] Notifications 使用 UserNotifications，明確說明用途，Chat action 需 preview + confirmation 後才排程。
- [x] Photos / Documents copy is currently Share Extension/user-selected metadata only; beta plist does not include Photo Library permission until PhotosPicker / PHPhotoLibrary access exists.
- [x] HomeKit live control intentionally remains disabled for beta: current entitlements contain only App Group, beta plist omits `NSHomeKitUsageDescription`, and HomeKit must stay preview/demo/test-only until entitlement, purpose copy, permission fallback, and real-device confirmation are complete.
- [x] Contacts 只在使用者明確要求建立聯絡人時使用 Contacts.framework，且需 runtime permission + preview + confirmation；不讀取或匯出通訊錄。
- [x] Apple Maps handoff does not require Kairo to read current location; beta plist does not include Location permission until CoreLocation access exists.
- [x] Access backend API facade resolves capability permission status and forwards explicit permission requests without treating status reads as OS prompt evidence.
- [ ] Permission-denied fallback UI still needs real-device QA across Calendar / Reminders / Notifications / Contacts.

### 3. Memory privacy

- [x] Memory Center 可查看、刪除與匯出記憶；manual edit remains outside the current beta scope unless added explicitly.
- [x] Memory backend API facade covers list/search/save/delete/erase/export/purge so the UI does not need direct store access for lifecycle actions.
- [x] Private chat 不查詢/帶入 long-term memory context，且會過濾 `saveMemory` action/tool candidates；package tests cover this, not real-device evidence.
- [x] 刪除記憶會在 JSON store 標記刪除，且 purge path 可從磁碟移除 deleted records；目前沒有 production embedding index。
- [x] Private chat request metadata sets provider routing privacy mode; without a selected local model it fails closed instead of calling cloud completion. Package tests cover this, not real-device evidence.
- [x] OpenAI/API key 只存 Keychain。

### 4. AI action safety

- [x] 目前已支援的寫入或外部操作都有 action preview。
- [x] tier1/tier2/tier3 action 需要使用者確認；高風險 handoff 不自動執行。
- [x] 不支援的 iOS 操作用 unsupportedSandboxAction 清楚說明。
- [x] 發送訊息、Email、付款、刪除資料等高風險操作預設不自動執行；付款目前不是支援 action。
- [x] Audit log 使用 metadata-only event model；confirmed、rejected、permission-denied/failed action outcomes are recorded without saving full sensitive payloads.

### 5. Share Extension

- [x] Extension 只匯入使用者主動分享的內容。
- [x] Extension 不執行高風險 agent action。
- [x] Extension 將內容放入 App Group queue，由主 App 讓使用者確認。
- [x] Share import backend API reads pending queue metadata, surfaces attachments/suggested prompt to Chat, and marks items imported without running agent actions in the extension.
- [x] Extension 有時間/記憶體限制下的 fallback：每次最多 enqueue 8 個 attachment metadata。

### 6. Shortcuts / App Intents

- [x] Core registry lists implemented App Intent identifiers for all current Shortcut nodes.
- [x] Core Shortcuts handoff builder encodes input and parses structured callback output.
- [x] Settings UI lists official Shortcut demo recipes with input/output contracts.
- [x] Demo recipe runner executes sample Shortcut node chains for package-level regression tests.
- [x] Kairo-owned internal recipe backend API covers list/save/delete/enable/run/sample seeding without creating Apple Shortcuts.
- [x] App Intents 描述已避免宣稱外部副作用，並明確標示 Kairo internal recipes 不會建立 Apple Shortcuts。
- [x] Intent action 不隱藏高風險副作用；Shortcut nodes 產生 preview/draft/output JSON。
- [x] App Intents return encoded `ShortcutNodeOutput` JSON strings for downstream Shortcuts parsing.
- [x] Shortcut safety schema uses `schemaVersion=1` and explicit confirmation fields such as `reminderRequiresConfirmation=true`, `messageBodyInURL=false`, and `homeActionRequiresConfirmation=true`.
- [x] 高風險 action 仍遵守 confirmation policy；device-level App Intent smoke 仍待真機簽核。

### 6.5 Skill management

- [x] Core `AgentSkillCatalog` exposes installed skills/tools to prompt context.
- [x] Access UI shows installed skills in a Skill Manager section.
- [x] Downloadable skill manifests require signature metadata and SHA-256 checksum verification before install.
- [x] Marketplace signatures can be verified against a public-key trust store before install.
- [x] File-backed skill manager core supports install, disable, enable, remove, and reload.
- [x] Live app environment wires the file-backed skill manager into Access.
- [x] Access UI exposes signed manifest JSON import controls.
- [x] Skill manager rejects signed manifest downgrades and allows same/newer versions.
- [x] Skill update UI shows installed version, incoming version, and changelog.
- [x] Official Shortcut demo recipes are exposed as built-in installed skills and persist disabled state.
- [x] Deterministic tool invocation planner maps provided skill/OAuth connector catalog snapshots to preview candidates, stores chat-visible `toolCandidates`, and sends action-backed skills through safety filtering before chat display.
- [x] Skill marketplace website shows permissions, risk tier, version, author, and changelog before install.
- [x] Standalone skill update repository exists for catalog and manifest updates.
- [x] Production app settings fetch the standalone skill update repository catalog.
- [x] Marketplace skill Install downloads the signed manifest and shows the preview before confirmation.
- [x] `--ui-testing` launches a deterministic Skill Manager environment with static marketplace responses.
- [x] XCUITest smoke source covers Skill Manager refresh, disable/enable, marketplace preview/confirm, chat HomeKit action preview, chat Shortcut tool candidate preview, and HomeKit preview interactions.
- [x] XCUITest covers chat local-notification preview and confirmation before scheduling.
- [x] XCUITest covers chat EventKit reminder preview and confirmation before writing.
- [x] XCUITest covers chat EventKit calendar preview and confirmation before writing.
- [x] XCUITest covers chat Contacts.framework contact preview and confirmation before writing.
- [x] XCUITest covers chat email draft preview and visible handoff confirmation before opening `mailto:`.
- [x] XCUITest covers chat Messages handoff preview and visible confirmation before opening `sms:`.
- [x] XCUITest covers chat Apple Maps directions preview and visible handoff confirmation before opening Maps.
- [x] Marketplace trust store supports key rotation, publication, and revocation metadata, including active/revoked state, `publicationStatus`, validity windows, revoked timestamps, and revoked reasons.
- [x] Marketplace/model catalog trust stores support rotation, pending-publication gating, and emergency revocation metadata, including active/revoked state, validity windows, revoked timestamps, and revoked reasons; the release runbook is documented in `docs/TRUST_STORE_RUNBOOK.md`.
- [x] User-created skills require explicit capability selection and confirmation policy before a disabled local draft can be saved.
- [x] Skill Manager backend API facade covers catalog/effective catalog/preview/install/disable/enable/remove/user drafts, unavailable-service fail-closed behavior, and compatibility-blocked marketplace skills staying out of the executable catalog.
- [x] Skill remove flow has simulator UI smoke coverage for user-created drafts; signed marketplace update preview/confirm has simulator XCUITest smoke coverage.
- [x] Chat uses live Skill Manager effective catalog, including disabled and compatibility-blocked skill state.

### 7. Background tasks

- [x] 不宣稱常駐 daemon。
- [x] 只用合法 background modes / BGTaskScheduler。
- [x] Background work 可被 iOS 延遲或取消。
- [x] 所有 background work 有 expiration handling。
- [x] 使用者可關閉提醒、sync、background refresh。

### 8. Model downloads

- [x] 模型下載由使用者明確觸發；the local-model catalog uses remote manifest entries, not bundled app assets.
- [x] Settings UI 顯示本機模型 catalog/status rows 與 download/select affordances。
- [x] Settings UI 顯示 provider route preference，可選 Automatic / Prefer Local / Prefer Cloud / Local Only。
- [x] Settings UI 可刪除已安裝模型並清除 selected-model state。
- [x] Settings download preview 顯示模型大小、授權、license approval、用途、儲存/備份政策與刪除方式。
- [x] Complete final copy QA for App Review；copy 已保留 iOS local inference / HomeKit live control / private cross-app access / silent Shortcut modification 的限制。
- [x] Package source-health tests cover no-collected-data/no-tracking privacy manifest claims, absence of HomeKit entitlement, and review-note boundary copy for local inference, HomeKit, cross-app access, and silent Shortcut modification.
- [x] Core downloader supports HTTPS + checksum verification.
- [x] Core settings can persist and validate the user-selected installed model.
- [x] Live Settings wiring creates the verified downloader from `KairoEnvironment.live`.
- [x] Remote catalog payload signature verification rejects unknown, revoked, pending-publication, out-of-window, unsupported, or invalid P-256 signing keys before accepting download rows.
- [x] Package tests cover checksum failure, download cancellation cleanup, stale interrupted-download cleanup after restart/status reload, deleting the selected model, and runtime-unavailable fail-closed paths.
- [ ] Publish production signed catalog/public key material and runtime speed proof。
- [x] 模型存在 Application Support/LocalModels，並由 downloader 標記為不進 iCloud backup。
- [x] iOS live wiring keeps the local-model reply check and benchmark runtime fail-closed until an App Store-compatible inference engine is implemented.
- [ ] iOS production inference runtime is implemented and verified on real devices. Current macOS/dev reply check is not proof.

### 9. OpenAI / ChatGPT auth

- [x] Core OAuth connector service builds authorization URLs and stores provider-namespaced token sets.
- [x] Core OAuth login center reports connector status and builds configured authorization sessions.
- [x] Settings UI lists OAuth connector readiness without exposing token values.
- [x] App registers `kairo://` and previews OAuth callbacks with redacted code metadata only.
- [x] OpenAI API key can be saved / dry-run tested / deleted from Settings.
- [x] Live app stores API keys and OAuth token sets in Keychain-backed credential storage.
- [x] OAuth connectors support disconnect / token delete.
- [x] Settings backend API facade covers OpenAI key status/save/dry-run/delete and OAuth login options/session/callback preview/disconnect without exposing raw secrets or authorization codes.
- [x] Malformed or undecodable stored OAuth tokens are treated as reauthorization-required and do not count as connected runtime providers.
- [x] Local Only routing fails closed without calling cloud completion when no local model is selected.
- [x] 不保存 ChatGPT web cookie。
- [x] 不爬取 ChatGPT web session。
- [ ] Additional provider API integrations beyond the current OAuth/API-key scaffolds are not complete.

### 10. Account and deletion

- [x] Current beta has no Kairo backend account; App Review copy must not claim backend account deletion until a backend account exists.
- [x] Memory Center provides user-triggered memory JSON export.
- [x] Memory Center provides memory delete; JSON store can purge deleted records from disk.
- [x] On-device deletion proof and process are documented below for App Review.
- [x] Privacy manifest currently declares no collected data and no tracking; App Privacy Labels should match this no-collection/no-tracking beta claim unless future analytics, account, telemetry, or cloud-sync collection is added.

### 11. Deferred surfaces

- [x] Keyboard Extension is intentionally not part of the current beta; project target/source-health checks keep it out of beta builds.
- [x] Widget is intentionally not part of the current beta; project target/source-health checks keep it out of beta builds.
- [x] Real HomeKit entitlement path is intentionally not part of the current beta until entitlement/device/fallback work is done; beta entitlements remain App Group only.
- [x] Additional OAuth providers are deferred until one provider path is fully reviewed and secure.

## Data deletion evidence and flow

Current beta deletion is on-device and user-triggered:

| Data area | User flow | Evidence scope |
|---|---|---|
| Chat history | Delete chat thread from Chat history UI. | `ChatHistoryStore` deletes file-backed threads; package/UI evidence still needs real-device restart sign-off. |
| Memory records | Memory Center delete button removes a record; export shares active records only. | `JSONFileMemoryStore.delete` marks records deleted and `purgeDeleted` removes deleted JSON records from disk. |
| Local models | Settings / Models delete removes the installed model and clears selected-model state. | Package tests cover selected-model delete; no model weights are committed or bundled. |
| API keys / OAuth tokens | Settings delete/disconnect removes Keychain-backed secrets. | Package tests cover OpenAI API key delete and OAuth token disconnect/delete. |
| Audit logs | Settings / Privacy exposes a user-triggered Clear Audit Log action for metadata-only audit logs; full sensitive payloads should not be stored. | `KairoDeletionAPI.clearAuditLog()` and package tests cover backend deletion; Settings UI wiring exposes the clear action without deleting chat history, memories, API keys, OAuth tokens, or downloaded models. |
| Backend account | Not applicable in current beta. | No backend account exists; do not include backend deletion claims in shipped review copy. |

## Privacy label alignment

Submission checklist: `docs/PRIVACY_LABELS_CHECKLIST.md`.

For the current beta build, App Privacy Labels should state no tracking and no collected data only if the submitted binary keeps the current no-analytics/no-backend-account posture. If any future build adds analytics, telemetry, account sync, cloud memory, or provider-side collection beyond user-configured API calls, update labels and review copy before submission.

Purpose-string alignment:

- Calendar / Reminders / Notifications / Contacts are just-in-time and tied to user-confirmed actions.
- Photos/Documents are currently Share Extension/user-selected metadata surfaces, not background or full-library access claims; `NSPhotoLibraryUsageDescription` is not in the beta plist.
- Location is not required for Apple Maps handoff; `NSLocationWhenInUseUsageDescription` is not in the beta plist, and any future location read must remain user-triggered and just-in-time.
- HomeKit purpose copy must not be exercised in beta until the entitlement/live-control path is complete; `NSHomeKitUsageDescription` is not in the beta plist.

## Real-device beta sign-off

Authoritative physical-device sign-off log: `docs/REAL_DEVICE_BETA_SIGNOFF.md`.

Current `devicectl` check on 2026-06-04 10:02 CST found real devices listed but unavailable:

- `iPad Air 5` (`EDC75137-2987-56F5-A08D-DB0D7A2B8F05`) unavailable.
- `iPhone 17 Pro Max` (`58A417FA-6D4D-5F15-B673-AF238D812161`) unavailable.
- `iPhone Xs Max` (`45BD464D-6093-59A4-A4DA-FA999477B976`) unavailable.

Because no available real device was reachable, the following remain release-blocking and must not be substituted with simulator/package evidence:

- Chat / Memory / Access / Settings smoke.
- Share Extension import.
- App Intents Ask / Save / Search.
- Chat history persistence after app restart.
- Local notification / reminder / calendar preview + confirm.
- Email / message / phone / web / maps handoff preview + confirm.

## Beta acceptance snapshot (2026-06-04)

- [x] `swift test` 通過。
- [x] `xcodegen generate` 通過。
- [x] Focused simulator XCUITest smoke 通過：
  - `testLaunchDrawerChatAndSettingsSmokeFlow`
  - `testSettingsLocalModelCatalogListsDownloadableModels`
  - `testSettingsLocalModelDownloadRequiresConfirmationPreview`
  - `testSettingsShowsShortcutDemoInputOutputContracts`
  - `testShortcutsSurfaceShowsNodeDemoContracts`
  - `testAutomationsRecipeCenterPreviewsRunsAndTogglesInternalRecipe`
  - `testAccessSkillManagerBlocksIncompatibleMarketplaceSkillInstall`
  - `testAccessSkillManagerSearchFiltersSkills`
  - `testSettingsShowsOAuthConnectorReadinessAndBoundaries`
  - `testChatCanPreviewAndConfirmNotificationAction`
  - `testChatCanPreviewAndConfirmReminderAction`
  - `testChatCanPreviewAndConfirmCalendarAction`
  - `testChatCanPreviewAndConfirmContactAction`
  - `testChatCanPreviewAndConfirmEmailDraftHandoff`
  - `testChatCanPreviewAndConfirmMapDirectionsHandoff`
  - `testChatCanPreviewAndConfirmMessagesHandoff`
  - `testChatCanPreviewAndConfirmPhoneCallHandoff`
  - `testChatCanPreviewAndConfirmWebSearchHandoff`
- [x] Package tests currently cover Memory save/search/delete/export plus backend API lifecycle/export facade, Kairo-owned internal recipe backend API lifecycle/run/sample seeding, Share Extension import plus backend API queue-import/mark-imported facade, App Intent registry/type coverage plus Ask/Save/Search node runtime, Access permission backend API status/request forwarding, local model catalog unknown/revoked/pending-publication/out-of-window/invalid signing-key gating, local model download progress/cancellation/checksum/delete/runtime-unavailable/stale-state cleanup, local model backend API facade status/select/preference/delete/stale-cleanup/fail-closed behavior, Skill Manager backend API facade lifecycle/user-draft/compatibility/fail-closed behavior, Settings backend API facade OpenAI/OAuth secret-redaction behavior, live Skill Manager effective catalog, OpenAI API key save/dry-run/delete, OAuth connector malformed-token reauth + token disconnect/delete, and Local Only fail-closed routing without cloud completion calls.
- [x] Share Extension 文字、URL、圖片、PDF/file metadata 匯入由 package tests 覆蓋。
- [x] Reminder / Calendar / Contact / Notification 與 Email / Messages / Phone / Web / Maps preview + confirm path 已由 focused simulator smoke 覆蓋。
- [x] 不支援的跨 App 操作會顯示安全替代方案。
- [ ] 真機 smoke 尚未在這一輪重跑；2026-06-04 10:02 CST 的 `xcrun devicectl list devices` 顯示可見裝置皆為 `unavailable`，Chat / Memory / Access / Settings / Share Extension / App Intents 仍需實機簽核。
- [ ] App Intent Ask / Save / Search 在這一輪尚未做 device-level smoke；目前證據是 registry/type coverage，外加 Ask/Save/Search node package tests，不是實機驗證。
- [ ] Chat history app 重啟 persistence 仍需在真機重跑簽核。
- [ ] HomeKit control action 仍只可宣稱 preview/demo/test path；真實 entitlement/live control 尚未完成。
- [x] OpenAI API key save/dry-run/delete 與 OAuth connector malformed-token reauth + token disconnect/delete 已有 package tests；dry run 不送出網路請求。
- [x] Focused regex secret scan 已於 2026-06-04 重跑，未在 tracked source/docs 中找到明顯 credential。

## Review notes draft

Submission-ready review note copy lives in `docs/APP_REVIEW_NOTES.md`; keep this section aligned with that file before App Review upload.

- Kairo is a chat-first iOS app that uses only public APIs, App Intents, Share Extension, BGTaskScheduler, official OAuth/API flows, and visible URL handoffs.
- Shared content enters Kairo only through Share Extension, document/photo pickers, App Intents/Shortcuts, or official OAuth APIs. Kairo does not read other apps' private containers, control arbitrary app UI, or bypass iOS permissions.
- On-device deletion is user-triggered for chat history, memory JSON/export content, downloaded local models, saved API keys, OAuth tokens, and metadata-only audit logs. If a future Kairo backend account is added, backend account-deletion copy must be reviewed separately before release.
- For the current beta, App Privacy Labels should remain no tracking and no collected data. The submitted binary has no analytics SDK, no backend account, no cloud memory sync, no crash/telemetry collection provider, and no provider-side sync beyond explicit user-configured API calls. If any of those are added later, the privacy labels and this review copy must be updated before submission.
- Background tasks are bounded refresh/index/verify/cleanup jobs only. Kairo is not a daemon, does not watch the screen, and background work can be disabled by the user through iOS settings.
- Any write or external action is previewed and requires explicit confirmation according to the app safety policy.
- Local model catalog/download/select/delete are present, but iOS production local inference is not complete. macOS/dev reply checks and benchmark numbers are not iPhone runtime proof.
- HomeKit is limited to preview/demo/test scaffolding in this beta. Live HomeKit control requires a future entitlement, permission, provider, and real-device review pass.
- Kairo does not create, edit, install, or reorder Apple Shortcuts silently. Users must configure Apple Shortcuts themselves; Kairo only exposes App Intents, internal Kairo recipes, and visible handoff metadata.
