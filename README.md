# Kairo

![Kairo GitHub cover](Assets/github-readme-cover.svg)

Kairo is an open-source Swift/SwiftUI iOS agent scaffold for building a **universal, sandbox-compliant iPhone assistant**. It combines chat, long-term memory, Share Extension ingestion, App Intents/Shortcuts, permission-aware tools, audit logs, OpenAI-compatible cloud models, and local-model fallback planning without pretending iOS apps can bypass sandbox rules.

> Product principle: if a capability is allowed by user consent, iOS public APIs, App Intents, Shortcuts, extensions, or official third-party APIs, Kairo should make it useful. If iOS does not allow it, Kairo must explain the boundary and offer a safe alternative.

## What Kairo is

Kairo is a source-first iOS agent reference implementation for developers who want to ship an App Store-safe assistant that can:

- Chat with the user and preserve conversation history.
- Remember user-approved facts in an editable memory store.
- Understand files, links, text, and images shared into the app.
- Preview sandbox-safe actions before execution.
- Use App Intents and Shortcuts for user-triggered automation.
- Call official model/provider APIs or route eligible work to a local fallback model.
- Keep a clear audit trail of what the agent saw, suggested, and did.

## Sandbox-first scope

Kairo does **not** promise capabilities that normal App Store apps cannot provide:

- Arbitrary reading of other apps' private data.
- Background screen watching or screenshots.
- Unprompted control of other app UIs.
- Permission bypasses, private APIs, jailbreak-only APIs, or background daemons.
- Unapproved access to Messages, Mail, Notes, or ChatGPT web sessions/cookies.

Instead, Kairo uses iOS-supported entry points: Share Extension, document/photo pickers, EventKit, Contacts.framework, UserNotifications, App Intents, Shortcuts, `mailto:`/`sms:`/Apple Maps/URL handoff, OAuth connectors, and explicit user confirmation.

## Current implementation

- Swift Package product: `KairoCore`.
- SwiftUI app scaffold: Chat, Memory Center, Access/Permissions, Settings.
- Persistent chat threads with JSON-backed history store.
- Memory store protocols plus in-memory and JSON file implementations.
- OpenAI provider abstraction, credential store, Keychain-backed credential store, ChatGPT OAuth scaffold, generic OAuth connector authorization core, redacted callback preview store, connector login status center, and Settings connector status/callback UI.
- Downloadable local-model starter catalog entries for a deliberately small set of popular public GGUF models, currently Qwen3.5 0.8B and Llama 3.2 1B, plus `LocalModelCatalogService` for the planned `kairo-models` static backend, verified downloader, install registry, selected-model settings, compact model management UI/catalog refresh, benchmark metadata, local reply-check runtime abstraction, and provider-routing scaffold. Model weights are not bundled in the app or repository.
- Chat messages support text selection/copy and compact reply references, so replying to a previous message does not require pasting the whole source message into the composer.
- Capability registry, sandbox action catalog, safety policy engine, action preview UI, and sandbox action executor.
- Chat can surface executable local notification actions through `UserNotifications`, reminder actions through EventKit Reminders, calendar-event actions through EventKit Calendar, contact-create actions through Contacts.framework, email draft handoffs through `mailto:`, Messages recipient handoffs through `sms:`, and Apple Maps directions handoffs through `maps.apple.com`, but all stay behind visible action preview, runtime permission or visible handoff, and explicit user confirmation. Messages handoff keeps body text in Kairo preview because Apple's SMS link does not carry message body text.
- Kairo-owned internal recipe engine with sample recipes, file-backed recipe store, deterministic preview/run runner, risk confirmation gates, App Intents bridge (`Run/Suggest/List Kairo Recipe`, `Run Kairo Daily Briefing`), Shortcut template registry, and a Shortcuts drawer screen for adding, previewing, running, enabling, disabling recipes, and reviewing user-installed Shortcut template guidance. These are not Apple Shortcuts workflows.
- Agent skill catalog, all official Shortcut demo recipes as built-in skills, deterministic tool invocation planner, chat-visible tool candidates for Shortcut/OAuth handoffs, local user-created skill drafts, manifest signature metadata, SHA-256 checksum validation, public-key trust-store verification, signed manifest JSON import, update preview with changelog, version downgrade protection, compatibility gates for iOS version/entitlements/OAuth providers/downloaded local models, file-backed skill install lifecycle, environment-backed Access Skill Manager UI, so installed tools can be shown to the model and managed by the user.
- Static skill marketplace seed under `Website/skills`, mirrored to the independent `easonwumac/kairo-skills` repo, plus app-side catalog refresh and manifest-download preview from the published GitHub Pages catalog.
- Static model catalog seed under `Website/models`, intended to be mirrored to the planned independent `easonwumac/kairo-models` repo for signed model-list updates and runtime benchmark metadata.
- Popular app integration registry covering App Intents, Shortcuts, URL schemes/universal links, Share Extension handoff, and OAuth connector metadata.
- BGTaskScheduler-compatible background task policy for bounded app refresh/processing work without daemon overclaims.
- Share Extension ingestion queue for text, URLs, files, and images.
- Structured Shortcut node runtime, executable official demo recipe runner, Settings demo recipe UI, and App Intents for asking, saving, searching, summarizing, task extraction, draft replies, reminder drafts, daily briefings, and generic node-kind plus JSON input/output chaining.
- User-visible Shortcuts handoff URL builder with encoded input payloads and structured callback parsing.
- HomeKit-safe action model, executor injection, and Access demo UI for confirmed scene/accessory control.
- XcodeGen UI test target scaffold, UI smoke scenario catalog, deterministic `--ui-testing` Skill Manager environment, Access/HomeKit/Skill Manager interaction and compatibility-blocked install coverage, chat notification/reminder/calendar/contact/email-draft/Messages/Apple-Maps action-preview e2e coverage, Shortcut tool-candidate e2e coverage, and stable SwiftUI accessibility identifiers.
- App icon source plus GitHub/README visual assets.
- Privacy manifest, purpose-string notes, capability matrix, App Store readiness docs, and unit tests.

