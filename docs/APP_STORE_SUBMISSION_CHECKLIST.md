# App Store Submission Checklist

This is the final handoff checklist before uploading a Kairo beta or App Review build. It gathers the release-blocking evidence that must stay aligned across readiness docs, review notes, privacy labels, real-device sign-off, and catalog publication.

## Required Package

- `docs/APP_STORE_READINESS.md` is the status source for beta scope and remaining blockers.
- `docs/APP_REVIEW_NOTES.md` is the submission-ready review note copy.
- `docs/PRIVACY_LABELS_CHECKLIST.md` is the App Store Connect privacy-label handoff.
- `docs/REAL_DEVICE_BETA_SIGNOFF.md` is the only source for physical-device beta sign-off.
- `docs/IOS_TARGET_READINESS.md` tracks signing, target, simulator-build, App Group, purpose-string, and app-bundle evidence boundaries.
- `docs/CATALOG_RELEASE_CHECKLIST.md` is the production gate for standalone skill and model catalogs.
- `docs/TRUST_STORE_RUNBOOK.md` is the rotation/revocation runbook for signed catalog trust stores.

## Blocking Gates

Do not submit until all gates below are true:

- Real-device sign-off has no `Blocked - device unavailable` rows and includes physical-device evidence for Chat, Memory, Access, Settings, Share Extension import, App Intents Ask/Save/Search, chat history restart persistence, notification/reminder/calendar preview + confirm, and email/message/phone/web/maps handoff preview + confirm.
- App Review notes do not claim iOS production local inference, live HomeKit control, arbitrary cross-app UI control, private cross-app reads, ChatGPT browser-session reuse, or silent Apple Shortcut creation.
- Privacy labels match `Kairo/Resources/PrivacyInfo.xcprivacy`: no tracking, no collected data, no tracking domains, and only UserDefaults required-reason API usage with reason `CA92.1`.
- Purpose strings match current beta capabilities: Calendar, Reminders, Notifications, and Contacts only; HomeKit, Location, and Photo Library purpose strings remain absent until those capabilities ship.
- iOS target readiness has signed-build evidence for Apple Developer entitlement resolution, App Group runtime read/write, purpose-string prompt display, and signed bundle contents.
- Local model copy distinguishes catalog/download/select/delete support from iOS production inference runtime, which remains Planned until real-device runtime proof exists.
- Production skill and model catalog readiness is not claimed until standalone signed catalogs and public trust-store metadata are published outside this app repo.
- Focused scans find no secrets, tokens, private keys, generated credentials, model weights, `.gguf`, tokenizer blobs, model packages, or downloaded caches in tracked files.

## Evidence Boundaries

- Simulator UI smoke, package tests, source-health tests, and screenshots from `tmp/` are support evidence only.
- App-side signature verification proves fail-closed validation behavior, not that production catalogs have been published.
- macOS/dev local-model reply checks and benchmark adapters are not iPhone runtime proof.
- Current deletion proof is on-device only; do not add backend account deletion copy unless a backend account exists.
