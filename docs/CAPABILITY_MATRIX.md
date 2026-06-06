# Capability Matrix

Kairo's capabilities are now evaluated by whether they help the personal information asset loop:

```text
Capture -> Understand -> Prepare Actions
```

## Status labels

| Status | Meaning |
|---|---|
| Implemented | Usable in the app/core path and covered by tests for the stated scope. |
| Scaffolded | Code, UI, models, or protocols exist, but the user flow is not complete. |
| Planned | Accepted direction, not implemented yet. |
| Deprioritized | Existing code may remain, but it should not be a primary user path. |
| Not allowed | Outside App Store-safe public API boundaries. |

## Asset Management

| Capability | Status | Notes |
|---|---|---|
| Asset model | Implemented | `KnowledgeAsset` covers kind, source, createdAt, file reference, extracted text, tags, sensitivity, and linked InfoPages. |
| Asset store | Implemented | File-backed and in-memory stores exist. |
| Asset import from pending shares | Implemented | Main app imports queued share items into Library. |
| Asset list/search/detail | Implemented | Library can display and search saved assets. |
| Asset delete/export | Implemented | User-managed delete/export path exists. |
| iCloud backup policy | Implemented | User can choose backup inclusion for imported assets. |
| Manual note capture | Planned | Should create assets, not separate memory-only records. |
| Photos picker / document picker | Planned | Useful for asset capture; add only if it feeds Library. |
| OCR / screenshot text extraction | Planned | Do not claim until real OCR/runtime exists. |
| Vision screenshot description | Planned | Requires model/runtime evidence. |

## InfoPages

| Capability | Status | Notes |
|---|---|---|
| InfoPage model | Implemented | Structured title/category/summary/facts/timeline/assets/reminders/actions. |
| InfoPage store | Implemented | File-backed and in-memory stores exist. |
| Deterministic InfoPage generation | Implemented | Travel/order/project/general generation from text/extracted text. |
| Travel template data | Implemented | Package tests cover travel generation from asset text. |
| InfoPage List UI | Planned | Next product surface. |
| InfoPage Detail UI | Planned | Travel first. |
| Asset selection into InfoPage | Planned | Needed for real workflow. |
| Space / Collection UI | Planned | Later grouping layer. |

## Actions

| Capability | Status | Notes |
|---|---|---|
| ReminderLink model | Implemented | Supports `kairo://info-page/{id}` deep link and notes fallback. |
| Reminder draft from InfoPage | Scaffolded | Data model exists; UI wiring remains. |
| Confirmed EventKit reminder write | Implemented in chat path / Planned for InfoPage path | Must stay preview + explicit confirmation. |
| Calendar draft | Implemented in chat path / Planned for InfoPage path | Useful for travel/project InfoPages. |
| Email/message reply draft | Implemented in chat path / Planned for InfoPage path | Should remain draft/visible handoff only. |
| Maps/phone/web visible handoff | Implemented in chat path / Planned for InfoPage path | Do not claim completion outside Kairo. |

## Chat And Memory

| Capability | Status | Notes |
|---|---|---|
| Chat | Implemented | Supporting entry for asking about assets and preparing actions. |
| Chat history | Implemented | Persistent thread store exists. |
| Memory store | Implemented | Useful but should converge with asset/InfoPage context. |
| Chat over assets/InfoPages | Planned | Search and cite saved assets/InfoPages. |
| Private chat | Implemented | Support feature, not product center. |

## Models

| Capability | Status | Notes |
|---|---|---|
| Cloud model API key path | Implemented / Scaffolded | Useful for asset understanding when configured. |
| Local model catalog/download/select/delete | Scaffolded | Keep user-triggered; no bundled weights. |
| Simulator local inference | Scaffolded | Only claim when evidence exists. |
| iPhone production local inference | Planned | Requires real runtime proof. |
| Asset extraction model evaluation | Scaffolded | Minimum tests should validate structured extraction, not raw benchmark speed. |

## Deprioritized Existing Systems

| Capability | Status | Notes |
|---|---|---|
| Recipes / sample flows | Deprioritized | Hide unless directly supporting asset-to-action. |
| Skill Manager / managed tools | Deprioritized | Do not show as primary UI. |
| App Integration Harness catalog | Deprioritized | Can remain as safety backend for action previews. |
| Shortcut node expansion | Deprioritized | Do not add nodes before asset MVP. |
| HomeKit live control | Deprioritized | Not useful for current MVP. |
| Keyboard / Widget / CarPlay | Deprioritized | New surfaces are paused. |

## Not allowed

| Capability | Status | Notes |
|---|---|---|
| Reading other apps' private data | Not allowed | Use Share Sheet, copy/paste, user files, or official APIs only. |
| Arbitrary cross-app UI control | Not allowed | No hidden UI automation. |
| Background screen watching | Not allowed | No background screenshots or surveillance. |
| Silent send/call/delete/write | Not allowed | All writes and external actions require preview + confirmation. |
| Silent Apple Shortcuts creation/editing | Not allowed | Kairo can expose App Intents but cannot silently manage Apple Shortcuts. |
