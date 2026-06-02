# Shortcuts Strategy

Shortcuts / App Intents 可能是 Kairo 的關鍵功能。因為一般 iOS App 不能任意控制其他 App，但 Shortcuts 是 Apple 官方允許使用者把多個 App 行為組合起來的自動化表面。

## 核心定位

Kairo 不應嘗試繞過 iOS sandbox，而是成為 Shortcuts 裡的 AI brain：

- 理解輸入。
- 查詢記憶。
- 摘要內容。
- 抽出任務。
- 產生 drafts。
- 產生 reply drafts。
- 決定下一步建議。
- 把結構化結果交給 Shortcuts 後續動作。

Kairo Recipes 是另一層：它們是 Kairo app 內部 workflows，可以由 Kairo 儲存、preview、run、enable/disable。Apple Shortcuts 可以透過 App Intents 呼叫 Kairo Recipes，但 Kairo 不會 silent create/edit/install Apple Shortcuts。

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

8. `Run Kairo Recipe`
   - input：recipe id, optional text
   - output：encoded `KairoRecipeRunResult`
   - boundary：Tier 2+ recipes return a preview that requires confirmation in the Kairo app

9. `Suggest Kairo Recipe`
   - input：natural-language automation request
   - output：disabled Kairo recipe draft for review
   - boundary：does not create Apple Shortcuts

10. `List Kairo Recipes`
    - output：enabled Kairo recipe ids/titles for user-created Shortcuts

11. `Run Kairo Daily Briefing`
    - input：optional text
    - output：encoded `KairoRecipeRunResult`
    - boundary：seeds the Kairo internal recipe if missing, not an Apple Shortcut

## Shortcuts Recipes

`ShortcutDemoCatalog.default` is the code-backed source of truth for official demo recipes. Each recipe contains:

- trigger summary;
- ordered Kairo node steps;
- input/output contract fields;
- sample `ShortcutNodeInput` JSON for imported Shortcut examples or future UI previews.

`SettingsView` surfaces these recipes under `Shortcut Demos` so users can inspect the trigger, node path, input fields, output fields, and sample input before building or installing the Shortcut.

`ShortcutDemoRecipeRunner` can execute a demo recipe's sample steps against `ShortcutNodeRuntime` for tests and future previews. When a step marks `variables.kairoInputSource = previousStepOutput`, the runner chains structured output into the next node by preferring `fields.chainText`, then task/reminder drafts, then `displayText`. This keeps UI summaries separate from machine-readable node input.

### Daily Briefing

```text
At 8:30 AM
→ Create Daily Briefing with Kairo
→ Show Result
→ Optional: Send Notification
```

Node contract:

- node: `dailyBriefing`
- input: `text`
- output: `displayText`, `fields.briefing`, `fields.taskCount`, optional task drafts

### Save Any Shared Text

```text
Share Sheet / Shortcut Input
→ Save to Kairo Memory
→ Extract Tasks
→ Show Confirmation
```

Node contract:

- nodes: `saveMemory` → `extractTasks`
- input: shared text / URL content from the user
- output: `memoryID`, `fields.taskCount`, task drafts, reminder drafts

### Screenshot to Tasks

```text
Select Photo
→ Extract Text from Image
→ Extract Tasks with Kairo
→ Create Reminder Drafts
```

Node contract:

- nodes: `extractTasks` → `createReminderDraft`
- input: OCR text from a user-selected screenshot
- output: `fields.taskCount`, `fields.reminderDraftCount`, reminder drafts that still require confirmation before any write

### Reply Draft from Shared Text

```text
Share Sheet / Shortcut Input
→ Summarize with Kairo
→ Draft Reply with Kairo
→ Review Manually
```

Node contract:

- nodes: `summarize` → `draftReply`
- input: email, message, or support text explicitly selected by the user
- output: `fields.replyDraft`, `fields.replyDraftTone`, and display text; no send action is executed automatically

### Meeting Prep Brief

```text
Manual Shortcut / meeting title
→ Search Kairo Memory
→ Summarize with Kairo
→ Extract Prep Tasks
```

Node contract:

- nodes: `searchMemory` → `summarize` → `extractTasks`
- input: meeting title, customer name, memory query, or pasted notes
- output: memory match count, prep summary, task drafts, and reminder drafts; no EventKit write occurs without a later confirmed action

## 設計原則

- App Intents 要小而穩定，不要做太多隱藏副作用。
- 能回傳 structured output 就不要只回傳長文字。
- 高風險操作在 Kairo 內仍需 confirmation policy。
- Extension / Intent runtime 有時間限制，長任務交給主 App 或後端。
- Shortcuts 是使用者顯式配置的自動化，因此比背景 daemon 更符合 iOS 生態。

## Implemented node contract

`ShortcutNodeRuntime` is the shared core used by App Intents and tests. It treats each Shortcut action as a small node:

