# Privacy Labels Checklist

This checklist is the App Store Connect privacy-label handoff for the current Kairo beta. It must stay aligned with `Kairo/Resources/PrivacyInfo.xcprivacy`, `Config/KairoApp-Info.plist`, and the review-note boundary in `docs/APP_REVIEW_NOTES.md`.

## Current Beta Label Answers

For the current beta binary:

- Tracking: No.
- Data collected: No collected data.
- Tracking domains: None.
- Required Reason API usage: UserDefaults only, reason `CA92.1`.

These answers are valid only while Kairo has no analytics SDK, no ad tracking, no backend account, no cloud memory sync, no crash/telemetry collection provider, and no provider-side sync beyond explicit user-configured API calls.

## Purpose String Alignment

Enabled beta purpose strings:

- `NSCalendarsUsageDescription`
- `NSCalendarsFullAccessUsageDescription`
- `NSRemindersUsageDescription`
- `NSRemindersFullAccessUsageDescription`
- `NSUserNotificationsUsageDescription`
- `NSContactsUsageDescription`

Future-only purpose strings must remain absent from the beta plist until the corresponding capability ships:

- `NSHomeKitUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`

## Review Before Submission

- Verify `Kairo/Resources/PrivacyInfo.xcprivacy` still has `NSPrivacyTracking=false`.
- Verify `NSPrivacyTrackingDomains` is empty.
- Verify `NSPrivacyCollectedDataTypes` is empty.
- Verify `NSPrivacyAccessedAPITypes` contains only UserDefaults with reason `CA92.1`.
- Verify `docs/APP_REVIEW_NOTES.md` does not claim backend account deletion or cloud-sync deletion unless a backend account exists.
- Verify `docs/REAL_DEVICE_BETA_SIGNOFF.md` remains the source for physical-device evidence; privacy labels do not prove runtime behavior.

## Deletion Evidence Boundary

Current deletion proof is on-device and user-triggered only:

- Chat history: delete a thread from Chat history; `ChatViewModel.deleteThread` calls `JSONFileChatHistoryStore.purgeDeletedThreads` to remove deleted file-backed threads from disk, while restart persistence still needs real-device sign-off.
- Memory records: Memory Center delete/export covers active records, and `JSONFileMemoryStore.purgeDeleted` removes deleted JSON records from disk.
- Local models: Settings / Models delete removes installed model files and clears selected-model state; no model weights are bundled or committed.
- API keys and OAuth tokens: Settings delete/disconnect removes Keychain-backed secrets; malformed token handling requires reauthorization instead of silently treating stale credentials as connected.
- Audit logs: Settings / Privacy exposes Clear Audit Log for metadata-only audit records; audit deletion must not be described as deleting chat history, memories, API keys, OAuth tokens, or downloaded models.
- Backend account deletion: not applicable in the current beta because Kairo has no backend account, server-side audit log, remotely stored chat history, or cloud memory sync.

## Change Triggers

Update App Privacy Labels, review notes, and this checklist before submission if any of these are added:

- Analytics, telemetry, crash reporting, advertising, or tracking SDKs.
- Backend accounts, cloud sync, cloud memory, server-side audit logs, or remotely stored chat history.
- Provider-side data sync beyond explicit user-configured API calls.
- Photo library, location, HomeKit entitlement, or additional sensitive permission access.
- Any data collection not represented in the current privacy manifest.
