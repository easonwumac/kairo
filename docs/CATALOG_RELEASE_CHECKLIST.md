# Catalog Release Checklist

This checklist is the production handoff gate for standalone Kairo skill and model catalogs. It does not replace app-side signature verification in `docs/TRUST_STORE_RUNBOOK.md`; it defines what must be published outside this app repo before beta or App Review copy can claim production catalog readiness.

## Repository Boundaries

- `easonwumac/kairo-skills` owns the production skill marketplace catalog, signed skill manifests, public trust-store metadata, changelogs, screenshots, compatibility metadata, and GitHub Pages hosting.
- `easonwumac/kairo-models` owns the production model catalog metadata, public trust-store metadata, model manifest rows, rollout metadata, license metadata, and GitHub Pages hosting.
- This app repo may keep reference seeds, tests, docs, and public trust metadata only.
- `Website/skills/skills.json` and `Website/models/models.json` in this app repo are unsigned reference seeds with `catalogSignatureStatus=referenceUnsigned`; they are not production signed catalog evidence.
- This app repo must not contain private signing keys, API tokens, generated credentials, model weights, tokenizer blobs, `.gguf`, `.safetensors`, `.onnx`, `.mlpackage`, `.mlmodelc`, or downloaded model caches.

## Skill Catalog Release Gate

Before marking the Skill marketplace production-ready:

- Publish a signed `skills.json` catalog from `easonwumac/kairo-skills`.
- Publish every downloadable skill manifest with signature metadata, SHA-256 checksum, version, changelog, author, permissions, risk tier, and compatibility requirements.
- Publish public trust-store key metadata with `keyID`, `algorithm`, `publicKeyBase64`, `status`, `publicationStatus`, activation window, retirement window, and revocation metadata where applicable.
- Keep default app-side marketplace release keys at `publicationStatus=pendingPublication` until the standalone signed catalog and public trust metadata are actually published.
- Verify unknown-key, revoked-key, pending-publication-key, expired-key, downgrade, invalid-signature, checksum, and compatibility-blocked paths fail closed in package tests.
- Confirm compatibility-blocked skills remain preview-only and cannot become executable tool candidates.
- Confirm Access install/update/remove UI smoke coverage is simulator-only support evidence, not real-device sign-off.

## Model Catalog Release Gate

Before marking local model catalog publication production-ready:

- Publish a signed `models.json` catalog from `easonwumac/kairo-models`.
- Publish only metadata and HTTPS download URLs; do not publish model weights in this app repo.
- Include model id, display name, version, runtime type, SHA-256, file size, license, license URL, minimum OS, minimum RAM/device tier, context window, safety policy version, benchmark profiles, deprecation status, rollout channel, and rollback metadata.
- Publish public trust-store key metadata with `keyID`, `algorithm`, `publicKeyBase64`, `status`, `publicationStatus`, `validFrom`, `validUntil`, `revokedAt`, and `revokedReason` where applicable.
- Keep default app-side release keys at `publicationStatus=pendingPublication` until the standalone signed catalog and public trust metadata are actually published.
- Verify unknown-key, revoked-key, pending-publication-key, out-of-window-key, invalid-signature, non-HTTPS URL, invalid-checksum, cancellation, stale-download cleanup, and delete-selected-model paths fail closed in package tests.
- Keep iOS production inference runtime marked Planned until a real-device runtime build proves latency, memory, thermal behavior, and App Store-compatible packaging.

## App Review Boundary

- App-side trust-store validation is not proof that production catalogs have been published.
- Signed catalog validation is not proof of iPhone local inference.
- Simulator UI smoke, package tests, source-health tests, and screenshots from `tmp/` are supporting evidence only; real-device beta sign-off still requires `docs/REAL_DEVICE_BETA_SIGNOFF.md`.
- Do not claim real HomeKit live control, silent Apple Shortcut creation, arbitrary cross-app UI control, private cross-app reads, or iOS production local inference from catalog publication alone.
