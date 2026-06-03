# Info.plist Purpose Strings

正式建立 Xcode iOS target 時，請依照實際啟用的 capability 加入 purpose strings。不要一次要求所有權限；採用 just-in-time permission。

## 建議文案

```xml
<key>NSCalendarsUsageDescription</key>
<string>Kairo 需要行事曆權限，才能在你確認後建立或整理行事曆草稿。</string>

<key>NSCalendarsFullAccessUsageDescription</key>
<string>Kairo 需要完整行事曆權限，才能在你確認後透過 EventKit 建立行事曆事件。</string>

<key>NSRemindersUsageDescription</key>
<string>Kairo 需要提醒事項權限，才能在你確認後建立與整理待辦提醒。</string>

<key>NSRemindersFullAccessUsageDescription</key>
<string>Kairo 需要提醒事項完整權限，才能在你確認後透過 EventKit 建立提醒事項。</string>

<key>NSContactsUsageDescription</key>
<string>Kairo 只會在你明確要求並確認後，透過 Contacts.framework 建立聯絡人。</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Kairo 只會處理你選擇的圖片或截圖，用於摘要、OCR、任務抽取與記憶保存。</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Kairo 只會在你要求地點相關協助時使用目前位置。</string>

<key>NSUserNotificationsUsageDescription</key>
<string>Kairo 會用通知提醒你 briefing、待確認動作與重要待辦。</string>

<key>NSHomeKitUsageDescription</key>
<string>Kairo 需要家庭權限，才能在你確認後執行 HomeKit 場景或配件控制。</string>
```

## 原則

- 權限必須和功能直接相關。
- 權限被拒絕時要有 graceful fallback。
- 高敏感權限預設不在 onboarding 一次要求。
- iOS 17+ 的 EventKit full-access requests 需要 `NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription`，舊 key 只作為舊系統 fallback。
- Apple Maps handoff 不需要 Kairo 讀取目前位置；只有未來明確加入定位讀取功能時，才可觸發 Location permission。
- 目前 beta 沒有 HomeKit entitlement；`NSHomeKitUsageDescription` 只能作為未來 live-control path 的文案草稿，不可在 review notes 宣稱真實 HomeKit live control 已完成。
