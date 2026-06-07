# Kairo Agent Notes

## Personal defaults

- Keep answers short and action-oriented.
- Prefer practical automation when safety allows.
- When changing code, run available tests or lints.
- Never run destructive commands without explicit confirmation.
- After each completed development stage, commit and push.
- Before every commit/push, scan for secrets and avoid committing tokens, API keys, credentials, model weights, or generated build artifacts.
- Avoid low-value descriptive UI copy. Prefer concise labels and actionable controls; only show explanatory text when it changes what the user can do or prevents a real mistake.
- Do not add tests that only assert user-facing copy, docs, readiness checklists, source files, or localization text contains specific strings.
- Do not add source-health or snapshot-style tests that read Swift/docs/localization files just to prove naming, file placement, line count, or exact wording.
- If a behavior matters, test the behavior through state, data model, permission, confirmation, risk-tier, persistence, API, UI smoke flow, or accessibility identifiers instead of matching prose.

## Local model simulator workflow

- When testing local model inference on Simulator, do not use a plain XcodeBuildMCP `build_run_sim` or a plain `xcodebuild` app install. Use `scripts/run_simulator_with_llama_runtime.sh`, or pass equivalent `FRAMEWORK_SEARCH_PATHS`, `OTHER_SWIFT_FLAGS -F ...`, and `OTHER_LDFLAGS -framework llama` settings.
- Before claiming a simulator build includes local inference, verify the built app binary links `llama.framework/llama` with `otool -L`. A copied `Frameworks/llama.framework` inside the app bundle is not enough proof because Swift may still compile with `#if canImport(llama)` disabled.
- If local inference fails with "installed app build did not load the local inference runtime", reinstall with the llama runtime script instead of changing model settings or falling back to mock responses.

## Product/UI defaults

- Current product direction: Kairo is a personal information asset manager and Action Inbox. The main loop is Capture assets -> Understand content -> Prepare InfoPages/reminders/actions with preview and confirmation.
- Primary user surfaces should be Library, Asset Inbox, Asset List, InfoPage List, InfoPage Detail, Chat as an understanding/search entry, Model Settings, Permissions, and Settings.
- Deprioritize Recipes, Skill Manager, phone-tool catalogs, marketplace, HomeKit demos, and integration harness surfaces unless they directly support asset capture, asset understanding, InfoPage generation, or confirmed reminder/action previews.
- Do not expand local model/backend/benchmark platform work unless it directly enables asset understanding on simulator/device.
- Do not surface scaffolded, preview-only, planned, beta-only, or unimplemented capabilities in the primary user UI. If a capability cannot actually work for users, hide it from the main flow instead of explaining why it cannot work.
- Do not use defensive or legalistic product copy in the app UI, such as repeated "Kairo does not..." text, "beta" caveats, implementation boundaries, or App Review-style disclaimers. Keep those boundaries in internal docs, review notes, or prompts when needed.
- Avoid developer/internal terms in user-facing UI: `handoff`, `tool candidate`, `schema`, `node`, `recipe id`, `scaffold`, `runtime proof`, `source of truth`, and similar implementation language.
- Avoid ambiguous status badges such as "Core", "Available", or "Needs permission" when they do not tell the user what action to take. Prefer direct controls like Allow, Ask Every Time, Deny, Connect, Download, Open, Delete, or Edit.
- If iOS already provides the permission prompt, the app UI should only decide whether Kairo may suggest/use that capability: Allow, Ask Every Time when useful, or Deny. Do not duplicate iOS permission explanations unless there is a concrete recovery action.
- Do not add UI copy just to explain missing functionality. If the function is not useful or not implemented, remove the entry from the user-facing surface.

## Related repositories

- `easonwumac/kairo`: main Swift/SwiftUI iOS app and `KairoCore` repository. This repo owns the app scaffold, App Store-safe capability boundaries, UI, tests, docs, `project.yml`, and package code.
- `easonwumac/kairo-skills`: standalone skill update repository. Use this for downloadable skill catalogs, signed skill manifests, GitHub Pages marketplace data, skill changelogs, permissions, checksums, and compatibility gates. Do not put model weights here.
- `easonwumac/kairo-models` (planned): standalone model catalog/backend-style repository. Use this for signed model lists and per-model manifests that Kairo can fetch to discover downloadable models. It should include model IDs, runtime type, download URLs, SHA-256, file size, license, minimum OS/device/RAM, context window, safety policy version, deprecation status, and rollout metadata. Do not commit model weights, tokenizer blobs, secrets, or access tokens.

## Repo boundary reminders

- Kairo creates and runs internal Kairo-owned workflows and managed skills; it must not silently create or edit Apple Shortcuts.
- Skills are tool/action capability packages. Models are inference assets. Keep skill catalogs and model catalogs separate.
- Qwen and other local models must be user-triggered downloads, not bundled app assets.
- Prefer public iOS APIs, explicit user permission, App Intents, Share/Keyboard extensions, official OAuth/API connectors, and visible handoff.
- Do not claim or implement private cross-app control, arbitrary UI clicking, background screen watching, private API use, jailbreak behavior, ChatGPT web-session scraping, or silent Shortcut modification.

## OpenAI Compatible cloud provider

