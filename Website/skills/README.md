# Kairo Skill Marketplace

This folder is the static seed for the standalone skills repository.

Standalone repository:

```text
https://github.com/easonwumac/kairo-skills
```

GitHub Pages URL:

```text
https://easonwumac.github.io/kairo-skills/
```

The Kairo app can import signed skill manifests from `manifests/`, while `skills.json`
is the public catalog used by the static marketplace page. Keep these artifacts in
sync when publishing updates:

- `skills.json`: searchable catalog entries, screenshots, risk tier, permissions, compatibility requirements, and changelog.
- `manifests/*.json`: signed `AgentSkillManifest` payloads importable through Access Skill Manager.
- `assets/*.svg`: public card artwork for GitHub Pages and README previews.

Compatibility requirements are metadata only. They can require a minimum iOS
version, entitlement ids, connected OAuth provider keys, or user-downloaded local
model ids. They do not grant permissions, install models, or bypass user approval.
