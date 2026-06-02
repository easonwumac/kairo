# Kairo PRD

## 產品願景

Kairo 是一個有記憶的手機級 Agent。它不是越獄工具，也不是系統後門；它是一個善用 iOS 公開能力的個人 Agent：使用者授權什麼，它就使用什麼；使用者分享什麼，它就記住什麼；高風險操作一律先預覽再確認。

## 目標使用者

- 每天處理大量資訊的創業者、PM、工程師、顧問、學生。
- 希望手機可以記住上下文、整理資訊、產生待辦和行事曆的人。
- 重視隱私，不希望 AI 默默上傳所有個人資料的人。

## 核心場景

### 1. 分享任何內容給 Kairo

使用者在 Safari、Mail、Files、Photos、Notion、Slack 等 App 中按分享，選擇 Kairo：

- Save to Memory
- Summarize
- Extract Tasks
- Ask About This
- Create Reminder Draft
- Create Calendar Draft

### 2. 查詢記憶

使用者問：

> 上次 Aaron 說的預算是多少？

Kairo 從記憶中搜尋相關資料，回答並附來源。

### 3. 建立行動

使用者說：

> 把這篇文章的行動項目排到下週。

Kairo 產生 reminders/calendar drafts，列出預覽，使用者確認後才寫入。

### 4. 每日 briefing

Kairo 整合使用者授權的 calendar、reminders、近期記憶與分享內容，產生每日摘要。

### 5. 權限中心

使用者可以看到每個 iOS 能力目前是否授權、Kairo 能拿來做什麼、如何撤銷。

## MVP 功能

### 必做

- Chat screen
- Memory Center
- Local encrypted memory store
- Search memory
- Manual add/edit/delete memory
- Share Extension ingestion
- EventKit reminder/calendar draft
- App Intents for common actions
- Notifications
- Permission Hub
- Audit Log
- OpenAI provider abstraction

### 第二階段

- Widget
- Local embeddings
- OAuth connector：Gmail / Google Calendar 或 Microsoft 365
- Cloud sync opt-in
- Better document OCR and PDF parsing
- Shortcuts gallery

### 不做

- 背景監控螢幕
- 任意控制其他 App UI
- 私有 API
- ChatGPT 網頁 session cookie 模擬登入
- 無確認發送訊息/Email/刪除資料

## 成功指標

- 使用者每週新增 ≥ 20 筆記憶。
- 70% 的記憶查詢可找到正確來源。
- 分享到 Kairo 的流程少於 3 步。
- 高風險 action 0 次未確認執行。
- 使用者能清楚理解 Kairo 能做與不能做什麼。