- `OpenAICompatibleProvider` (`Kairo/Services/OpenAICompatibleProvider.swift`) — generic OpenAI-compatible chat/completions provider.
- Supports multi-image Vision API: images up to 6 per request, resized to max 1024px, JPEG 0.8 compression, base64 data URLs.
- Settings UI: `SettingsOpenAICompatibleSection.swift` — endpoint, API key, model (with `/v1/models` fetch → push model picker page).
- Settings service: `OpenAICompatibleSettingsService.swift` — CRUD via UserDefaults keys `omlx_endpoint`, `omlx_api_key`, `omlx_model`, `omlx_display_name`.
- Launch config: `--ui-testing-omlx-endpoint=http://localhost:8000/v1 --ui-testing-omlx-api-key=365114 --ui-testing-omlx-model=gemma-4-e2b-it-4bit`.
- Credential keys in `CredentialStore.swift`: `.openAICompatibleAPIKey`, `.openAICompatibleEndpoint`, `.openAICompatibleModel`, `.openAICompatibleDisplayName`.
- Routing: `KairoApp` → `KairoUITestingEnvironmentComposer` → `KairoUITestingLocalModelFactory` → `LocalModelRoutingAIProvider(cloudProvider: OpenAICompatibleProvider)`.
- Chat model switcher: `ChatViewModel.refreshProviderRouteStatus()` checks OMLX UserDefaults and reports as configured cloud option.
- API key passed directly (not via async credential store) to avoid race condition on first request.

### JSON response parsing & InfoPage auto-save

- Provider parses response JSON into `InfoPageDraft` (from `AssetUnderstandingPipeline.swift`), extracts `assetDescription`/`summary` for display.
- `sanitizeDraftJSON()` maps invalid category names (`"general"` → `"generalNote"`, `"photo"` → `"generalNote"`, etc.) to valid enum values.
- Strips non-UUID `sourceAssetID` strings to avoid decode failures.
- Retry loop: up to 5 attempts when JSON parse fails and images are attached. Repair prompt includes exact schema.
- `AICompletionResponse.infoPageDraft` forwarded through `AgentCore.respond()` → `ChatViewModel.send()` → `saveInfoPageDraft()` → `InfoPageStore.save()`.
- Auto-saved InfoPage triggers `Notification.Name.infoPageSaved` → `InfoPageListView` reloads via `.onReceive`.
- Store: `InMemoryInfoPageStore` shared via static cache in `KairoEnvironment.sharedInfoPageStore`. Both ChatViewModel and InfoPageListView use same instance.
- InfoPage list shows saved pages; HTML renderer (`InfoPageHTMLRenderer.render()`) available for web-style view.

### Raw JSON slide panel

- Long-press assistant message bubble → full-screen page slides from right (ZStack + `.transition(.move(edge: .trailing))`).
- Uses root chrome back button pattern: `RootChromePreferenceKey` sets leading action to `.back`, title to "Raw JSON".
- `ChatView` now accepts `rootChromeBackRequestID` + `usesRootChromeNavigation` bindings for chrome integration.
- `InfoPageJSONView` parses JSON into structured sections: Title, Category/Confidence pills, Keywords (FlowLayout capsule tags), Categories, Facts, raw JSON at bottom.
- `.textSelection(.enabled)` removed from chat Text to avoid system copy/share menu conflict with long-press gesture.

## UI patterns & conventions

- **Back navigation**: Use `RootChromePreferenceKey` + `rootChromeBackRequestID` binding (not content back buttons). Set `leadingAction: .back` when a sub-page is active.
- **Push transitions**: `.transition(.move(edge: .trailing).combined(with: .opacity))` for page slides.
- **Chat image attachments**: Multi-select `PhotosPicker` with `maxSelectionCount: 6`. `AttachmentTray` shows all pending images (max width 220pt, truncated filenames).
- **Composer fallback**: `composedMessageText` no longer inserts "Review attachments" placeholder; image-only messages have empty text.

## Performance notes

- First inference on oMLX (MLX-native server) includes model compilation overhead (~90-110s for Gemma 4 E2B 4bit). Subsequent inferences ~5s.
- oMLX benchmarks: prefill 1965 tok/s, generation 44.7 tok/s, peak memory 4.37GB.
- Model is MLX format (from mlx-community), NOT GGUF. Served by oMLX.app (`/Applications/oMLX.app`).
- `MarkItDown` in model list is oMLX built-in file-to-markdown converter (not a real LLM), controlled by `integrations.markitdown_expose_model` setting.
- `LlamaCppLocalModelRuntime.swift` logs inference metrics to `tmp/KairoUITesting/llama-runtime.log`.
- OMLX cloud provider logs to `tmp/KairoUITesting/omlx-cloud.log`.

## Known issues

- **Category parsing**: Model sometimes outputs invalid `InfoPageCategory` values. `sanitizeDraftJSON()` handles many aliases but new edge cases may appear.
- **InfoPageStore**: Uses `InMemoryInfoPageStore` (volatile). Migration to `JSONFileInfoPageStore` requires async init workaround. Files on disk: `info-pages.json` in `KnowledgeAssets/`.
- **Images in InfoPages**: Saved InfoPages don't include the original image files. Asset IDs from classification output are stripped (non-UUID format). Image persistence to InfoPage assets needs implementation.
- **Simulator Metal GPU**: Broken for llama.cpp (`MTLSimDriver` incompatible). Cloud OMLX is the only viable dev workflow for model inference on simulator.
- **Local model GGUF files**: Cached at `~/.cache/kairo-models/` (Gemma 4 E2B Q4_0, Qwen 0.5B/1.5B/VL 3B). llama-server runs on port 8086 for local model path (separate from oMLX on port 8000).

