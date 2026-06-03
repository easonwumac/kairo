# App Review Notes

Kairo is a chat-first iOS app that uses only public APIs, App Intents, Share Extension, BGTaskScheduler, official OAuth/API flows, and visible URL handoffs.

Shared content enters Kairo only through Share Extension, document/photo pickers, App Intents/Shortcuts, or official OAuth APIs. Kairo does not read other apps' private containers, control arbitrary app UI, or bypass iOS permissions.

On-device deletion is user-triggered for chat history, memory JSON/export content, downloaded local models, saved API keys, OAuth tokens, and metadata-only audit logs. If a future Kairo backend account is added, backend account-deletion copy must be reviewed separately before release.

For the current beta, App Privacy Labels should remain no tracking and no collected data. The submitted binary has no analytics SDK, no backend account, no cloud memory sync, and no crash/telemetry collection provider. If any of those are added later, the privacy labels and this review copy must be updated before submission.

Background tasks are bounded refresh/index/verify/cleanup jobs only. Kairo is not a daemon, does not watch the screen, and background work can be disabled by the user through iOS settings.

Any write or external action is previewed and requires explicit confirmation according to the app safety policy.

Local model catalog/download/select/delete are present, but iOS production local inference is not complete. macOS/dev reply checks and benchmark numbers are not iPhone runtime proof.

HomeKit is limited to preview/demo/test scaffolding in this beta. Live HomeKit control requires a future entitlement, permission, provider, and real-device review pass.

Kairo does not create, edit, install, or reorder Apple Shortcuts silently. Users must configure Apple Shortcuts themselves; Kairo only exposes App Intents, internal Kairo recipes, and visible handoff metadata.
