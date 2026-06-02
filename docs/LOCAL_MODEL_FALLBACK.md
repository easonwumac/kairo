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

第一階段不把模型權重塞進 app 或 repo。Kairo core 已具備 Qwen3.5 0.8B Q4_K_M 的遠端下載 manifest entry、install registry、selected-model settings、provider routing、verified downloader、live Settings downloader wiring，以及 Settings 內的本機模型 catalog/status UI；下一步是 signed production catalog、progress/cancel UI、實機 runtime proof of concept。

## Download pipeline

`VerifiedLocalModelDownloader` handles the safe install path:

- downloads from the manifest URL through an injected `HTTPClient`;
- rejects unsupported manifests and non-2xx HTTP responses;
- verifies SHA-256 before moving the file into `KairoPaths.localModelsDirectory`;
- writes `downloading`, `installed`, or `failed` records to `FileBackedLocalModelInstallRegistry`;
- removes partial files when checksum verification fails.

The downloader is intentionally UI-agnostic. Settings now exposes model rows with download/select/delete affordances and route preference control, but a production build still needs a real signed catalog, configured downloader, progress/cancellation handling, license text, and stronger size disclosure.

The default development catalog points to `Qwen3.5 0.8B Q4_K_M` through Hugging Face:

- model source: `Qwen/Qwen3.5-0.8B`;
- downloadable GGUF: `AaryanK/Qwen3.5-0.8B-GGUF`, file `Qwen3.5-0.8B.q4_k_m.gguf`;
- expected file size: about 527.5 MB;
- SHA-256 is stored in the manifest and verified after download.

Kairo must keep this as an explicit user-triggered download. Do not commit model weights, tokenizer blobs, downloaded `.gguf` files, or cached model artifacts into this repository.

## Benchmark notes

Development-machine benchmark on June 2, 2026, using Apple M5 Pro:

- `llama.cpp` / GGUF `Qwen3.5-0.8B.q4_k_m.gguf`, Metal, 512 prompt tokens, 128 generated tokens, 5 trials: about 8,810 prompt tok/s and 214 generation tok/s.
- `llama.cpp` / GGUF with `-ngl 0`, 3 trials: about 433 prompt tok/s and 123 generation tok/s.
- `mlx-lm` / `mlx-community/Qwen3.5-0.8B-OptiQ-4bit`, 512 prompt tokens, 128 generated tokens, 5 trials: about 10,639 prompt tok/s, 286 generation tok/s, and 1.36 GB peak memory.

MLX is the stronger Apple Silicon benchmark path for macOS/dev validation. iPhone production support still needs a separate runtime decision and real-device proof for latency, memory, thermal behavior, and App Store-compatible packaging. Do not treat these Mac numbers as iPhone performance.

## Model catalog backend

Kairo should eventually move model availability into a standalone GitHub repository, for example `kairo-models`, used like a static backend:

- publish signed model catalog JSON and per-model manifests;
- list runtime-specific artifacts, such as GGUF for llama.cpp-compatible runtimes and MLX artifacts for Apple Silicon validation;
- include download URLs, SHA-256, file size, license, minimum OS, minimum RAM/device tier, context window, safety policy version, and deprecation status;
- never host committed model weights in the app repo;
- support catalog versioning, key rotation, revocation, and rollback;
- let Kairo fetch the catalog visibly and install only after user approval.

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
