# Background Tasks Strategy

Kairo 需要善用 iOS 允許的背景能力，但不能宣稱常駐背景 daemon。iOS background execution 是 opportunistic、受系統排程限制，而且 App Review 會檢查用途是否合理。

## 可用背景能力

### BGAppRefreshTask

適合：

- 更新每日 briefing cache。
- 檢查待匯入 Share queue。
- 清理過期 memory / attachment metadata。
- 準備前景開啟時可顯示的輕量 briefing draft；Widget snapshot must stay future-only until a Widget target ships.

限制：

- 不保證準時。
- 執行時間短。
- 需要 expiration handling。

### BGProcessingTask

適合：

- 模型 checksum verification。
- 本機 indexing / embedding rebuild。
- 大文件摘要預處理。
- 清理模型暫存檔。

限制：

- 需要 Info.plist permitted identifiers。
- 可能需要外接電源/網路條件。
- 不能濫用成常駐 agent。

### UserNotifications

適合：

- 提醒使用者回到 App 確認 action。
- Daily/weekly briefing notification。
- 重要待辦提醒。

### URLSession background transfers

適合：

- 下載使用者選擇的本機模型。
- 大檔案同步。

## Kairo 背景任務原則

1. 背景任務只做準備工作，不直接執行高風險 action。
2. 需要使用者確認的 action 只發通知或在下次前景開啟時顯示。
3. 所有任務都要可取消、可重試、可觀測。
4. 不依賴背景任務保證準時。
5. 使用者可以關閉 background refresh / notifications。

## Beta task identifiers

```text
com.kairo.app.refresh
com.kairo.app.processing.local-model
com.kairo.app.processing.connectors
```

These identifiers are mirrored in `Config/KairoApp-Info.plist` under `BGTaskSchedulerPermittedIdentifiers` and in `BackgroundTaskPolicy.defaultTasks`.

## Acceptance criteria

- [x] Background task registry 有明確 task catalog。
- [x] 每個 task 有目的、風險、是否可在背景執行的描述。
- [x] 不支援背景執行的 task 不會被排程。
- [x] Task planning 不會直接執行 tier2/tier3 action；高風險 action 只能走前景 preview + explicit confirmation。
- [x] 文件明確說明 iOS 不保證背景任務準時。

Package/source-health evidence:

- `BackgroundTaskPolicy.defaultTasks` defines the beta catalog and bounded runtime limits.
- `testBackgroundTaskIdentifiersMatchInfoPlist` keeps `BGTaskSchedulerPermittedIdentifiers` aligned with the policy catalog.
- `testBackgroundTaskPolicySchedulesBoundedRefreshAndRejectsDaemonClaims` rejects continuous background daemon requests.
- `testBackgroundTaskPolicyDefersOversizedConnectorWork` defers work that exceeds the task budget.

This is package/source evidence only. Real-device background launch behavior, App Group access, permission prompts, App Intents execution, Share Extension import, and persistence still require physical-device sign-off.
