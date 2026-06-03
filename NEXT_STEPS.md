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
| Memory store | Implemented | JSON/in-memory stores support save/search/delete/export; deleted JSON records can be purged from disk. |
| Settings / Access | Implemented | Current settings, model rows, OAuth readiness, and Skill Manager UI exist. |
| Share Extension ingestion queue | Implemented | Text/URL/image/PDF/file metadata imports into Chat; extension is queue-only and caps each request. |
| App Intents / Shortcut nodes | Implemented | Existing beta nodes have `schemaVersion=1` safety contracts; next work is device/App Intent QA, not more nodes. |
| Kairo Recipes | Implemented | Internal recipes, preview/run, enable/disable, and App Intent bridge exist. These are not Apple Shortcuts. |
| Skill Manager | Scaffolded | File-backed manager and Access UI exist; Chat now uses the live effective catalog for installed, disabled, and compatibility-blocked skill state. |
| Visible URL handoffs | Implemented | Email, Messages, Phone, Web Search, Maps handoffs require preview + confirmation. |
| EventKit / Notifications / Contacts actions | Implemented | Chat actions preview before confirmed writes; Shortcut nodes should remain draft-only unless confirmed by Kairo. |
| HomeKit action model | Scaffolded | Typed action model and demo/test preview exist; real HomeKit entitlement and live home control are not complete. |
| OAuth connector core | Scaffolded | Authorization/callback/status scaffolds exist; real provider API integrations are not complete. |
| Local model catalog/download/select/delete | Scaffolded | User-triggered catalog/download/select/delete flows exist; catalog unknown/revoked signing keys now fail closed in tests; download progress/cancellation/checksum/delete/runtime-unavailable paths are package-tested; richer progress UI, cryptographic catalog signature verification, and real-device iOS runtime proof are still missing. |
| macOS/dev local model reply check | Test-only / Mock | External command adapter is for development validation, not iOS production inference. |
| iOS production local model runtime | Planned | Do not claim local iPhone inference works until a real runtime is wired and tested. |
| Audit log persistence | Implemented | Live app persists file-backed metadata-only audit events. |
| Keyboard Extension | Planned | Not built. Do not prioritize before beta stabilization. |
| Widget | Planned | Not built. Do not prioritize before beta stabilization. |
| Real HomeKit entitlement path | Planned | Requires entitlement, permission copy, device testing, and fallback behavior. |
| Real OAuth provider API writes/reads | Planned | Requires provider scopes, token storage, review/security work, and disconnect/delete flow. |
| Arbitrary cross-app UI clicking | Not allowed | No private UI automation, Appium/WebDriverAgent, or hidden tapping as App Store runtime. |
| Background screen watching | Not allowed | No background screenshots or private screen monitoring. |
| Silent Apple Shortcuts editing | Not allowed | Kairo may guide user-installed Shortcuts; it must not silently create or edit them. |
| Reading Messages/Mail/Notes private stores | Not allowed | Use share sheet, handoff, or official provider APIs only. |

## Completed stabilization commits

- Chat uses the live Skill Manager effective catalog.
  - Disabled skills do not appear in Chat tool candidates.
  - Enabled and installed marketplace skills can appear.
  - Compatibility-blocked installed skills do not become executable tools.
- Shortcut node safety schema is versioned with `schemaVersion=1`.
  - Contact, Email, Message, Phone, Web Search, Calendar, Reminder, Notification, and Home preview boundaries are covered by tests.
  - `docs/SHORTCUTS_STRATEGY.md` and App Store docs describe the beta safety contract.

## Immediate implementation commits

1. Tighten local model beta path.
   - Keep downloads user-triggered.
   - Size, license, purpose, storage, backup policy, delete state, and runtime-unavailable copy are covered in the beta Settings path.
   - Catalog trust metadata now rejects unknown/revoked signing keys before accepting remote rows.
   - Remaining gaps: richer progress/cancel UI polish, cryptographic catalog signature verification, and real-device iOS runtime proof.
   - Never commit weights, tokenizer files, GGUF files, caches, credentials, or generated secrets.
   - Keep iOS production inference marked as Planned until real-device runtime evidence exists.

2. Run device and App Review verification.
  - 2026-06-03 baseline completed: `swift test`, `xcodegen generate`, and 18 focused simulator smoke tests covering Chat launch, local model catalog/download preview, Shortcut/App Intent demo surfaces, Recipe preview/run, Skill Manager compatibility/search, OAuth readiness, and 9 preview+confirm action paths all passed.
  - Memory save/search/delete/export, Share Extension import, App Intent registry/type coverage plus Save/Search node runtime, live Skill Manager effective catalog, local model signing-key/checksum/cancel/delete/runtime-unavailable paths, OpenAI API key save/dry-run/delete, OAuth connector malformed-token reauth + token disconnect/delete, and Local Only fail-closed no-cloud routing are currently covered by package tests.
  - Remaining sign-off gaps: real-device Chat / Memory / Access / Settings / Share Extension / App Intents smoke.
  - Keep App Intent/Shortcut device QA focused on existing beta nodes.

3. Finish remaining privacy review notes.
   - On-device deletion flow is now documented; backend account deletion remains backend-dependent and must stay out of shipped copy unless a backend account exists.
   - App Review copy still needs final real-device verification language before submission.

## Verification expectations

For every small stage:

1. Run the relevant tests.
2. Check `git status`.
3. Scan staged diff for secrets/model artifacts.
4. Commit with a clear message.
5. Push the current branch.

Do not report a feature as complete unless the current code and tests prove the exact scope.
