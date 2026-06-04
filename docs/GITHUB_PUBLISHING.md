# GitHub Publishing Legacy Note

This repository is already published at `https://github.com/easonwumac/kairo`. Do not use this file as an initial-repo creation checklist.

Current publication and release handoff must use:

- `docs/RELEASE_HYGIENE.md` for local tests, scans, generated-project checks, and exact-commit GitHub Actions verification.
- `docs/APP_STORE_SUBMISSION_CHECKLIST.md` for App Review and beta handoff gates.
- `docs/REAL_DEVICE_BETA_SIGNOFF.md` for physical-device evidence.
- `docs/CATALOG_RELEASE_CHECKLIST.md` for standalone skill/model catalog publication gates.

Before any public handoff, verify the current commit rather than relying on old publishing notes:

- `swift test`
- `xcodegen generate`
- `git diff --check`
- focused secret and model-artifact scans from `docs/RELEASE_HYGIENE.md`
- `git status --short --branch`
- GitHub Actions `Swift Tests` success where `headSha` equals `HEAD`

Do not submit or cite `tmp/` screenshots as physical-device evidence. They are support artifacts only and must not be committed.

If repository visibility, remotes, or GitHub Pages publication settings need to change, treat that as a separate repository-ops task and re-run the full release hygiene gate afterward.
