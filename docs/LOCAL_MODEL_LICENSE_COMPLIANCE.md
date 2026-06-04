# Local Model License Compliance

Last checked: 2026-06-04.

## Runtime

- `llama.cpp` is MIT licensed.
- If `llama.xcframework` is embedded in Kairo, the MIT notice must be bundled
  with the app. Kairo stores that notice in `Kairo/Resources/ThirdPartyNotices.md`.
- The compiled framework is a build artifact under `.build/local-runtime/` and
  must not be committed.

## Model Artifacts

- Kairo must not commit model weights, GGUF files, tokenizers, caches, or
  generated model artifacts.
- Model downloads must remain user-triggered.
- Settings must show model size, source host, license name, license URL host,
  intended local-only purposes, storage path, no-iCloud-backup policy, and delete
  flow before download confirmation.
- Remote catalogs must keep per-model `licenseName`, `licenseURL`,
  `downloadURL`, file size, SHA-256, runtime, device requirements, and safety
  policy metadata.

## Qwen3.5 0.8B

- Current catalog artifact: `AaryanK/Qwen3.5-0.8B-GGUF`,
  `Qwen3.5-0.8B.q4_k_m.gguf`.
- Current recorded license: `Apache-2.0`.
- Current catalog behavior: direct user-triggered download from Hugging Face,
  checksum verification, local app storage, backup exclusion, and explicit
  delete flow.
- Kairo does not redistribute this model in the app binary or repository.

## Release Gate

Before adding or changing any downloadable model:

- Verify the upstream model card and license from the source host.
- Confirm the license permits the intended product use.
- Update the model manifest license fields.
- Keep the license approval preview visible in Settings.
- Confirm `.gitignore` excludes downloaded artifacts.
- Run a focused artifact scan before commit.
