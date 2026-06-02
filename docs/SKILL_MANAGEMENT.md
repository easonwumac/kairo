# Skill Management

Kairo 的核心方向是把可操作能力包成可管理的 skills，並讓 model 在 prompt context 中看到已安裝、可用、需要確認的 tools。Skill 不是繞過 iOS 權限的方式，而是把 App Intents、Shortcuts、HomeKit、OAuth connector、本機模型與其他 public API 能力封裝成有 metadata、風險等級、確認規則與安裝狀態的工具包。

## Current foundation

- `AgentSkill` describes one managed tool package.
- `AgentSkillCatalog.default` exposes built-in installed skills such as HomeKit scene/accessory demos and Shortcut Daily Briefing.
- `CapabilityPromptContextBuilder` includes installed skills/tools so the model can propose named, supported tool packages.
- Access shows a Skill Manager section with installed skills and management affordances.
- HomeKit skills still require entitlement, Home authorization, action preview, and explicit confirmation before execution.

## Skill package requirements

Every downloadable or user-created skill should declare:

- stable skill id, display name, summary, version, and author;
- source: built-in, marketplace, or user-created;
- installation status: available, installed, or disabled;
- required capabilities and permissions;
- optional `AgentAction` payload or Shortcut recipe binding;
- risk tier and whether confirmation is required;
- download URL and signature/checksum for marketplace packages.

## Marketplace website target

The eventual management website should provide:

- searchable skill catalog with categories, screenshots, permissions, risk tier, and changelog;
- signed skill manifest downloads;
- compatibility filters for iOS version, entitlements, App Intents, Shortcuts, OAuth scopes, and local model requirements;
- install/update/remove flows that sync into the app;
- user-created skill publishing with review metadata;
- clear safety copy for skills that write data, control HomeKit, call external APIs, or require OAuth scopes.

## Near-term implementation order

1. Expand `AgentSkill` into signed package manifests.
2. Add persistence for installed/disabled skills.
3. Add Skill Manager UI for enable/disable/remove and install-from-manifest.
4. Make Shortcut demos and HomeKit controls first-class skills.
5. Build a small static marketplace page backed by signed JSON manifests.
6. Add UI/e2e coverage for install, disable, remove, and prompt-context availability.
