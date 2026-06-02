# Next Steps

## 立即下一步

1. 用 Xcode 建立 iOS App project，名稱 `Kairo`。
2. 將目前 Swift Package 的 `KairoCore` source 加入 app target。
3. 建立 targets：
   - `KairoApp`
   - `KairoShareExtension`
   - `KairoWidget`
   - `KairoCoreTests`
4. 設定 App Group，讓主 App、Share Extension、Widget 可共用必要資料。
5. 實作 Keychain-backed `CredentialStore`。
6. 實作 SwiftData/Core Data-backed `MemoryStore`。
7. 接 OpenAI Responses API 或後端代理。
8. 接 EventKit reminders/calendar permission 與實際寫入。
9. 建立 Share Extension ingestion flow。
10. 建立 App Store review checklist。

## 第一個可展示 Demo

- Chat tab 可以問 Kairo。
- Memory tab 可以新增/搜尋記憶。
- Access tab 可以看到 capability catalog。
- 使用 mock AI provider 回答。
- 測試通過：`swift test`。

## 注意

目前 repo 是 source-first scaffold，不是完整 `.xcodeproj`。這樣比較乾淨，後續可以選擇：

- 直接用 Xcode 建 project。
- 用 Tuist / XcodeGen 產生 project。
- 保持核心邏輯在 Swift Package，App target 只負責 UI、entitlements、extensions。
