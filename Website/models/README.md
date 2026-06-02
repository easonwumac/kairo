# Kairo Model Catalog

This folder is the reference seed for the planned standalone `kairo-models` repository. It is a static backend-style catalog that Kairo can fetch from GitHub Pages.

Do not commit model weights, tokenizer blobs, downloaded `.gguf` files, secrets, access tokens, or license-gated artifacts here.

## Files

- `models.json`: signed-catalog-shaped JSON for downloadable model manifests and optional runtime benchmark profiles.
- `index.html`: simple catalog landing page for GitHub Pages.

## Boundary

Kairo stores model metadata here, not inference assets. Every model must use an explicit remote download URL, SHA-256 checksum, file size, runtime type, license, device requirements, safety policy version, and deprecation status. Benchmark profiles may reference GGUF, MLX, Core ML, or other runtime artifacts, but they remain metadata only and must not imply iPhone performance until real-device tests prove it.

The seed catalog currently tracks popular GGUF models at 2B parameters or below, including Qwen/Qwen-Coder, Llama, DeepSeek, SmolLM, Gemma, and StableLM variants. Noncommercial or gated license terms must stay visible and should be enforced by the future standalone `kairo-models` catalog before production rollout.
