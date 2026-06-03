# Skill Management

Kairo 的核心方向是把可操作能力包成可管理的 skills，並讓 model 在 prompt context 中看到已安裝、可用、需要確認的 tools。Skill 不是繞過 iOS 權限的方式，而是把 App Intents、Shortcuts、HomeKit、OAuth connector、本機模型與其他 public API 能力封裝成有 metadata、風險等級、確認規則與安裝狀態的工具包。

## Current foundation

- `AgentSkill` describes one managed tool package.
- `AgentSkillCatalog.default` exposes built-in installed skills for HomeKit scene/accessory demos and every official `ShortcutDemoCatalog` recipe, including shared-text capture, screenshot-to-reminders, reply drafting, email triage, meeting prep, daily briefing, and generic node-runner examples.
- `AgentSkillManifest` validates downloadable marketplace manifests with required signature metadata, a SHA-256 checksum over the skill payload, and optional P-256 public-key verification through `AgentSkillManifestTrustStore`. Trust keys carry active/revoked state, optional validity windows, revocation timestamps, and revocation reasons so production key rotation can fail closed.
- `AgentSkillManagerService` plus `FileBackedAgentSkillStore` provide install, preview, disable, enable, remove, reload, and version downgrade protection for marketplace/user-created skills.
- `AgentSkillCompatibilityRequirements`, `AgentSkillRuntimeContext`, and `AgentSkillCompatibilityEvaluator` gate marketplace skills on minimum iOS version, required entitlements, connected OAuth providers, and downloaded local models.
- `AgentSkillManagerService.createUserSkillDraft(_:)` creates local user-owned skill drafts with stable `user-` ids only after explicit capability selection and confirmation policy are present. These drafts are saved disabled by default, are not marketplace packages, and still need explicit enablement plus future action wiring before they can be used as tools.
- `AgentSkillManagerService.previewInstall(jsonString:)` decodes signed JSON manifests, validates them, and returns the installed version, incoming version, changelog, compatibility report, and whether the change is install, reinstall, update, or blocked downgrade.
- `AgentSkillManagerService.installManifest(jsonString:)` still supports direct signed JSON install for service callers; the Access UI previews first, then installs the previewed manifest after user confirmation.
- `AgentSkillMarketplaceCatalogService.defaultStandaloneRepository` fetches the published standalone `skills.json` catalog, maps entries into downloadable marketplace skills, and downloads signed manifests for preview.
- `CapabilityPromptContextBuilder` includes installed skills/tools so the model can propose named, supported tool packages.
- `AgentToolInvocationPlanner` is the deterministic preview layer between natural-language requests and managed tools. It suggests only installed skills and official OAuth connector metadata, returns Shortcut/OAuth candidates as visible handoffs, and exposes action-backed skills such as HomeKit as `AgentAction` previews that still pass through `SafetyPolicyEngine`.
- Chat responses persist and render `toolCandidates` separately from executable `proposedActions`, so users can inspect installed Shortcut/OAuth skill matches without Kairo silently running Apple Shortcuts or account actions.
- Access shows a Skill Manager section backed by the app environment when available, with local user-created draft creation, marketplace refresh, marketplace install preview, signed manifest preview/import, built-in Shortcut demo skills, and installed, available, and disabled skill states with install/disable/enable/remove affordances.
- Access disables manifest confirmation when compatibility is blocked. The user still sees why: missing iOS version, entitlement, OAuth provider, or local model download.
- `KairoEnvironment.uiTesting(resetPersistentState:)` gives simulator XCUITest a deterministic file-backed Skill Manager and static marketplace responses for refresh, install preview, signed update preview/confirm, compatibility-blocked install, confirm install, disable/enable, and HomeKit preview flows.
- HomeKit skills still require entitlement, Home authorization, action preview, and explicit confirmation before execution.

## Skill package requirements

Every downloadable or user-created skill should declare:

- stable skill id, display name, summary, version, and author;
- source: built-in, marketplace, or user-created;
- installation status: available, installed, or disabled;
- required capabilities and permissions;
- optional `AgentAction` payload or Shortcut recipe binding;
- optional compatibility requirements: minimum iOS version, entitlement ids, OAuth provider keys, and local model ids;
- risk tier and whether confirmation is required;
- download URL, signature metadata, checksum, and trusted public-key id for marketplace packages.

Local drafts created in Access are intentionally smaller than downloadable marketplace packages. They record name, summary, source, capabilities, compatibility requirements, and disabled status first. They do not carry signatures, checksums, external download URLs, or executable payloads until the user connects them to approved Kairo capabilities.

## Compatibility Gates

Compatibility gates are fail-closed. A signed manifest can be decoded and previewed even when requirements are missing, but `AgentSkillManagerService.install(manifest:)` throws `AgentSkillInstallError.compatibilityBlocked` and the Access UI disables "Confirm Install".

Kairo currently evaluates:

- `minimumIOSVersion`: blocks skills that need a newer iOS runtime.
- `requiredEntitlements`: blocks skills that need entitlements not present in the app context, such as HomeKit.
- `requiredOAuthProviderKeys`: blocks skills until the matching official OAuth connector has a stored token set.
- `requiredLocalModelIDs`: blocks skills until the model has been downloaded by the user and recorded as installed.

This does not grant permissions or install models automatically. Users must still approve OAuth login, HomeKit access, model downloads, and any high-risk action preview.

## Marketplace website target

The static seed lives in `Website/skills` and is mirrored to the standalone GitHub repository `https://github.com/easonwumac/kairo-skills`. The app repo keeps the tests and reference artifacts; the standalone skills repo owns live skill updates, GitHub Pages hosting, screenshots, and signed manifest downloads.

The management website provides:

- searchable skill catalog with categories, screenshots, permissions, risk tier, and changelog;
- signed skill manifest downloads;
- `sourceRepository` metadata so clients know which standalone repo owns updates;
- compatibility filters for iOS version, entitlements, App Intents, Shortcuts, OAuth scopes, and local model requirements;
- install/update/remove flows that sync into the app;
- user-created skill publishing with review metadata;
- clear safety copy for skills that write data, control HomeKit, call external APIs, or require OAuth scopes.

## Near-term implementation order

1. Expand UI/e2e interaction coverage to signed text import and prompt-context availability. Chat now has HomeKit action-preview and Shortcut tool-candidate e2e coverage; Access now has simulator UI coverage for signed marketplace install/update, compatibility-blocked marketplace install, and user-created remove flows.
2. Publish the production marketplace trust-store key material; `docs/TRUST_STORE_RUNBOOK.md` now defines the rotation/revocation release gate.
3. Connect compatibility gates to production entitlement inspection and per-provider OAuth readiness details.
