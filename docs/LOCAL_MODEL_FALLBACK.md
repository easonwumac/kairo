# Local Model Fallback

Kairo 的模型策略不是只依賴雲端。手機端可以放一個超輕量 fallback model，用於離線、隱私敏感、網路失敗或雲端額度不足時的基本能力。

## 目標

本機 fallback 不追求取代雲端大模型，而是負責：

- 離線時的簡短回答。
- 敏感資料分類。
- prompt / memory redaction。
- query rewrite。
- 短摘要。
- action risk pre-check。
- 判斷是否需要雲端模型。
- 簡單 intent routing。

## 候選模型

可以研究：

- Qwen 3 / Qwen 3.5 0.6B～0.8B 等級模型。
- Phi / Gemma / SmolLM 等小模型。
- Apple Foundation Models（若部署目標與 API 條件允許）。
- Core ML 轉換後的小型 LLM 或 classifier。

## iOS 部署考量

- App size：模型權重不能讓 App 過大，必要時使用 on-demand download。
- Memory：低 RAM 裝置要避免 OOM。
- Battery / thermal：長時間推理會耗電與發熱。
- Latency：本機小模型適合短任務，不適合長推理。
- Quantization：優先 4-bit / 8-bit 量化。
- Privacy：本機推理可處理高敏感內容，避免上雲。

## Provider 設計

Kairo 應使用 provider chain：

```text
User Request
    │
    ▼
Safety / Sensitivity Check
    │
    ├── 高敏感 / 離線 / 雲端不可用 ──► LocalFallbackProvider
    │
    └── 可上雲 / 需要高品質 ───────► OpenAIProvider
```

建議 protocol：

```swift
protocol AIProvider {
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse
}
```

後續新增：

- `LocalFallbackProvider`
- `ProviderRouter`
- `SensitivityClassifier`
- `CloudEligibilityPolicy`

## MVP 策略

第一階段保留 mock/local placeholder，不急著塞模型權重。Kairo core 已具備 catalog、install registry、selected-model settings、provider routing、verified downloader scaffold，以及 Settings 內的本機模型 catalog/status UI；下一步是接上 signed production catalog、真實 downloader 設定與實機 runtime proof of concept。

## Download pipeline

`VerifiedLocalModelDownloader` handles the safe install path:

- downloads from the manifest URL through an injected `HTTPClient`;
- rejects unsupported manifests and non-2xx HTTP responses;
- verifies SHA-256 before moving the file into `KairoPaths.localModelsDirectory`;
- writes `downloading`, `installed`, or `failed` records to `FileBackedLocalModelInstallRegistry`;
- removes partial files when checksum verification fails.

The downloader is intentionally UI-agnostic. Settings now exposes model rows with download/select/delete affordances and route preference control, but a production build still needs a real signed catalog, configured downloader, progress/cancellation handling, license text, and stronger size disclosure.

## Model selection

`LocalModelSettingsService` owns the selected local model and route preference:

- persists `selectedModelID` and `ProviderRoutePreference` in `KairoPaths.localModelSettingsURL`;
- refuses to select deprecated, old-safety-policy, or uninstalled models;
- deletes installed model files, registry records, and selected-model state when the user removes a model;
- returns a `LocalModelSettingsStatus` snapshot used by Settings / model-library UI rows;
- exposes route preferences for Automatic, Prefer Local, Prefer Cloud, and Local Only modes;
- builds a `ProviderRoutingContext` so chat can route privacy/offline eligible prompts to the selected installed model.

建議順序：

1. 先做 `LocalFallbackProvider` protocol shell。
2. 用 rule-based fallback 模擬本機模型能力。
3. 用 verified downloader 安裝使用者明確選擇的模型。
4. 讓使用者指定已安裝模型與 route preference。
5. 選定 Core ML / llama.cpp / MLX Swift 等 runtime。
6. 測 Qwen 0.6B～0.8B quantized 在 iPhone 上的速度與 RAM。
7. 只把 fallback 用於短任務，不拿來做長規劃。
