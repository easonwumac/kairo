# Safety and Privacy

Kairo 的核心風險是「記憶 + 行動」。所以安全設計必須是一等公民。

## 原則

1. 使用者控制記憶。
2. 使用者控制權限。
3. 高風險操作先預覽再確認。
4. 最小化資料收集。
5. 雲端處理必須明確告知與可關閉。
6. 所有 action 留 audit trail。
7. 刪除要刪乾淨：DB、blob、embedding、cache、derived summaries。

## Action Risk Tier

### Tier 0：只讀 / 建議

- 搜尋記憶
- 摘要
- 解釋
- 建議下一步

可直接執行。

### Tier 1：草稿

- Email draft
- Message draft
- Calendar draft
- Reminder draft

只產生草稿，不直接發送。

### Tier 2：低風險寫入

- 儲存記憶
- 建立簡單 reminder
- 建立私人 note

可允許使用者設定自動執行，但仍需 audit log。

### Tier 3：高風險操作

- 發送訊息
- 發送 Email
- 刪除資料
- 分享位置
- 修改大量行事曆
- HomeKit 場景或配件控制
- 對外部 API 做不可逆操作
- 支付、購買、訂閱

必須 preview + explicit confirmation；可選 Face ID/passcode gate。

## Memory Privacy

每筆記憶包含：

- source
- sensitivity
- cloudSyncAllowed
- userEditable
- expiresAt
- deletedAt
- derivedFrom

## Audit Log

每個 action 記錄：

- 使用時間
- action type
- 使用哪些 memory IDs
- 使用哪些 permission
- 是否呼叫雲端模型
- 使用者是否確認
- 結果

Audit log 不應保存完整敏感 payload，除非使用者明確允許。

## Tool Preview Boundary

Kairo may map user requests to installed skills or OAuth connector metadata before a model response is shown, but this is only a preview layer. Disabled skills are ignored, local/no-tool routing returns no tool candidates, Shortcut/OAuth matches remain visible handoffs, and action-backed skills still pass through `SafetyPolicyEngine` before any proposed action appears in chat. Chat stores `toolCandidates` separately from `proposedActions`; candidates are inspection/setup hints, not evidence that Kairo ran a Shortcut or touched an external account.

## Reminder and Notification Boundaries

Kairo may propose a local notification action when the user explicitly asks to be notified or alerted. Scheduling uses only Apple's public `UserNotifications` API, requires runtime notification authorization, and must be shown as an action preview in chat before the user confirms. Kairo must not silently schedule notifications from hidden model output, background monitoring, or unapproved Shortcut installation.

Kairo may propose an EventKit reminder action when the user explicitly asks to create a reminder, todo, or reminder item. Reminder writes use only EventKit Reminders, require runtime reminder authorization, and must be shown as an action preview before confirmation. Shortcut nodes and Kairo Recipes can prepare reminder drafts, but they must not write EventKit reminders unless a later confirmed action performs the write.

## Kairo Recipe Boundary

Kairo Recipes are internal Kairo workflows. They can be created, stored, previewed, enabled, disabled, and run by Kairo, but they are not Apple Shortcuts workflows. Kairo must not silently create, edit, install, or reorder Apple Shortcuts.

Recipe runner behavior follows the same risk tiers: read-only and draft steps can produce summaries or drafts, while Tier 2 and Tier 3 writes require preview and explicit confirmation before any write step is allowed. Draft steps such as reminder, calendar, notification, and HomeKit proposals remain visible drafts until a user-approved execution path exists.
