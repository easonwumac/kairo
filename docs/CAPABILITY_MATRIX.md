# iOS Capability Matrix

Kairo 的策略：最大化使用 iOS 公開 API、使用者授權、App Intents、Shortcuts、extensions、外部服務 API；避免 private API、隱藏監控與越權控制。

| 能力 | iOS 路徑 | 使用者授權 | 背景能力 | MVP | 風險 |
|---|---|---:|---:|---:|---|
| Chat | App UI | 否 | 否 | 是 | 低 |
| 長期記憶 | SwiftData/Core Data + encrypted files | 否 | 有限 | 是 | 隱私 |
| Share Sheet 匯入 | Share Extension | 使用者主動 | Extension 限制 | 是 | 低 |
| 文件選取 | UIDocumentPicker | 使用者主動 | 否 | 是 | 低 |
| 圖片選取 | PhotosPicker | 使用者主動/Photos 權限 | 否 | 是 | 中 |
| 行事曆 | EventKit | 是 | 有限 | 是 | 中 |
| 提醒事項 | EventKit | 是 | 有限 | 是 | 中 |
| 通知 | UserNotifications | 是 | 是 | 是 | 中 |
| App Intents | AppIntents | 使用者觸發 | Shortcuts 決定 | 是 | 低 |
| Siri / Shortcuts | App Intents | 使用者設定 | 有限 | 是 | 低 |
| URL schemes / Universal Links | `openURL` / links | 使用者可見 | 否 | 是 | 僅 handoff，不能隱藏控制 |
| OAuth connectors | 官方 API + OAuth | 是 | 有限 / 後端輔助 | 後續 | Token / scope 安全 |
| BGTaskScheduler | BGAppRefreshTask / BGProcessingTask | 系統與使用者設定 | 有限、非即時 | 是 | 不可宣稱 daemon |
| Contacts | Contacts.framework | 是 | 否 | 後續 | 隱私高 |
| Location | CoreLocation | 是 | 特定模式 | 後續 | 隱私高 |
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