- input: text, optional query, source name, user variables, and result limit.
- output: display text, typed fields, optional chain text for downstream nodes, optional memory id, memory matches, extracted task drafts, reminder drafts, and proposed actions.
- transport: App Intents return the encoded `ShortcutNodeOutput` JSON string so downstream Shortcut steps can pass the result into another Kairo node or parse fields with Shortcuts dictionary actions.
- safety: task extraction and reminder creation only produce drafts; they do not write EventKit data unless a later confirmed action does so.

`Run Kairo Shortcut Node` is the generic node bridge for advanced Shortcuts. The user supplies a supported `ShortcutNodeKind` raw value and encoded `ShortcutNodeInput` JSON, and Kairo returns encoded `ShortcutNodeOutput` JSON. This makes Kairo usable as a Shortcuts node graph component without giving Kairo permission to silently create, edit, or execute Apple Shortcuts.

Internal Kairo Recipes use `KairoRecipeRunner` instead of `ShortcutNodeRuntime`. They are exposed to Shortcuts through `Run Kairo Recipe`, `Suggest Kairo Recipe`, `List Kairo Recipes`, and `Run Kairo Daily Briefing`, but the source of truth remains Kairo's recipe store rather than the user's Apple Shortcuts collection.

Current nodes:

1. `Ask Kairo` returns an answer payload.
2. `Save to Kairo Memory` stores text in the App Group memory store and returns `memoryID` plus extracted task drafts.
3. `Search Kairo Memory` returns matching memory metadata.
4. `Summarize with Kairo` returns a bounded text summary.
5. `Extract Kairo Tasks` returns task and reminder drafts without executing writes.
6. `Create Reminder Draft` returns reminder drafts without EventKit writes.
7. `Draft Reply` returns reply draft text without sending email, chat, or SMS.
8. `Create Daily Briefing` returns briefing text and suggested task drafts.
9. `Run Kairo Shortcut Node` runs a supported node kind from JSON input and returns structured JSON output.
10. `Run Kairo Recipe` runs an enabled internal recipe by id and returns structured JSON output.
11. `Suggest Kairo Recipe` saves a disabled recipe draft for Kairo Automations review.
12. `List Kairo Recipes` lists enabled recipe ids/titles.
13. `Run Kairo Daily Briefing` seeds and runs the internal Daily Briefing recipe.

Implemented App Intent types:

1. `AskKairoIntent`
2. `SaveToKairoMemoryIntent`
3. `SearchKairoMemoryIntent`
4. `SummarizeWithKairoIntent`
5. `ExtractKairoTasksIntent`
6. `CreateDailyBriefingIntent`
7. `CreateReminderDraftsIntent`
8. `RunKairoShortcutNodeIntent`
9. `RunKairoRecipeIntent`
10. `SuggestKairoRecipeIntent`
11. `ListKairoRecipesIntent`
12. `RunKairoDailyBriefingIntent`

## Shortcut Template Registry

`ShortcutTemplateRegistry.default` ships user-installed template metadata for Daily Briefing, Meeting Prep, Share Text to Kairo, Screenshot to Tasks, Action Button Ask Kairo, and generic Run Kairo Recipe. Templates store required App Intent identifiers, recommended internal recipe ids, and manual setup instructions.

Template metadata is not a one-tap install mechanism. The Automations tab states that Kairo creates internal recipes and Apple Shortcuts installation requires user approval.

## User-visible Shortcut handoff

`ShortcutHandoffService` builds `shortcuts://run-shortcut` URLs for workflows the user has created or installed. Kairo encodes `ShortcutNodeInput` as the `text` input and adds two variables:

- `kairoHandoffRequestID`: stable request id for matching a return payload.
- `kairoCallbackURL`: `kairo://shortcuts/callback?requestID=...`, which a Shortcut can open after it has produced a `ShortcutNodeOutput` JSON string.

This is not silent automation. The handoff opens Shortcuts through visible URL handling, and Kairo only parses a callback when the Shortcut explicitly opens the callback URL with an `output` query item. `SandboxActionExecutor` only allows the `shortcuts://run-shortcut` host for Shortcuts handoffs; other custom URL schemes remain blocked unless added as a separately reviewed integration.

## Integration registry alignment

`IntegrationRegistry` keeps Shortcuts/App Intents metadata beside URL-scheme and OAuth connector metadata so the model can distinguish three very different paths:

1. **Shortcuts/App Intents**：使用者明確設定或觸發，自動化步驟由 Shortcuts 執行。
2. **URL schemes / universal links**：只能開啟使用者可見的 handoff，不能隱藏操作或讀取對方 App 資料。
3. **OAuth connectors**：只透過官方 API 與授權 scopes 存取資料；寫入外部帳號仍需 preview + confirmation。

This registry should power UI explanations, prompt context, App Store review notes, and connector setup screens.

## 後續實作方向

- 把 JSON output 升級成 App Intents custom value/entity output when the generated Xcode target can verify it on device.
- 將 `ShortcutDemoCatalog` 接到 Settings / onboarding UI，並輸出可匯入的 Shortcuts 範例。
