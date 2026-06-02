# Skill Management

Kairo 的核心方向是把可操作能力包成可管理的 skills，並讓 model 在 prompt context 中看到已安裝、可用、需要確認的 tools。Skill 不是繞過 iOS 權限的方式，而是把 App Intents、Shortcuts、HomeKit、OAuth connector、本機模型與其他 public API 能力封裝成有 metadata、風險等級、確認規則與安裝狀態的工具包。

## Current foundation

- `AgentSkill` describes one managed tool package.
- `AgentSkillCatalog.default` exposes built-in installed skills for HomeKit scene/accessory demos and every official `ShortcutDemoCatalog` recipe.
- `AgentSkillManifest` validates downloadable marketplace manifests with required signature metadata, a SHA-256 checksum over the skill payload, and optional P-256 public-key verification through `AgentSkillManifestTrustStore`.
- `AgentSkillManagerService` plus `FileBackedAgentSkillStore` provide install, preview, disable, enable, remove, reload, and version downgrade protection for marketplace/user-created skills.
- `AgentSkillManagerService.previewInstall(jsonString:)` decodes signed JSON manifests, validates them, and returns the installed version, incoming version, changelog, and whether the change is install, reinstall, update, or blocked downgrade.
- `AgentSkillManagerService.installManifest(jsonString:)` still supports direct signed JSON install for service callers; the Access UI previews first, then installs the previewed manifest after user confirmation.
- `AgentSkillMarketplaceCatalogService.defaultStandaloneRepository` fetches the published standalone `skills.json` catalog, maps entries into downloadable marketplace skills, and downloads signed manifests for preview.
- `CapabilityPromptContextBuilder` includes installed skills/tools so the model can propose named, supported tool packages.
- Access shows a Skill Manager section backed by the app environment when available, with marketplace refresh, marketplace install preview, signed manifest preview/import, built-in Shortcut demo skills, and installed, available, and disabled skill states with install/disable/enable/remove affordances.
- HomeKit skills still require entitlement, Home authorization, action preview, and explicit confirmation before execution.

## Skill package requirements

Every downloadable or user-created skill should declare:

- stable skill id, display name, summary, version, and author;
- source: built-in, marketplace, or user-created;
- installation status: available, installed, or disabled;
- required capabilities and permissions;
- optional `AgentAction` payload or Shortcut recipe binding;
- risk tier and whether confirmation is required;
- download URL, signature metadata, checksum, and trusted public-key id for marketplace packages.

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

1. Add UI/e2e interaction coverage for marketplace refresh, marketplace install preview, signed import, update, disable, remove, and prompt-context availability.
2. Add production trust-store key rotation/revocation metadata.
3. Add compatibility gates for iOS version, entitlements, OAuth scopes, and local model requirements.
