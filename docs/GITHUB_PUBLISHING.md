# GitHub Publishing Checklist

Kairo 要公開發布前，必須先確保 repo 不含 secrets、個人本機資料或使用者記憶。

## 發布前檢查

1. 測試通過：

```bash
swift test
```

2. 檢查敏感字串：

```bash
rg -n "sk-|OPENAI_API_KEY|apiKey|password|secret|token|refresh_token|access_token" .
```

合理出現於文件或程式常數時可以保留；真正 credential 必須移除。

3. 檢查 git 狀態：

```bash
git status --short
```

4. 確認 `.gitignore` 包含：

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
