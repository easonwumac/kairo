# Roadmap

Kairo has moved beyond the initial scaffold stage. The roadmap now prioritizes a stable beta flow over adding more surfaces or more Shortcut nodes.

## Status labels

| Status | Meaning |
|---|---|
| Implemented | Usable in the app/core path and covered by tests for the stated scope. |
| Scaffolded | Code, UI, models, or protocols exist, but beta hardening remains. |
| Test-only / Mock | Deterministic test/demo path only; not a real runtime capability. |
| Planned | Accepted direction, not implemented yet. |
| Not allowed | Outside App Store-safe public API boundaries for this app. |

## Current state

| Area | Status | Notes |
|---|---|---|
| App project, app target, share extension target, UI test target | Implemented | Project and targets exist in `project.yml` / `Kairo.xcodeproj`. |
| Chat-first shell | Implemented | Chat is the primary surface; More manages support screens. |
| Memory | Implemented | Save/search/delete/export stores exist; deleted JSON records can be purged from disk. |
| Share Extension ingestion queue | Implemented | Text/URL/image/PDF/file metadata imports into Chat; extension stays queue-only and capped. |
| App Intents / Shortcut nodes | Implemented | Existing beta nodes have `schemaVersion=1` safety contracts; next work is device/App Intent QA. |
| Kairo Recipes | Implemented | Internal workflows with preview/run/enable/disable and App Intent bridge. |
| Skill Manager | Scaffolded | File-backed lifecycle and Access UI exist; Chat uses the live effective catalog for installed, disabled, and compatibility-blocked skill state. |
| URL handoff previews | Implemented | Email, Messages, Phone, Web Search, and Maps use visible handoff + confirmation. |
| EventKit / Notifications / Contacts actions | Implemented | Chat preview + confirmation exists for current action scope. |
| HomeKit | Scaffolded | Typed action model, demo UI, and tests exist; real entitlement/live home path is planned. |
| OAuth connectors | Scaffolded | Auth/callback/status scaffolds exist; real provider APIs are planned. |
| Local model catalog/download/select/delete | Scaffolded | User-triggered catalog/download/settings path exists with package-tested progress/cancel/delete/checksum/trust-store behavior, but production signed catalog publication and real-device iOS runtime proof remain release blockers. |
| macOS/dev local model runtime adapter | Test-only / Mock | External command validation path only. |
| iOS production local model inference | Planned | Requires real runtime, device proof, memory/thermal gating, and App Store packaging. |
| Keyboard Extension | Planned | Deferred. |
| Widget | Planned | Deferred. |
| Cross-app UI clicking, background screen watching, private app data reads | Not allowed | Not part of Kairo's App Store-safe scope. |

## Phase 1: Beta stabilization

Do first:

1. **Documentation state alignment**
   - Keep README, NEXT_STEPS, capability matrix, App Store readiness, local model docs, and Shortcut strategy aligned with implementation state.
   - Every user-facing claim must map to Implemented, Scaffolded, Test-only / Mock, Planned, or Not allowed.

2. **Chat uses live Skill Manager state**
   - Chat and `AgentCore` plan from the effective installed skill catalog, not only `AgentSkillCatalog.default`.
   - Disabled skills disappear from Chat tool candidates.
   - Installed marketplace skills appear in the effective catalog.
   - Compatibility-blocked skills stay preview-only and never become executable tools.

3. **Shortcut node hardening**
   - Do not add more nodes first.
   - Lock down current safety boundaries: Contacts draft/write, Email draft, Message handoff, Phone handoff, Web Search handoff, Calendar/Reminder drafts, and Home preview.
   - Keep App Intent JSON output stable for downstream Shortcuts parsing.

4. **Local model beta path**
   - Keep downloads user-triggered.
   - Show model size, license, purpose, delete state, storage/backup policy, progress/cancel, and runtime availability honestly.
   - Keep skill and model release keys `publicationStatus=pendingPublication` until standalone catalogs and public trust metadata are published.
   - Keep macOS/dev reply checks separate from iOS production inference.

5. **Audit and memory lifecycle**
   - File-backed metadata-only audit logging is in the beta path.
   - Memory Center can export/delete active records; JSON store can purge deleted records.

6. **Share Extension beta import**
   - Main app imports text, URL, image, PDF, and file metadata shared into Kairo.
   - Extension does not run model inference or high-risk actions; it only queues up to 8 attachments per request.

## Phase 2: Production readiness

- Privacy labels and App Store review notes.
- Real-device smoke checks for Chat, Memory, Access, Settings, Share Extension, App Intents Ask/Save/Search, chat history restart persistence, permission-denied fallbacks, and confirmed notification/reminder/calendar/email/message/phone/web/maps actions.
- Keychain/token deletion and provider disconnect flows.
- Background task expiration handling and user-visible scheduling boundaries.
- Data export/delete flows.
- Production signed skill and model catalog publication from standalone repositories, with public trust metadata published outside this app repo.

## Phase 3: Integrations after beta safety

Add only after beta stabilization:

- One real OAuth provider API path, such as Google Calendar/Gmail or Microsoft 365.
- Real HomeKit entitlement path with explicit permission copy and fallback UI.
- Published production skill catalog key material after `pendingPublication` keys are promoted with matching standalone catalog publication.
- Published production model catalog with device gating, rollout metadata, and real-device iPhone runtime proof.

## Deferred work

Do not prioritize until the beta flow above is stable:

- More Shortcut nodes.
- Keyboard Extension.
- Widget.
- CarPlay / car mode.
- Multiple OAuth connectors.
- Additional app surfaces.

## Always out of scope

- Private API use.
- Jailbreak-only features.
- Arbitrary cross-app UI clicking.
- Background screen watching.
- Reading Messages, Apple Mail, Notes, Safari history/cookies, or ChatGPT web sessions.
- Silent Apple Shortcuts creation or editing.
