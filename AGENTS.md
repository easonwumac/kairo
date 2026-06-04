# Kairo Agent Notes

## Personal defaults

- Keep answers short and action-oriented.
- Prefer practical automation when safety allows.
- When changing code, run available tests or lints.
- Never run destructive commands without explicit confirmation.
- After each completed development stage, commit and push.
- Before every commit/push, scan for secrets and avoid committing tokens, API keys, credentials, model weights, or generated build artifacts.
- Do not add tests that only assert user-facing copy, docs, readiness checklists, source files, or localization text contains specific strings.
- Do not add source-health or snapshot-style tests that read Swift/docs/localization files just to prove naming, file placement, line count, or exact wording.
- If a behavior matters, test the behavior through state, data model, permission, confirmation, risk-tier, persistence, API, UI smoke flow, or accessibility identifiers instead of matching prose.

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
