# Privacy Labels Checklist

This checklist is the App Store Connect privacy-label handoff for the current Kairo beta. It must stay aligned with `Kairo/Resources/PrivacyInfo.xcprivacy`, `Config/KairoApp-Info.plist`, and the review-note boundary in `docs/APP_REVIEW_NOTES.md`.

## Current Beta Label Answers

For the current beta binary:

- Tracking: No.
- Data collected: No collected data.
- Tracking domains: None.
- Required Reason API usage: UserDefaults only, reason `CA92.1`.

These answers are valid only while Kairo has no analytics SDK, no ad tracking, no backend account, no cloud memory sync, no crash/telemetry collection provider, and no provider-side sync beyond user-configured API calls.

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

## Change Triggers

Update App Privacy Labels, review notes, and this checklist before submission if any of these are added:

- Analytics, telemetry, crash reporting, advertising, or tracking SDKs.
- Backend accounts, cloud sync, cloud memory, server-side audit logs, or remotely stored chat history.
- Provider-side data sync beyond explicit user-configured API calls.
- Photo library, location, HomeKit entitlement, or additional sensitive permission access.
- Any data collection not represented in the current privacy manifest.
