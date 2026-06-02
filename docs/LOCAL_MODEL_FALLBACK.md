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

第一階段保留 mock/local placeholder，不急著塞模型權重。Kairo core 已具備 catalog、install registry、provider routing，以及 verified downloader scaffold；下一步是接上使用者可見的下載 UI 與實機 runtime proof of concept。

## Download pipeline

`VerifiedLocalModelDownloader` handles the safe install path:

- downloads from the manifest URL through an injected `HTTPClient`;
- rejects unsupported manifests and non-2xx HTTP responses;
- verifies SHA-256 before moving the file into `KairoPaths.localModelsDirectory`;
- writes `downloading`, `installed`, or `failed` records to `FileBackedLocalModelInstallRegistry`;
- removes partial files when checksum verification fails.

The downloader is intentionally UI-agnostic so the app can later expose a model download screen with progress, cancellation, license text, size disclosure, and delete controls.

建議順序：

1. 先做 `LocalFallbackProvider` protocol shell。
2. 用 rule-based fallback 模擬本機模型能力。
3. 用 verified downloader 安裝使用者明確選擇的模型。
4. 選定 Core ML / llama.cpp / MLX Swift 等 runtime。
5. 測 Qwen 0.6B～0.8B quantized 在 iPhone 上的速度與 RAM。
6. 只把 fallback 用於短任務，不拿來做長規劃。
