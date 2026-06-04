# Real-Device Beta Sign-Off

This file is the release-blocking physical-device evidence log for the Kairo beta. Do not mark any item as passed from simulator runs, package tests, source-health tests, screenshots from `tmp/`, or code inspection alone.

## Evidence rules

- Required evidence must come from a reachable physical iPhone or iPad installed with the tested Kairo build.
- Each passed row must include device name, OS version, build identifier or commit, tester, date, and a short result note.
- Simulator, package-test, and XCUITest evidence may be linked as supporting coverage only; it is not real-device sign-off.
- If `devicectl` lists devices as `unavailable`, keep all rows as `Blocked - device unavailable`.
- Do not mark local-model iOS runtime, live HomeKit control, cross-app private reads, arbitrary UI control, or silent Apple Shortcut creation as passed in this file.

## Install and launch proof chain

Before marking any row as passed on a real device, capture each step separately:

1. Build the signed app for the physical device with `xcodebuild -destination 'id=<device-id>'`.
2. Confirm the built `.app` exists in the selected derived-data path.
3. Install explicitly with `xcrun devicectl device install app --device <device-id> <path-to-app>`.
4. Verify the installed bundle appears in `xcrun devicectl device info apps --device <device-id>`.
5. Launch with `xcrun devicectl device process launch --device <device-id> app.kairo.ios` after bundle presence is confirmed.

Do not treat a successful build, simulator install, TestFlight upload, or `xcodebuild` destination listing as proof that the app is installed or launched on a physical device.

## Current device availability

Last checked with `xcrun devicectl list devices` on 2026-06-04 08:38 CST:

| Device | Identifier | State |
|---|---|---|
| iPad Air 5 | `EDC75137-2987-56F5-A08D-DB0D7A2B8F05` | Blocked - device unavailable |
| iPhone 17 Pro Max | `58A417FA-6D4D-5F15-B673-AF238D812161` | Blocked - device unavailable |
| iPhone Xs Max | `45BD464D-6093-59A4-A4DA-FA999477B976` | Blocked - device unavailable |

## Sign-off matrix

| Area | Required physical-device check | Status | Evidence |
|---|---|---|---|
| Chat | Launch Kairo, send a standard chat prompt, confirm response renders without unsafe unsupported claims. | Blocked - device unavailable | Pending reachable device. |
| Memory | Save, search, export, delete, and verify deleted memory is absent after refresh. | Blocked - device unavailable | Pending reachable device. |
| Access | Open Access, review Skill Manager state, disabled/compatibility-blocked skills, and permission status copy. | Blocked - device unavailable | Pending reachable device. |
| Settings | Open Settings, verify privacy/account/model sections and deletion controls render on device. | Blocked - device unavailable | Pending reachable device. |
| Share Extension import | Share text, URL, image, and file/PDF metadata into Kairo, then confirm the main app imports queued items without extension-side action execution. | Blocked - device unavailable | Pending reachable device. |
| App Intents Ask | Run Ask Kairo from Shortcuts/App Intents on device and verify returned text matches Kairo runtime behavior. | Blocked - device unavailable | Pending reachable device. |
| App Intents Save | Run Save to Kairo Memory on device and verify memory is visible in Kairo. | Blocked - device unavailable | Pending reachable device. |
| App Intents Search | Run Search Kairo Memory on device and verify expected memory result output. | Blocked - device unavailable | Pending reachable device. |
| Chat history restart persistence | Create a chat, force quit/relaunch Kairo, and verify the thread persists. | Blocked - device unavailable | Pending reachable device. |
| Local notification preview + confirm | Trigger notification action from Chat, verify preview, explicitly confirm, and observe scheduled notification behavior. | Blocked - device unavailable | Pending reachable device. |
| Reminder preview + confirm | Trigger reminder action from Chat, verify EventKit permission/fallback behavior, explicitly confirm, and verify Reminders write or denied fallback. | Blocked - device unavailable | Pending reachable device. |
| Calendar preview + confirm | Trigger calendar action from Chat, verify EventKit permission/fallback behavior, explicitly confirm, and verify Calendar write or denied fallback. | Blocked - device unavailable | Pending reachable device. |
| Contacts permission-denied fallback | Deny Contacts permission and verify Kairo shows a clear fallback without claiming a write. | Blocked - device unavailable | Pending reachable device. |
| Email handoff preview + confirm | Trigger email draft action, verify `mailto:` handoff preview, explicitly confirm, and verify Kairo does not send mail silently. | Blocked - device unavailable | Pending reachable device. |
| Message handoff preview + confirm | Trigger Messages handoff, verify `sms:` handoff preview, explicitly confirm, and verify Kairo does not send messages silently. | Blocked - device unavailable | Pending reachable device. |
| Phone handoff preview + confirm | Trigger phone handoff, verify `tel:` preview, explicitly confirm, and verify visible system handoff. | Blocked - device unavailable | Pending reachable device. |
| Web handoff preview + confirm | Trigger web search handoff, verify URL preview, explicitly confirm, and verify visible browser handoff. | Blocked - device unavailable | Pending reachable device. |
| Maps handoff preview + confirm | Trigger Apple Maps directions handoff, verify URL preview, explicitly confirm, and verify visible Maps handoff without location-read claims. | Blocked - device unavailable | Pending reachable device. |

## Completion rule

Real-device beta sign-off is incomplete until every required row is updated with physical-device evidence. Keep `docs/APP_STORE_READINESS.md` and `NEXT_STEPS.md` marked release-blocking until this file has no `Blocked - device unavailable` rows.
