# Trust Store Runbook

Kairo uses signed catalogs for downloadable skills and local model metadata. This runbook is the release checklist for rotating or revoking signing keys without shipping model weights, tokenizer blobs, credentials, or unsigned production catalogs in the app repo.

## Scope

- Skill marketplace manifests are published from `easonwumac/kairo-skills` and validated by `AgentSkillManifestTrustStore`.
- Local model catalog metadata is published from the planned `easonwumac/kairo-models` repository and validated by `LocalModelCatalogTrustStore`.
- The app repo may contain public trust metadata, reference seed catalogs, tests, and documentation.
- The app repo must not contain private signing keys, API tokens, model weights, `.gguf`, tokenizer files, caches, generated credentials, or downloaded model artifacts.

## Required Metadata

Skill marketplace trust keys must include:

- `keyID`
- `algorithm`
- `publicKeyBase64`
- `status` as `active` or `revoked`
- `validFrom` when activating a future key
- `expiresAt` when scheduling retirement
- `revokedAt` and `revokedReason` when revoking

Local model catalog trust keys must include:

- `keyID`
- `algorithm`
- `publicKeyBase64`
- `status` as `active` or `revoked`
- `validFrom` when activating a future key
- `validUntil` when scheduling retirement
- `revokedAt` and `revokedReason` when revoking

Production catalog payloads must include the matching signing key id and a non-empty signature. App-side validation must fail closed for missing signatures, unknown keys, revoked keys, out-of-window keys, unsupported algorithms, invalid signatures, non-HTTPS model URLs, and invalid checksums.

## Planned Rotation

1. Generate the new signing key outside this repository.
2. Add only the new public key metadata to the relevant trust store.
3. Mark the outgoing key with a retirement window before using the new key for production payloads.
4. Sign a staging skill manifest or model catalog with the new key.
5. Verify the staging payload in package tests or a signed-catalog dry run before publishing.
6. Publish the signed catalog to the standalone repository.
7. Refresh the catalog from the app and verify that existing active keys still work and the new key is accepted.
8. After the rollout window, mark the old key `revoked` with `revokedAt` or `revokedReason` metadata as supported by that trust store.

## Emergency Revocation

1. Stop publishing payloads signed by the compromised key.
2. Mark the compromised key `revoked` in the app-side trust store and standalone repository metadata.
3. Add a clear `revokedReason` without including secrets or private incident details.
4. Re-sign the marketplace manifest or model catalog with an active replacement key.
5. Run package tests that cover unknown-key, revoked-key, and invalid-signature rejection.
6. Run focused secret and model-artifact scans before commit.
7. Ship the trust-store update before publishing new downloadable payloads that require the replacement key.

## Release Gate

Before App Review or beta release handoff:

- `swift test` must pass.
- `xcodegen generate` must pass when `xcodegen` is installed.
- Focused scans must find no secrets, tokens, private keys, generated credentials, model weights, `.gguf`, tokenizer files, or model caches in tracked files.
- `docs/CATALOG_RELEASE_CHECKLIST.md` must be complete for the standalone skill and model catalog repositories before production catalog publication is claimed.
- `docs/APP_STORE_READINESS.md` must distinguish app-side signature verification from production catalog publication.
- Real-device evidence is still required for runtime claims; signed catalog validation is not proof of iPhone local inference.
