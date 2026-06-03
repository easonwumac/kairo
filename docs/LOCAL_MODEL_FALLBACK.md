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

第一階段不把模型權重塞進 app 或 repo。Kairo core 已具備多個 2B 參數以下公開 GGUF 模型的遠端下載 manifest entries、install registry、selected-model settings、provider routing、verified downloader、live Settings downloader wiring、模型 catalog/status UI、benchmark metadata，以及 local reply-check runtime abstraction；下一步是 signed production catalog、progress/cancel UI、實機 runtime proof of concept。

## Download pipeline

`VerifiedLocalModelDownloader` handles the safe install path:

- downloads from the manifest URL through an injected `HTTPClient`;
- rejects unsupported manifests and non-2xx HTTP responses;
- verifies SHA-256 before moving the file into `KairoPaths.localModelsDirectory`;
- writes `downloading`, `installed`, or `failed` records to `FileBackedLocalModelInstallRegistry`;
- removes partial files when checksum verification fails.

The downloader is intentionally UI-agnostic. Settings now exposes model rows with download/select/delete affordances, route preference control, visible catalog source text, and a Refresh Catalog action. A production build still needs a real signed catalog, stronger signature verification, progress/cancellation handling, license text, and stronger size disclosure.

The default development catalog starts with 4 popular public GGUF downloads through Hugging Face. It is intentionally compact for the first Models UI pass; the standalone `kairo-models` catalog can add more entries later without bundling weights into the app:

- `Qwen3.5 0.8B Q4_K_M`: `AaryanK/Qwen3.5-0.8B-GGUF`, file `Qwen3.5-0.8B.q4_k_m.gguf`, about 527.5 MB.
- `Llama 3.2 1B Instruct Q4_K_M`: `bartowski/Llama-3.2-1B-Instruct-GGUF`, file `Llama-3.2-1B-Instruct-Q4_K_M.gguf`, about 807.7 MB.
- `DeepSeek R1 Distill Qwen 1.5B Q4_K_M`: `QuantFactory/DeepSeek-R1-Distill-Qwen-1.5B-GGUF`, file `DeepSeek-R1-Distill-Qwen-1.5B.Q4_K_M.gguf`, about 1.12 GB.
- `SmolLM2 1.7B Instruct Q4_K_M`: `bartowski/SmolLM2-1.7B-Instruct-GGUF`, file `SmolLM2-1.7B-Instruct-Q4_K_M.gguf`, about 1.06 GB.

SHA-256 and file size are stored in each manifest and verified after download. Models with noncommercial, custom, or gated license terms, should keep license text visible and should gain a production license-approval gate in the standalone `kairo-models` catalog before broad rollout.

Kairo must keep this as an explicit user-triggered download. Do not commit model weights, tokenizer blobs, downloaded `.gguf` files, or cached model artifacts into this repository.

## Benchmark notes

Development-machine benchmark on June 2, 2026, using Apple M5 Pro:

- `llama.cpp` / GGUF `Qwen3.5-0.8B.q4_k_m.gguf`, Metal, 512 prompt tokens, 128 generated tokens, 5 trials: about 8,810 prompt tok/s and 214 generation tok/s.
- `llama.cpp` / GGUF with `-ngl 0`, 3 trials: about 433 prompt tok/s and 123 generation tok/s.
- `mlx-lm` / `mlx-community/Qwen3.5-0.8B-OptiQ-4bit`, 512 prompt tokens, 128 generated tokens, 5 trials: about 10,639 prompt tok/s, 286 generation tok/s, and 1.36 GB peak memory.
- June 3, 2026 spot check with `mlx_lm.generate --ignore-chat-template`, prompt `Kairo local model is running.`, 16 generated tokens: about 107.8 prompt tok/s, 307.5 generation tok/s, 0.694 GB peak memory, and visible local output `Kairo local model is running.`.

MLX is the stronger Apple Silicon benchmark path for macOS/dev validation. iPhone production support still needs a separate runtime decision and real-device proof for latency, memory, thermal behavior, and App Store-compatible packaging. Do not treat these Mac numbers as iPhone performance.

`LocalModelManifest.benchmarkProfiles` now records the GGUF Metal and MLX reference profiles for `Qwen3.5 0.8B Q4_K_M`. Settings shows the best reference summary as `MLX ref 286 gen tok/s ... iPhone not verified`, while the row still downloads only the GGUF artifact through the explicit user-approved model downloader. The MLX artifact is tracked as benchmark metadata for Apple Silicon validation, not as an in-app iPhone download target in this pass.

## Reply check

`LocalModelReplyCheckService` verifies the local-model execution path separately from benchmark metadata:

- it refuses to run until the target model has an installed registry record;
- it calls an injected `LocalModelReplyCheckRuntime` and requires non-empty response text;
- Settings exposes a visible `Run Reply Check` button for each model row;
- UI tests seed only a deterministic install record and deterministic runtime response, never model weights;
- live builds use an unavailable runtime placeholder until an App Store-compatible iPhone inference runtime is wired.

This lets Kairo test the reply-check plumbing without bundling Qwen, while still making the missing production runtime explicit.

## Model catalog backend

Kairo now includes `LocalModelCatalogService.defaultStandaloneRepository`, which fetches `https://easonwumac.github.io/kairo-models/models.json` and treats it like a static backend. This repository also contains `Website/models` as the reference seed that can be mirrored to the standalone `kairo-models` repository.

The model catalog backend should:

- publish signed model catalog JSON and per-model manifests;
- list runtime-specific artifacts, such as GGUF for llama.cpp-compatible runtimes and MLX artifacts for Apple Silicon validation;
- include download URLs, SHA-256, file size, license, minimum OS, minimum RAM/device tier, context window, safety policy version, benchmark profiles, and deprecation status;
- never host committed model weights in the app repo;
- support catalog versioning, key rotation, revocation, and rollback;
- let Kairo fetch the catalog visibly and install only after user approval.

Current service behavior:

- decodes `LocalModelCatalog` JSON with `sourceRepository` metadata;
- rejects remote catalog entries whose model download URL is not HTTPS;
- rejects entries missing a 64-character SHA-256 checksum;
- merges remote entries over matching built-in model IDs while preserving built-in fallback models that the remote catalog omits;
- decodes missing `benchmarkProfiles` as an empty list so older remote catalogs remain compatible;
- syncs refreshed catalog metadata into `LocalModelSettingsService` so Settings can still select models from the refreshed catalog.

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
