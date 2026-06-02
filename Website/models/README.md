# Kairo Model Catalog

This folder is the reference seed for the planned standalone `kairo-models` repository. It is a static backend-style catalog that Kairo can fetch from GitHub Pages.

Do not commit model weights, tokenizer blobs, downloaded `.gguf` files, secrets, access tokens, or license-gated artifacts here.

## Files

- `models.json`: signed-catalog-shaped JSON for downloadable model manifests.
- `index.html`: simple catalog landing page for GitHub Pages.

## Boundary

Kairo stores model metadata here, not inference assets. Every model must use an explicit remote download URL, SHA-256 checksum, file size, runtime type, license, device requirements, safety policy version, and deprecation status.
