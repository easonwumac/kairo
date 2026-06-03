# Kairo Model Catalog

This folder is the reference seed for the planned standalone `kairo-models` repository. It is a static backend-style catalog that Kairo can fetch from GitHub Pages.

Do not commit model weights, tokenizer blobs, downloaded `.gguf` files, secrets, access tokens, or license-gated artifacts here.

## Files

- `models.json`: signed-catalog-shaped JSON for downloadable model manifests and optional runtime benchmark profiles.
- `index.html`: simple catalog landing page for GitHub Pages.

## Boundary

Kairo stores model metadata here, not inference assets. Every model must use an explicit remote download URL, SHA-256 checksum, file size, runtime type, license, device requirements, safety policy version, and deprecation status. Benchmark profiles may reference GGUF, MLX, Core ML, or other runtime artifacts, but they remain metadata only and must not imply iPhone performance until real-device tests prove it.

The seed catalog intentionally starts with a compact starter trio: Qwen3.5 0.8B, Llama 3.2 1B, and Gemma 3 1B. Larger catalogs can live in the future standalone `kairo-models` repository; noncommercial or gated license terms must stay visible and should be enforced before production rollout.
