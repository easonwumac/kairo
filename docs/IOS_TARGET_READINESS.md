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

## Verification before TestFlight

- [x] Generate/open Xcode project.
  - Verified 2026-06-04 with `xcodebuild -list -project Kairo.xcodeproj`.
- [ ] Confirm entitlements resolve against the Apple Developer team.
- [x] Build `KairoApp` on simulator.
  - Verified 2026-06-04 with `xcodebuild -project Kairo.xcodeproj -scheme KairoApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- [x] Build `KairoShareExtension` on simulator.
  - Verified 2026-06-04 with `xcodebuild -project Kairo.xcodeproj -scheme KairoShareExtension -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/kairo-share-extension-derived-data CODE_SIGNING_ALLOWED=NO build`.
- [ ] Run `KairoUITests` smoke flow on simulator.
- [ ] Verify App Group container read/write.
- [ ] Verify purpose strings display correctly.
- [x] Verify BackgroundTasks identifiers match Info.plist.
  - Verified 2026-06-04 by `SourceHealthTests.testBackgroundTaskIdentifiersMatchInfoPlist`, matching `BGTaskSchedulerPermittedIdentifiers` to `BackgroundTaskPolicy.defaultTasks`.
- [ ] Verify no generated user data or secrets are included in the app bundle.

These checks are simulator build evidence only. They are not real-device beta sign-off evidence and do not validate App Group runtime access, permission prompts, App Intents execution, Share Extension import, or persistence on a physical iPhone.
