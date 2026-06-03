# iOS Capability Matrix

Kairo 的策略：最大化使用 iOS 公開 API、使用者授權、App Intents、Shortcuts、extensions、外部服務 API；避免 private API、隱藏監控與越權控制。

| 能力 | iOS 路徑 | 使用者授權 | 背景能力 | MVP | 風險 |
|---|---|---:|---:|---:|---|
| Chat | App UI | 否 | 否 | 是 | 低 |
| 長期記憶 | SwiftData/Core Data + encrypted files | 否 | 有限 | 是 | 隱私 |
| Share Sheet 匯入 | Share Extension | 使用者主動 | Extension 限制 | 是 | 低 |
| 文件選取 | UIDocumentPicker | 使用者主動 | 否 | 是 | 低 |
| 圖片選取 | PhotosPicker | 使用者主動/Photos 權限 | 否 | 是 | 中 |
| 行事曆 | EventKit | 是 | 有限 | 是 | 中；Chat action 需 preview + confirm |
| 提醒事項 | EventKit | 是 | 有限 | 是 | 中；Chat action 需 preview + confirm |
| 通知 | UserNotifications | 是 | 是 | 是 | 中；Chat action 需 preview + confirm |
| App Intents | AppIntents | 使用者觸發 | Shortcuts 決定 | 是 | 低 |
| Siri / Shortcuts | App Intents | 使用者設定 | 有限 | 是 | 低 |
| Kairo Recipes | App internal store + App Intents bridge | 使用者建立/啟用 | App 內有限 | 是 | Tier 2+ 需確認；不是 Apple Shortcuts |
| URL schemes / Universal Links | `openURL` / links | 使用者可見 | 否 | 是 | 僅 handoff，不能隱藏控制 |
| Email draft handoff | `mailto:` URL handoff | 使用者確認 | 否 | 是 | 只建立可見草稿；不讀 Mail DB；不靜默寄信 |
| Messages recipient handoff | `sms:` URL handoff | 使用者確認 | 否 | 是 | 只開啟可見收件人 handoff；正文留在 Kairo preview；不讀 Messages；不靜默送出 |
| Phone call handoff | `tel:` URL handoff | 使用者確認 | 否 | 是 | 只開啟可見 Phone handoff；不讀通話紀錄；不靜默撥號 |
| Web search handoff | HTTPS search URL | 使用者確認 | 否 | 是 | 只開啟可見 Safari/DuckDuckGo 搜尋；不背景瀏覽；不讀取或抓取網頁 |
| Apple Maps directions handoff | `maps.apple.com` Map Link | 使用者確認 | 否 | 是 | 只開啟可見路線；不讀目前位置；不自動開始導航 |
| OAuth connectors | 官方 API + OAuth | 是 | 有限 / 後端輔助 | 後續 | Token / scope 安全 |
| BGTaskScheduler | BGAppRefreshTask / BGProcessingTask | 系統與使用者設定 | 有限、非即時 | 是 | 不可宣稱 daemon |
| Contacts | Contacts.framework | 是 | 否 | 後續 | 隱私高；Chat action 需 preview + confirm；不讀取/匯出聯絡人資料庫 |
| Location | CoreLocation / Maps handoff | Maps handoff 為使用者確認；CoreLocation 需 runtime permission | 特定模式 | Handoff 是；定位後續 | 隱私高 |
| Health | HealthKit | 是 + entitlement | 有限 | 不預設 | 隱私高 |
| Home | HomeKit | 是 | 有限 | Scaffolded | 中 |
| Focus / 系統設定 | 大多無公開 API | 不適用 | 不適用 | 否 | 不可行 |
| 讀取 Messages | 無一般公開 API | 不適用 | 不適用 | 否 | 不可行 |
| 讀取 Apple Mail DB | 無一般公開 API | 不適用 | 不適用 | 否 | 不可行 |
| 讀取 Notes DB | 無一般公開 API | 不適用 | 不適用 | 否 | 不可行 |
| 任意點擊其他 App | 無 App Store 公開 API | 不適用 | 不適用 | 否 | 不可行 |
| 螢幕背景監控 | 無一般公開 API | 不適用 | 不適用 | 否 | 不可行 |
| MDM 管理 | Apple MDM / supervised device | 企業註冊 | 是 | 企業分支 | 非消費版 |
| 外部服務資料 | OAuth / vendor API | 是 | 後端可 | 後續 | Token 安全 |

## 設計準則

1. 如果 iOS 有 public API，而且使用者可明確授權，就列入 capability catalog。
2. 如果只能透過 private API、jailbreak、test automation 達成，就標記為 R&D only。
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
