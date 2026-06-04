# Release Hygiene Runbook

This runbook is the repeatable evidence path before each beta handoff, App Review handoff, or release-blocking commit. It complements `docs/APP_STORE_SUBMISSION_CHECKLIST.md`; it is not a substitute for real-device sign-off.

## Local Checks

Run these before committing release-blocking work:

```bash
swift test
xcodegen generate
git diff --check
```

If `xcodegen` is not installed, record that explicitly in the handoff instead of implying project regeneration was verified.

## Focused Repository Scans

Run focused scans before staging or committing:

```bash
rg -n --hidden --glob '!.git/**' --glob '!.build/**' --glob '!tmp/**' --glob '!Kairo.xcodeproj/**' --glob '!*.xcworkspace/**' --glob '!*.xcuserstate' --glob '!Package.resolved' '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----|password\s*=\s*[^\s]+|api[_-]?key\s*=\s*[^\s]+|access[_-]?token\s*=\s*[^\s]+|refresh[_-]?token\s*=\s*[^\s]+)' .
find . -path './.git' -prune -o -path './.build' -prune -o -path './tmp' -prune -o \( -iname '*.gguf' -o -iname '*.ggml' -o -iname '*tokenizer*' -o -iname '*.safetensors' -o -iname '*.bin' -o -iname '*.mlmodelc' -o -iname '*.mlpackage' -o -iname '*.onnx' -o -iname '*model-cache*' \) -print
```

Both scans must return no tracked secrets, tokens, private keys, generated credentials, model weights, `.gguf`, tokenizer blobs, model packages, or downloaded caches. Do not stage `tmp/` screenshots as release evidence.

## GitHub Actions Gate

After pushing the release candidate commit to `main`, verify the `Swift Tests` workflow succeeded for that exact submitted commit:

```bash
git rev-parse HEAD
gh run list --repo easonwumac/kairo --branch main --limit 5 --json databaseId,status,conclusion,workflowName,headSha,url
```

The matching `headSha` must equal `HEAD`, `workflowName` must be `Swift Tests`, `status` must be `completed`, and `conclusion` must be `success`. Older successful runs do not prove the submitted commit.

## Evidence Boundaries

- `swift test`, source-health tests, simulator UI smoke, screenshots from `tmp/`, and GitHub Actions success are support evidence only.
- Real-device beta sign-off still requires `docs/REAL_DEVICE_BETA_SIGNOFF.md` to have physical-device evidence and no `Blocked - device unavailable` rows.
- App-side catalog signature validation proves fail-closed behavior only; it does not prove production signed catalogs or public trust metadata were published.
- macOS/dev local-model reply checks and benchmark adapters are not iPhone production inference proof.
