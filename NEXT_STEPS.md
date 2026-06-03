# Next Steps

Kairo is in beta stabilization / App Review preparation. Do not add new Shortcut nodes, tabs, Keyboard, Widget, CarPlay, or extra OAuth providers before these release blockers are closed.

## Release-blocking gaps

1. Real-device beta sign-off.
   - Current `devicectl` check on 2026-06-04 listed the available test devices as `unavailable`, so no real-device sign-off was completed in this pass.
   - Re-run on a reachable physical iPhone or iPad: Chat / Memory / Access / Settings, Share Extension import, App Intents Ask / Save / Search, chat history restart persistence, local notification / reminder / calendar preview + confirm, and email / message / phone / web / maps handoff preview + confirm.
   - Write device results back to `docs/APP_STORE_READINESS.md`; do not substitute simulator or package tests for real-device evidence.

2. Permission-denied and App Review final QA.
   - Run real-device fallback checks for denied Calendar / Reminders / Notifications / Contacts permissions.
   - Access permission status/request handling now has backend API coverage; keep device permission-denied fallback sign-off as real-device-only evidence.
   - Memory lifecycle/export, Kairo-owned internal recipe lifecycle/run, Share Extension queue import, metadata-only audit log deletion, and Settings credential/OAuth management now have backend API coverage; keep future deletion copy limited to on-device data unless a backend account exists.
   - Privacy manifest no-collection/no-tracking, absence of HomeKit entitlement, and review-note boundary copy are now package-tested; recheck labels only if analytics, backend accounts, cloud sync, crash collection, or connector sync is added.
   - Keep HomeKit live control out of beta claims until entitlement, permission copy, fallback UI, confirmation behavior, and real-device evidence are complete.
   - Keep review notes from claiming iOS production local inference, real HomeKit live control, arbitrary cross-app reads/UI control, ChatGPT web-session reuse, or silent Apple Shortcuts creation.

3. Local model release hardening.
   - Keep downloads explicitly user-triggered and continue blocking model weights, `.gguf`, tokenizer blobs, caches, and generated artifacts from the repo.
   - Publish the production signed catalog and real release public-key material; app-side catalog payload signature verification now fails closed for unknown, revoked, out-of-window, unsupported, or invalid keys, and `docs/TRUST_STORE_RUNBOOK.md` now defines the rotation/revocation release gate.
   - Settings now shows foreground download progress/cancel, cleans stale interrupted download state on status reload, requires an explicit license-approval preview before download confirmation, and local model management now has a backend API facade for status/select/preference/delete/stale cleanup.
   - Keep iOS production inference runtime marked `Planned` until there is real-device runtime proof.

4. Skill Manager / marketplace production hardening.
   - Publish production marketplace trust-store key material; `docs/TRUST_STORE_RUNBOOK.md` now defines rotation/revocation metadata and the release gate, and app-side trust keys carry active/revoked metadata and validity windows.
   - User-created skill drafts now require explicit capability selection and confirmation policy; keep this invariant covered.
   - Skill Manager lifecycle now has a backend API facade for catalog/effective catalog/preview/install/disable/enable/remove/user drafts, including fail-closed behavior when the service is unavailable.
   - Kairo-owned internal recipe lifecycle/run/sample seeding now has a backend API facade; keep the boundary clear that these are internal recipes and do not silently create Apple Shortcuts.
   - Signed skill update and user-created remove flows now have simulator UI smoke coverage; keep these invariants covered without treating them as real-device sign-off.
   - Preserve the invariant that compatibility-blocked skills never become executable tools.

5. Release hygiene before each commit and submission.
   - Run relevant tests, plus `swift test` before release handoff.
   - Run `xcodegen generate` when `xcodegen` is available.
   - Run a focused scan for secrets, tokens, credentials, model weights, tokenizer files, `.gguf`, caches, and generated build artifacts.
   - Commit and push each completed, tested small stage.
