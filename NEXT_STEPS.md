# Next Steps

## Current direction

Kairo is past the initial scaffold stage. The next work should stabilize the existing beta flow instead of adding more Shortcut nodes, tabs, widgets, or new surfaces.

Primary product shape:

- Chat is the main surface.
- Tools, skills, workflows, memory, models, and settings support Chat.
- Every write, handoff, or sensitive action must be previewed and explicitly confirmed.
- Documentation must say when a feature is implemented, scaffolded, test-only, planned, or not allowed.

## Status labels

| Status | Meaning |
|---|---|
| Implemented | Usable in the app/core path and covered by tests for the stated scope. |
| Scaffolded | Code, UI, models, or protocols exist, but the beta path is not production-complete. |
| Test-only / Mock | Deterministic test/demo path only; do not describe as real runtime capability. |
| Planned | Accepted direction, not implemented yet. |
| Not allowed | Outside App Store-safe public API boundaries for this app. |

## Feature state table

| Area | Status | Beta note |
|---|---|---|
| Chat-first app shell | Implemented | App now launches into Chat; More manages support surfaces. |
| Chat history | Implemented | JSON-backed persistent chat store exists. |
| Memory store | Scaffolded | JSON/in-memory stores exist; delete/export and derived cleanup still need beta hardening. |
| Settings / Access | Implemented | Current settings, model rows, OAuth readiness, and Skill Manager UI exist. |
| Share Extension ingestion queue | Scaffolded | Queue and import path exist; beta still needs stronger import tests and no-heavy-work enforcement. |
| App Intents / Shortcut nodes | Implemented | Many node contracts exist; next work is safety/schema hardening, not more nodes. |
| Kairo Recipes | Implemented | Internal recipes, preview/run, enable/disable, and App Intent bridge exist. These are not Apple Shortcuts. |
| Skill Manager | Scaffolded | File-backed manager and Access UI exist; Chat still needs live effective catalog wiring. |
| Visible URL handoffs | Implemented | Email, Messages, Phone, Web Search, Maps handoffs require preview + confirmation. |
| EventKit / Notifications / Contacts actions | Implemented | Chat actions preview before confirmed writes; Shortcut nodes should remain draft-only unless confirmed by Kairo. |
| HomeKit action model | Scaffolded | Typed action model and demo/test preview exist; real HomeKit entitlement and live home control are not complete. |
| OAuth connector core | Scaffolded | Authorization/callback/status scaffolds exist; real provider API integrations are not complete. |
| Local model catalog/download/select/delete | Implemented | User-triggered model catalog, verified downloader, selected model settings, and delete flow exist. |
| macOS/dev local model reply check | Test-only / Mock | External command adapter is for development validation, not iOS production inference. |
| iOS production local model runtime | Planned | Do not claim local iPhone inference works until a real runtime is wired and tested. |
| Audit log persistence | Scaffolded | Audit models exist; live app should persist metadata-only logs with redaction. |
| Keyboard Extension | Planned | Not built. Do not prioritize before beta stabilization. |
| Widget | Planned | Not built. Do not prioritize before beta stabilization. |
| Real HomeKit entitlement path | Planned | Requires entitlement, permission copy, device testing, and fallback behavior. |
| Real OAuth provider API writes/reads | Planned | Requires provider scopes, token storage, review/security work, and disconnect/delete flow. |
| Arbitrary cross-app UI clicking | Not allowed | No private UI automation, Appium/WebDriverAgent, or hidden tapping as App Store runtime. |
| Background screen watching | Not allowed | No background screenshots or private screen monitoring. |
| Silent Apple Shortcuts editing | Not allowed | Kairo may guide user-installed Shortcuts; it must not silently create or edit them. |
| Reading Messages/Mail/Notes private stores | Not allowed | Use share sheet, handoff, or official provider APIs only. |

## Immediate implementation commits

1. Make Chat use the live Skill Manager effective catalog.
   - Disabled skills must not appear in Chat tool candidates.
   - Enabled skills should appear.
   - Installed marketplace skills should enter the effective catalog.
   - Compatibility-blocked skills should never become executable tools.

2. Harden existing Shortcut node beta contracts.
   - Do not add more nodes first.
   - Confirm tests for Contact, Email, Message, Phone, Web Search, Calendar, Reminder, and Home preview boundaries.
   - Stabilize App Intent JSON output schema.
   - Update `docs/SHORTCUTS_STRATEGY.md` and App Store docs with exact status.

3. Tighten local model beta path.
   - Keep downloads user-triggered.
   - Never commit weights, tokenizer files, GGUF files, caches, credentials, or generated secrets.
   - Keep iOS production inference marked as Planned until real-device runtime evidence exists.

4. Add audit and memory lifecycle hardening.
   - Persist audit metadata by default, not full sensitive payload.
   - Add memory delete/export and cleanup for derived summaries/cache/attachment references.

5. Complete Share Extension beta import path.
   - Shared text, URL, image, and file metadata should appear in main app pending content.
   - Extension must not perform heavy model inference or high-risk actions.

## Verification expectations

For every small stage:

1. Run the relevant tests.
2. Check `git status`.
3. Scan staged diff for secrets/model artifacts.
4. Commit with a clear message.
5. Push the current branch.

Do not report a feature as complete unless the current code and tests prove the exact scope.
