# GitHub Publishing Checklist

Kairo 要公開發布前，必須先確保 repo 不含 secrets、個人本機資料或使用者記憶。

## 發布前檢查

1. 跑 release hygiene runbook：

`docs/RELEASE_HYGIENE.md` 是目前的權威 handoff 流程；GitHub 發布前不要只靠這份舊 checklist。

2. 測試通過：

```bash
swift test
xcodegen generate
git diff --check
```

3. 檢查 secrets、credentials、model artifacts：

```bash
rg -n --hidden --glob '!.git/**' --glob '!.build/**' --glob '!tmp/**' --glob '!Kairo.xcodeproj/**' --glob '!*.xcworkspace/**' --glob '!*.xcuserstate' --glob '!Package.resolved' '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----|password\s*=\s*[^\s]+|api[_-]?key\s*=\s*[^\s]+|access[_-]?token\s*=\s*[^\s]+|refresh[_-]?token\s*=\s*[^\s]+)' .
find . -path './.git' -prune -o -path './.build' -prune -o -path './tmp' -prune -o \( -iname '*.gguf' -o -iname '*.ggml' -o -iname '*tokenizer*' -o -iname '*.safetensors' -o -iname '*.bin' -o -iname '*.mlmodelc' -o -iname '*.mlpackage' -o -iname '*.onnx' -o -iname '*model-cache*' \) -print
```

這兩個 scan 必須沒有 tracked secrets、tokens、private keys、generated credentials、model weights、`.gguf`、tokenizer blobs、model packages 或 downloaded caches。`tmp/` screenshots 只能當非 release support artifact，不可提交或引用為真機證據。

4. 檢查 git 狀態：

```bash
git status --short --branch
```

5. Push 後確認 GitHub Actions 對 submitted commit 成功：

```bash
git rev-parse HEAD
gh run list --repo easonwumac/kairo --branch main --limit 5 --json databaseId,status,conclusion,workflowName,headSha,url
```

`Swift Tests` 的 `headSha` 必須等於 `HEAD`、`status=completed`、`conclusion=success`。舊的成功 run 不可當成本次提交證據。

6. 確認 `.gitignore` 包含：

- `.build/`
- Xcode user files
- `.env*`
- secrets
- provisioning profiles
- local memory-store / SQLite files

## 建立公開 GitHub repo

```bash
git init
git branch -M main
git add .
git commit -m "Initial Kairo scaffold"
gh repo create kairo --public --source . --remote origin --push
```

## 公開定位

README 應明確說明：

- Kairo 是 permissioned iOS Agent，不是 jailbreak/control-everything tool。
- 只使用 iOS public APIs、user-granted permissions、Shortcuts、App Intents、Share Extension、official provider APIs。
- 高風險動作需要 confirmation。
- OpenAI/ChatGPT OAuth 僅走官方授權流程；不保存 ChatGPT web cookies、不爬取網頁 session。

## 發布後

- 確認 GitHub repo visibility 是 public。
- 確認 Actions 沒有洩漏 secret。
- 若之後加入 API key 或 OAuth client secret，使用 GitHub Secrets，不放 repo。