## Visual overview

![Kairo capability board](Assets/github-capability-board.svg)

![Kairo Shortcut recipes](Assets/github-shortcut-recipes.svg)

## Brand assets

<img src="Assets/kairo-app-icon.svg" alt="Kairo app icon source" width="140">

- App icon source: [Assets/kairo-app-icon.svg](Assets/kairo-app-icon.svg)
- GitHub cover / social preview source: [Assets/github-readme-cover.svg](Assets/github-readme-cover.svg)
- Capability overview: [Assets/github-capability-board.svg](Assets/github-capability-board.svg)
- Shortcut recipes overview: [Assets/github-shortcut-recipes.svg](Assets/github-shortcut-recipes.svg)

## Repository layout

```text
kairo/
├── Assets/                         # Open-source SVG logo, icon, and GitHub visual assets
├── Config/                         # Info.plist and purpose-string notes
├── Kairo/
│   ├── App/                        # SwiftUI app entry point
│   ├── Extensions/ShareExtension/  # Share ingestion scaffold
│   ├── Intents/                    # App Intents scaffold
│   ├── Models/                     # Agent, chat, attachment, memory models
│   ├── Resources/                  # Privacy manifest
│   ├── Services/                   # Stores, providers, permissions, actions
│   └── Views/                      # SwiftUI screens and components
├── Tests/                          # Swift Package tests
├── Website/                        # Static marketplace seed for standalone skill repo hosting
├── docs/                           # Product, architecture, safety, release docs
├── Package.swift
└── project.yml                     # XcodeGen project scaffold
```

## Quick start

```bash
swift test
```

Optional Xcode project generation:

```bash
xcodegen generate
```

The package is intentionally dependency-free. The iOS app target is described in `project.yml`; the core logic stays in `KairoCore` so it can be tested without an iOS simulator.

## Product roadmap

1. App target hardening: entitlements, App Group, Share Extension UI, widgets.
2. Memory and chat persistence migration to SwiftData/Core Data for production apps.
3. Real provider integrations: OpenAI Responses API, official OAuth connectors, optional backend proxy, and provider-specific app review/security requirements.
4. Tool/skill execution: package usable iOS capabilities as managed skills, then execute EventKit writes, local notifications, URL/deep-link handoff, Shortcuts/App Intents, documents/photos import.
5. Bounded background work: BGAppRefreshTask/BGProcessingTask registration, checkpointing, expiration handling, and user-visible rescheduling.
6. Local model fallback: signed production model catalog, real-device runtime benchmark proof, device gating, progress/cancel UI, and safety policy versioning.
7. Skill marketplace: signed skill manifests, compatibility-gated install/update/remove flows, and a management website for downloadable skills.
8. App Store readiness: privacy nutrition labels, review notes, permission prompts, deletion/export flows.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Capability matrix](docs/CAPABILITY_MATRIX.md)
- [Safety and privacy](docs/SAFETY_AND_PRIVACY.md)
- [OpenAI/auth strategy](docs/AUTH_OPENAI.md)
- [Local model fallback](docs/LOCAL_MODEL_FALLBACK.md)
- [Recipe engine](docs/RECIPE_ENGINE.md)
- [Shortcuts strategy](docs/SHORTCUTS_STRATEGY.md)
- [Skill management](docs/SKILL_MANAGEMENT.md)
- [App Store readiness](docs/APP_STORE_READINESS.md)
- [Roadmap](docs/ROADMAP.md)

## License

MIT. See [LICENSE](LICENSE).
