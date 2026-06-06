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
