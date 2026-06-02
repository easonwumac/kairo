# Shortcuts Strategy

Shortcuts / App Intents 可能是 Kairo 的關鍵功能。因為一般 iOS App 不能任意控制其他 App，但 Shortcuts 是 Apple 官方允許使用者把多個 App 行為組合起來的自動化表面。

## 核心定位

Kairo 不應嘗試繞過 iOS sandbox，而是成為 Shortcuts 裡的 AI brain：

- 理解輸入。
- 查詢記憶。
- 摘要內容。
- 抽出任務。
- 產生 drafts。
- 決定下一步建議。
- 把結構化結果交給 Shortcuts 後續動作。

## MVP App Intents

第一批建議：

1. `Ask Kairo`
   - input：question
   - output：answer

2. `Save to Kairo Memory`
   - input：text / URL / note
   - output：memory id / summary

3. `Search Kairo Memory`
   - input：query
   - output：matching memories

4. `Summarize with Kairo`
   - input：text / URL content
   - output：summary

5. `Extract Tasks`
   - input：text
   - output：task list

6. `Create Reminder Draft`
   - input：title / notes / due date
   - output：draft or created reminder after confirmation policy

7. `Create Daily Briefing`
   - input：date / options
   - output：briefing text

## Shortcuts Recipes

### Daily Briefing

```text
At 8:30 AM
→ Ask Kairo: Create Daily Briefing
→ Show Result
→ Optional: Send Notification
```

### Save Any Shared Text

```text
Share Sheet / Shortcut Input
→ Save to Kairo Memory
→ Extract Tasks
→ Show Confirmation
```

### Meeting Prep

```text
Get Upcoming Calendar Events
→ Ask Kairo: Prepare meeting brief using memory
→ Show Result
```

### Screenshot to Tasks

```text
Select Photo
→ Extract Text from Image
→ Extract Tasks with Kairo
→ Create Reminder Drafts
```

## 設計原則

- App Intents 要小而穩定，不要做太多隱藏副作用。
- 能回傳 structured output 就不要只回傳長文字。
- 高風險操作在 Kairo 內仍需 confirmation policy。
- Extension / Intent runtime 有時間限制，長任務交給主 App 或後端。
- Shortcuts 是使用者顯式配置的自動化，因此比背景 daemon 更符合 iOS 生態。

## Implemented node contract

`ShortcutNodeRuntime` is the shared core used by App Intents and tests. It treats each Shortcut action as a small node:

- input: text, optional query, source name, user variables, and result limit.
- output: display text, typed fields, optional memory id, memory matches, extracted task drafts, reminder drafts, and proposed actions.
- transport: App Intents return the encoded `ShortcutNodeOutput` JSON string so downstream Shortcut steps can pass the result into another Kairo node or parse fields with Shortcuts dictionary actions.
- safety: task extraction and reminder creation only produce drafts; they do not write EventKit data unless a later confirmed action does so.

Current nodes:

1. `Ask Kairo` returns an answer payload.
2. `Save to Kairo Memory` stores text in the App Group memory store and returns `memoryID` plus extracted task drafts.
3. `Search Kairo Memory` returns matching memory metadata.
4. `Summarize with Kairo` returns a bounded text summary.
5. `Extract Kairo Tasks` returns task and reminder drafts without executing writes.

## Integration registry alignment

`IntegrationRegistry` keeps Shortcuts/App Intents metadata beside URL-scheme and OAuth connector metadata so the model can distinguish three very different paths:

1. **Shortcuts/App Intents**：使用者明確設定或觸發，自動化步驟由 Shortcuts 執行。
2. **URL schemes / universal links**：只能開啟使用者可見的 handoff，不能隱藏操作或讀取對方 App 資料。
3. **OAuth connectors**：只透過官方 API 與授權 scopes 存取資料；寫入外部帳號仍需 preview + confirmation。

This registry should power UI explanations, prompt context, App Store review notes, and connector setup screens.

## 後續實作方向

- 加入 `Create Daily Briefing` 與 `Create Reminder Draft` App Intents。
- 把 JSON output 升級成 App Intents custom value/entity output when the generated Xcode target can verify it on device.
- 提供一組官方 Shortcut templates。
