# Skill Management

Kairo 的核心方向是把可操作能力包成可管理的 skills，並讓 model 在 prompt context 中看到已安裝、可用、需要確認的 tools。Skill 不是繞過 iOS 權限的方式，而是把 App Intents、Shortcuts、HomeKit、OAuth connector、本機模型與其他 public API 能力封裝成有 metadata、風險等級、確認規則與安裝狀態的工具包。

## Current foundation

- `AgentSkill` describes one managed tool package.
- `AgentSkillCatalog.default` exposes built-in installed skills such as HomeKit scene/accessory demos and Shortcut Daily Briefing.
- `AgentSkillManifest` validates downloadable marketplace manifests with required signature metadata, a SHA-256 checksum over the skill payload, and optional P-256 public-key verification through `AgentSkillManifestTrustStore`.
- `AgentSkillManagerService` plus `FileBackedAgentSkillStore` provide install, preview, disable, enable, remove, reload, and version downgrade protection for marketplace/user-created skills.
- `AgentSkillManagerService.previewInstall(jsonString:)` decodes signed JSON manifests, validates them, and returns the installed version, incoming version, changelog, and whether the change is install, reinstall, update, or blocked downgrade.
- `AgentSkillManagerService.installManifest(jsonString:)` still supports direct signed JSON install for service callers; the Access UI previews first, then installs the previewed manifest after user confirmation.
- `CapabilityPromptContextBuilder` includes installed skills/tools so the model can propose named, supported tool packages.
- Access shows a Skill Manager section backed by the app environment when available, with signed manifest preview/import plus installed, available, and disabled skill states with install/disable/enable/remove affordances.
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

The eventual management website should provide:

- searchable skill catalog with categories, screenshots, permissions, risk tier, and changelog;
- signed skill manifest downloads;
- compatibility filters for iOS version, entitlements, App Intents, Shortcuts, OAuth scopes, and local model requirements;
- install/update/remove flows that sync into the app;
- user-created skill publishing with review metadata;
- clear safety copy for skills that write data, control HomeKit, call external APIs, or require OAuth scopes.

## Near-term implementation order

1. Make Shortcut demos and HomeKit controls first-class persisted skills.
2. Build a small static marketplace page backed by signed JSON manifests.
3. Add UI/e2e coverage for signed import, update, disable, remove, and prompt-context availability.
4. Add production trust-store key rotation/revocation metadata.
