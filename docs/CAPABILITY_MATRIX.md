# iOS Capability Matrix

Kairo 的策略：最大化使用 iOS 公開 API、使用者授權、App Intents、Shortcuts、extensions、外部服務 API；避免 private API、隱藏監控與越權控制。

## Status labels

| Status | Meaning |
|---|---|
| Implemented | 目前 app/core path 可用，且已針對標示範圍測試。 |
| Scaffolded | 已有 code、UI、models 或 protocols，但 beta path 尚未 production-complete。 |
| Test-only / Mock | 只存在 deterministic test/demo path，不可宣稱為真實 runtime 能力。 |
| Planned | 方向接受，但尚未實作。 |
| Not allowed | 不符合 Kairo 的 App Store-safe public API 邊界。 |

## Matrix

| 能力 | Status | iOS 路徑 | 使用者授權 | Beta 備註 / 風險 |
|---|---|---|---|---|
| Chat-first app shell | Implemented | SwiftUI App UI | 否 | Chat 是主畫面；More 管理支援 surfaces。 |
| Chat history | Implemented | JSON-backed app storage | 否 | 可保存 thread；生產 migration 可後續評估。 |
| 長期記憶 | Implemented | JSON store / Memory Center export | 使用者管理 | Save/search/delete/export 已有；deleted JSON records 可 purge from disk。 |
| Share Sheet 匯入 | Implemented | Share Extension + App Group queue | 使用者主動 | Text/URL/image/PDF/file metadata 進 Chat pending attachments；extension queue-only、最多 8 attachments/request。 |
| 文件/圖片選取 | Planned | UIDocumentPicker / PhotosPicker | 使用者主動 | 目前主要靠 Share Extension metadata path；picker UX 尚未完成。 |
| 行事曆 | Implemented | EventKit Calendar | 是 | Chat action 需 preview + confirm；Shortcut nodes 預設產生 draft。 |
| 提醒事項 | Implemented | EventKit Reminders | 是 | Chat action 需 preview + confirm；Shortcut nodes 預設產生 draft。 |
| 通知 | Implemented | UserNotifications | 是 | 只有 Confirm 後才排程。 |
| Contacts create action | Implemented | Contacts.framework | 是 | 只處理使用者要求建立/新增；不讀取、同步或匯出通訊錄。 |
| App Intents | Implemented | AppIntents | 使用者觸發 | Current Shortcut node contracts use `schemaVersion=1` safety fields；後續是 device/App Intent QA。 |
| Siri / Shortcuts | Scaffolded | App Intents + user-installed Shortcuts | 使用者設定 | Kairo 可提供 App Intents/template guidance；不可 silent create/edit Apple Shortcuts。 |
| Kairo Recipes | Implemented | App internal store + App Intents bridge | 使用者建立/啟用 | Kairo-owned workflows；不是 Apple Shortcuts。 |
| Skill Manager | Scaffolded | File-backed manager + Access UI | 使用者管理 | Installed/disabled lifecycle exists；Chat consumes the live effective catalog, including compatibility-blocked state。 |
| URL schemes / Universal Links | Implemented | `openURL` / links | 使用者可見 | 僅 handoff，不能隱藏控制。 |
| Email draft handoff | Implemented | `mailto:` URL handoff | 使用者確認 | 只建立可見草稿；不讀 Mail DB；不靜默寄信。 |
| Messages recipient handoff | Implemented | `sms:` URL handoff | 使用者確認 | 只開可見收件人 handoff；正文留在 Kairo preview；不讀 Messages；不靜默送出。 |
| Phone call handoff | Implemented | `tel:` URL handoff | 使用者確認 | 只開 visible Phone handoff；不讀通話紀錄；不靜默撥號。 |
| Web search handoff | Implemented | HTTPS search URL | 使用者確認 | 只開 Safari/DuckDuckGo 搜尋；不背景瀏覽；不讀 Safari history/cookies。 |
| Apple Maps directions handoff | Implemented | `maps.apple.com` Map Link | 使用者確認 | 只開可見路線；不讀目前位置；不自動開始導航。 |
| OAuth connector auth/status core | Scaffolded | 官方 API + OAuth | 是 | Auth URL、callback redaction、status UI exists；real provider API read/write 尚未完成。 |
| Real OAuth provider API integrations | Planned | 官方 API + OAuth scopes | 是 | 需要 provider scopes、token revoke/delete、review/security work。 |
| BGTaskScheduler policy | Scaffolded | BGAppRefreshTask / BGProcessingTask | 系統與使用者設定 | Policy model exists；不可宣稱 daemon。 |
| HomeKit action model | Scaffolded | HomeKit typed request / executor injection | 是 | Preview/demo/test path exists；real entitlement/live home control 尚未完成。 |
| Real HomeKit entitlement path | Planned | HomeKit entitlement + Home permission | 是 | 需 entitlement、purpose copy、device tests、fallback UI。 |
| Local model catalog | Implemented | Signed/static catalog path | 使用者刷新/選擇 | Catalog metadata exists；production signing/key rotation still planned。 |
| Local model download/select/delete | Implemented | Explicit download to app storage | 使用者明確觸發 | Verified download/checksum/select/delete exists；不得 commit weights/GGUF/cache。 |
| macOS/dev local model reply check | Test-only / Mock | External command adapter | 開發者本機 | 用於 dev validation，不是 iOS production runtime。 |
| iOS production local model inference | Planned | App Store-compatible on-device runtime | 使用者選擇模型 | 尚未完成；不可假裝成功。 |
| Audit log persistence | Implemented | File-backed metadata-only audit log | 否 | Live app persists action kind, capability, memory ids, confirmation/result metadata only。 |
| Memory export/delete lifecycle | Implemented | App storage + export UI | 使用者主動 | Memory Center 可匯出 active records、刪除記憶；JSON store 可 purge deleted records。 |
| Keyboard Extension | Planned | Keyboard Extension | 使用者安裝/啟用 | 尚未完成；暫緩。 |
| Widget | Planned | WidgetKit | 使用者加入 | 尚未完成；暫緩。 |
| Location direct access | Planned | CoreLocation | 是 | Maps handoff 不需要 Kairo 讀定位；CoreLocation path 未完成。 |
| Health | Planned | HealthKit + entitlement | 是 + entitlement | 不預設啟用；需高隱私審查。 |
| MDM 管理 | Planned | Apple MDM / supervised device | 企業註冊 | 只可能是 enterprise branch，非 consumer beta。 |
| Focus / 系統設定控制 | Not allowed | 大多無公開 API | 不適用 | 不宣稱可控制。 |
| 讀取 Messages | Not allowed | 無一般公開 API | 不適用 | 不讀 Messages DB。 |
| 讀取 Apple Mail DB | Not allowed | 無一般公開 API | 不適用 | 只能用 share/OAuth/visible handoff。 |
| 讀取 Notes DB | Not allowed | 無一般公開 API | 不適用 | 不讀 Notes private store。 |
| 任意點擊其他 App | Not allowed | 無 App Store 公開 API | 不適用 | 不使用 hidden UI automation。 |
| 螢幕背景監控 | Not allowed | 無一般公開 API | 不適用 | 不背景截圖、不監看。 |
| ChatGPT web-session scraping | Not allowed | 無合規公開 path | 不適用 | 不讀 cookie、不接管 web session。 |

