# Kairo PRD

## 產品願景

Kairo 是手機上的個人資訊資產管理系統。

使用者把截圖、連結、文件、文字、票券、訂單、行程、聊天片段或筆記丟進 Kairo。Kairo 幫使用者保存原始資料、抽取重點、建立資料頁、補上待辦與提醒，並讓之後可以用 Chat 找回資料。

Kairo 的價值不是控制手機，而是把使用者散落在手機上的資訊變成可搜尋、可理解、可追蹤、可行動的個人知識庫。

## 目標使用者

- 常截圖保存資訊，但之後找不到的人。
- 旅行、專案、訂單、保固、醫療、財務、證件等資料散落在多個 App 的人。
- 希望 AI 幫忙整理資訊，但不希望資料被默默執行外部動作的人。
- 希望本地模型成為長期方向，但也接受雲端或 OCR 作為輔助的人。

## 核心物件

### Asset

使用者匯入的原始資料。

- 類型：text、url、image、pdf、file、manual note。
- 欄位：source、createdAt、file reference、extracted text、tags、sensitivity、linkedInfoPageIDs。
- 原始 asset reference 不可丟失。

### InfoPage

Kairo 整理後的資料頁。

- 類型：travel、order、warranty、medical、project、finance、identity document、home device、subscription、general note。
- 欄位：title、category、summary、timeline、facts、assets、reminders、actionDrafts。
- 第一個專屬 UI 先做 Travel。

### Space / Collection

多個 Asset 和 InfoPage 的集合，例如「香港旅行」、「Kairo 專案」、「家中設備」、「個人證件」。

### ReminderLink

從 InfoPage 建立或建議的提醒事項。

- 優先用 `kairo://info-page/{id}` 回到 Kairo。
- 若 Reminder URL 欄位不可用，寫入 notes fallback。
- 寫入前必須 preview + explicit confirmation。

## MVP Flows

### Flow A：匯入資產

- Share Extension / 主 App 可匯入 text、URL、截圖/image、PDF/file metadata。
- 匯入後先進入 Chat review，由 Kairo 分析內容並檢索相似 assets / folders / InfoPages。
- Kairo 依檢索結果建議建立新 asset、合併到既有資料頁、或不儲存。
- 除非 Settings 啟用低風險自動建立，否則建立或合併前要詢問使用者。
- 使用者可在 Library 看到完整資產列表、搜尋、篩選、刪除。
- 不做高風險 action。
- 不假裝圖片 OCR 已完成。

### Flow B：資產整理成 InfoPage

- 使用者可選多個 assets，建立或加入 InfoPage。
- Kairo 產生 title、category、summary、facts、timeline、suggested reminders、linked assets。
- Travel InfoPage MVP 要能呈現 flights、hotel/pickup/booking、timeline、reminders、original assets。
- UI 用固定 template，模型只填 structured data。

### Flow C：InfoPage 到 Reminder / Action

- Kairo 從 InfoPage 建議 Reminder drafts。
- 寫入 Reminders 前必須 preview + explicit confirmation。
- Reminder 能連回 InfoPage。
- Email、Message、Phone、Maps、Web 只能產生 draft 或 visible handoff。

## 模型方向

- 本地 LLM 是長期重點，但 MVP 應先讓資料流可用。
- 0.8B 級 text model 只能當 fallback text extractor。
- 截圖理解需要 OCR、vision-capable model，或 OCR + 2B/4B 級 text model。
- Gemma-class 2B/4B 或相近模型應列入 screenshot description、structured JSON、InfoPage generation 評估。
- 不新增 benchmark UI/API；只保留能證明 asset understanding 可用的測試。

## 必做

- Asset model/store/backend API。
- Library search / filter / detail。
- Share Extension import 到 Chat review，並產生 create / merge / skip asset proposal。
- InfoPage model/store/generator。
- Travel InfoPage UI。
- InfoPage -> Reminder preview + confirm。
- Chat 搜尋或引用 assets / InfoPages。
- iCloud backup opt-in。

## 暫停或退場

- Recipes / sample flows。
- Skill marketplace / managed tools。
- App Integration Harness 擴張。
- 新 Shortcut node。
- Keyboard / Widget / CarPlay。
- HomeKit live control。
- local model backend / benchmark 平台化。
- 大型 generic refactor。

## 成功指標

- 使用者每週匯入至少 20 筆 assets。
- 使用者能在 10 秒內找到曾經匯入的截圖或資料。
- Travel InfoPage 能從多筆旅行資料整理出 timeline 和 missing checklist。
- 任何提醒、行程或外部動作 0 次未確認執行。
