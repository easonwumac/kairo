Implementation Plan

> REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

- [ ] **Goal:** 以可測、可提交的小步驟完成 Kairo beta smoke 驗證、local model hardening、provider credential safety hardening，並同步更新 App Store readiness 文件。
- [ ] **Architecture:** 先以現有 `swift test`、`xcodegen generate`、單元測試與 UI smoke 測試入口確認 beta flow 現況，再用最小修改補齊缺口。所有文件狀態必須和實作一致；未完成的 production 能力保留為 scaffolded、planned、unavailable。
- [ ] **Tech Stack:** Swift 5.9、iOS 17.0、Swift Package Manager、XcodeGen、XCTest、SwiftUI。

- [ ] **Files:**
- [ ] Modify: `NEXT_STEPS.md`
- [ ] Modify: `docs/APP_STORE_READINESS.md`
- [ ] Modify: `Tests/...`（依實際缺口補測試）
- [ ] Modify: `Kairo/...`（僅在測試證明缺口後補最小實作）
- [ ] Create: `docs/superpowers/plans/2026-06-03-beta-hardening.md`

- [ ] **Step 1: 建立 beta smoke 基線**
- [ ] Run: `swift test`
- [ ] Run: `xcodegen generate`（僅在環境有 `xcodegen` 時）
- [ ] Inspect: 盤點 Chat、Memory、Share Extension、App Intents、Recipe、Skill Manager、preview/confirm 路徑對應的測試與文件。

- [ ] **Step 2: 補 beta smoke 缺口的 failing test**
- [ ] Write: 針對缺少或與文件不一致的 smoke path 補最小 failing test。
- [ ] Run: 僅跑新增或修改的測試，確認先失敗且失敗原因正確。

- [ ] **Step 3: 補最小實作並驗證**
- [ ] Write: 只補讓 Step 2 通過所需的最小 production code 或文件修正。
- [ ] Run: 重新執行相關測試直到通過。
- [ ] Update: `docs/APP_STORE_READINESS.md`、`NEXT_STEPS.md` 反映真實結果與剩餘風險。

- [ ] **Step 4: commit beta smoke 階段**
- [ ] Run: `git status`
- [ ] Inspect: diff 內不得含 secrets、model artifacts、weights、GGUF、tokenizer、cache、build artifacts。
- [ ] Commit: 一個只包含 beta smoke / readiness 更新的 commit。
- [ ] Push: 推到目前 branch。

- [ ] **Step 5: local model hardening**
- [ ] Write failing tests: checksum failure、cancel、delete selected model、runtime unavailable、progress/state machine。
- [ ] Run failing tests: 確認為真缺口。
- [ ] Write minimal code: 維持使用者手動下載、不落地 model artifacts 到 repo、runtime unavailable 誠實顯示。
- [ ] Update docs: 補 signed catalog / trust metadata 設計與 beta 限制。
- [ ] Run: 相關測試與 `swift test`。

- [ ] **Step 6: commit local model 階段**
- [ ] Run: `git status`
- [ ] Inspect: diff 無 secrets / model artifacts。
- [ ] Commit: 一個只包含 local model hardening 的 commit。
- [ ] Push: 推到目前 branch。

- [ ] **Step 7: provider credential safety**
- [ ] Write failing tests: OpenAI API key save/test-or-dry-run/delete、Keychain only、logout/delete token、local-only mode 不呼叫 cloud、missing key fallback/error。
- [ ] Run failing tests: 確認為真缺口。
- [ ] Write minimal code: 只補安全需求與錯誤路徑，不新增 web login 或 cookie/session 行為。
- [ ] Run: 相關測試與 `swift test`。
- [ ] Update docs: 對齊 privacy / review notes / deletion 說明。

- [ ] **Step 8: commit provider 階段**
- [ ] Run: `git status`
- [ ] Inspect: diff 無 secrets / model artifacts。
- [ ] Commit: 一個只包含 provider credential safety 的 commit。
- [ ] Push: 推到目前 branch。

- [ ] **Step 9: 最終驗證**
- [ ] Run: `swift test`
- [ ] Run: 需要時補跑特定 smoke 或 UI 測試命令。
- [ ] Confirm: 文件、測試、實作狀態一致。