## 設計準則

1. 如果 iOS 有 public API，而且使用者可明確授權，就列入 capability catalog。
2. 如果只能透過 private API、jailbreak、test automation 達成，就標記為 Not allowed。
3. 如果是高隱私資料，例如 contacts、location、health、email，預設不啟用。
4. 所有外部 action 需要 risk tier。
5. 所有高風險 action 必須 preview + confirm。
6. URL scheme / universal link 只能作為使用者可見 handoff，不能宣稱能讀取或控制對方 App UI。
7. OAuth connector 只能存取使用者授權 scope 內的官方 API；敏感 scopes 需要審核、token 安全與撤銷流程。
8. 背景工作只能使用 BGTaskScheduler 的有限刷新/處理模型；不得宣稱常駐、即時或精準排程。
9. HomeKit action 只能透過 HomeKit entitlement、使用者家庭授權、action preview 與 explicit confirmation 執行；目前 core 已有 typed request / executor injection scaffold，尚未啟用實機 entitlement。
10. Kairo Recipes 是 app 內部 workflows；可以由 Kairo 儲存、preview、run、enable/disable，但不得 silent create/edit Apple Shortcuts。
11. Local notifications 只能透過 `UserNotifications` 和 runtime permission 排程；Chat 內的通知 action 必須先顯示 action preview，使用者按 Confirm 後才可執行。
12. Reminder writes 只能透過 EventKit Reminders 和 runtime permission；Shortcut/recipe 節點預設只產生 drafts，Chat 內的 reminder action 必須先預覽再由使用者 Confirm。
13. Calendar writes 只能透過 EventKit Calendar 和 runtime permission；Shortcut/recipe 節點預設只產生 calendar drafts，Chat 內的 calendar action 必須先預覽再由使用者 Confirm。
14. Contacts writes 只能在使用者明確要求建立/新增聯絡人時，透過 Contacts.framework runtime permission、action preview 與 Confirm 執行；此階段不讀取、搜尋、同步或匯出通訊錄。
15. Email draft handoff 只能在使用者明確要求草擬/撰寫 email 時產生 `mailto:` 草稿 handoff；Kairo 不讀 Apple Mail DB、不抓取 mailbox、不靜默寄信。
16. Messages handoff 只能在使用者明確要求傳訊息/簡訊時產生 `sms:` 收件人 handoff；正文留在 Kairo preview，因 Apple SMS link 不支援正文參數；Kairo 不讀 Messages、不插入正文、不靜默送出。
17. Phone call handoff 只能在使用者明確要求撥打電話時產生 `tel:` handoff；Kairo 不讀通話紀錄、不靜默撥號、不宣稱電話已接通。
18. Web search handoff 只能在使用者明確要求搜尋網路時產生 HTTPS search URL；Kairo 不背景瀏覽、不抓取網頁、不讀 Safari history/cookies，也不宣稱已閱讀搜尋結果。
19. Apple Maps directions handoff 只能在使用者明確要求導航/路線時產生 `maps.apple.com` link；Kairo 不讀目前位置、不追蹤定位、不自動開始導航。
20. Local model download 只能由使用者明確觸發；repo 不可包含 model weights、GGUF、tokenizer、cache 或 generated credentials。
