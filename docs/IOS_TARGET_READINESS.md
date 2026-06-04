# iOS Target Readiness

This repo is source-first. `project.yml` describes an XcodeGen path for creating an iOS app target and Share Extension target while keeping core logic testable through Swift Package Manager.

## Targets

- `KairoApp`: main SwiftUI app.
- `KairoShareExtension`: receives user-shared content and writes pending ingestion items.
- `KairoCoreTests`: unit tests for core logic.
- `KairoUITests`: XCUITest smoke coverage for launch, chat send, chat HomeKit action preview, chat Shortcut tool candidate preview, settings, HomeKit preview, and Skill Manager refresh/install/disable/enable flows.

## Required Apple Developer setup

1. Create bundle IDs:
   - `app.kairo.ios`
   - `app.kairo.ios.share`
2. Create App Group:
   - `group.app.kairo.shared`
3. Enable App Group on both app and extension bundle IDs.
4. If BackgroundTasks are implemented in the app target, keep permitted identifiers aligned with `BGTaskSchedulerPermittedIdentifiers` in `Config/KairoApp-Info.plist`.
5. Do not enable high-sensitivity entitlements such as HealthKit, HomeKit, Network Extension, FamilyControls, or critical alerts until the product has a real App Review-eligible use case.

## Shared container strategy

Production targets should initialize `KairoPaths` using the App Group container when available:

```swift
let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.kairo.shared")
```

Use the shared container for:

- `share-ingestion-queue.json`
- copied shared files from the Share Extension
- lightweight metadata needed by App Intents / widgets

Avoid putting large local model files in the App Group unless the extension truly needs them. Model weights should usually remain in the main app container.

## Share Extension rules

- Only receive content the user explicitly shares.
- Copy temporary provider files into the App Group before returning.
- Never execute agent actions inside the extension.
- Enqueue `ShareIngestionItem` and let the main app show review/confirmation UI.
- Keep extension UI and processing short.

## Background task identifiers

`Config/KairoApp-Info.plist` contains:

- `com.kairo.app.refresh`
- `com.kairo.app.processing.local-model`
- `com.kairo.app.processing.connectors`

These match `BackgroundTaskPolicy.defaultTasks`.

## Release evidence boundary

Current device availability was checked with `xcrun devicectl list devices` on 2026-06-04, and all listed physical devices were `unavailable`. Until a signed build runs on a reachable physical iPhone or iPad, the checks below remain release-blocking and must not be replaced by simulator build output, package tests, source-health tests, or screenshots from `tmp/`.

Real-device install/launch evidence must prove the full sequence separately: signed `xcodebuild` for `id=<device-id>`, built `.app` exists in derived data, `xcrun devicectl device install app` succeeds, `xcrun devicectl device info apps --device <device-id>` lists `app.kairo.ios`, and `xcrun devicectl device process launch --device <device-id> app.kairo.ios` succeeds. A successful build or simulator run is not enough.

Physical-device or Apple Developer evidence is still required for:

- entitlement resolution against the Apple Developer team;
- App Group container read/write between `KairoApp`, `KairoShareExtension`, and App Intents;
- purpose-string prompt display on device;
- verification that the signed app bundle does not include generated user data, credentials, model weights, tokenizer blobs, or downloaded caches;
- Share Extension import and persistence across app relaunch.

## Verification before TestFlight

- [x] Generate/open Xcode project.
  - Verified 2026-06-04 with `xcodebuild -list -project Kairo.xcodeproj`.
- [ ] Confirm entitlements resolve against the Apple Developer team.
  - Blocked: requires Apple Developer team signing evidence for the submitted bundle IDs and App Group.
- [x] Build `KairoApp` on simulator.
  - Verified 2026-06-04 with `xcodebuild -project Kairo.xcodeproj -scheme KairoApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- [x] Build `KairoShareExtension` on simulator.
  - Verified 2026-06-04 with `xcodebuild -project Kairo.xcodeproj -scheme KairoShareExtension -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/kairo-share-extension-derived-data CODE_SIGNING_ALLOWED=NO build`.
- [x] Run `KairoUITests` smoke flow on simulator.
  - Verified 2026-06-04 on `iPhone 17` simulator with `xcodebuild -project Kairo.xcodeproj -scheme KairoApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KairoUITests/KairoAppSmokeUITests/testLaunchDrawerChatAndSettingsSmokeFlow test`.
- [ ] Verify App Group container read/write.
  - Blocked: requires signed physical-device runtime evidence; simulator/package tests do not prove App Group behavior on device.
- [ ] Verify purpose strings display correctly.
  - Blocked: requires physical-device permission prompts for Calendar, Reminders, Notifications, and Contacts.
- [x] Verify BackgroundTasks identifiers match Info.plist.
  - Verified 2026-06-04 by `SourceHealthTests.testBackgroundTaskIdentifiersMatchInfoPlist`, matching `BGTaskSchedulerPermittedIdentifiers` to `BackgroundTaskPolicy.defaultTasks`.
- [ ] Verify no generated user data or secrets are included in the app bundle.
  - Blocked: requires inspection of the signed app bundle/archive before TestFlight or App Review upload.

These checks are simulator build evidence only. They are not real-device beta sign-off evidence and do not validate App Group runtime access, permission prompts, App Intents execution, Share Extension import, or persistence on a physical iPhone.
