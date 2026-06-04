# OpenAI / OAuth Connector Auth Design

## 重要限制

目前不要把「ChatGPT auth 登入」設計成模擬 ChatGPT 網頁登入、保存 session cookie、爬取 ChatGPT 網頁或繞過 OpenAI 官方流程。這會有安全、合規與穩定性問題。

Kairo 採用 provider abstraction：

1. **OpenAI API Key 模式**：使用者或開發者提供 OpenAI API key。
2. **後端代理模式**：Kairo server 持有 OpenAI credentials，使用者登入 Kairo 帳號後使用配額。
3. **OpenAI OAuth / ChatGPT Connector 模式**：若 OpenAI 提供合適的官方 OAuth/connector，透過官方授權流程接入。
4. **BYOM 模式**：Bring Your Own Model，未來可支援 Anthropic、local model、OpenRouter、Azure OpenAI 等。

## MVP 建議

第一版：

- iOS app 支援輸入 OpenAI API key。
- API key 只存在 Keychain。
- App 透過 `AIProvider` protocol 呼叫模型。
- 所有 prompt payload 在 Debug log 中預設 redacted。
- 使用者可選擇 local-only mode，不呼叫雲端模型。

第二版：

- 建 Kairo backend。
- 使用 Sign in with Apple 登入 Kairo。
- 後端管理 OpenAI provider、rate limit、billing、APNs、OAuth connectors。

## Auth 模組

```swift
protocol AIProvider {
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse
}

protocol AuthProvider {
    var isSignedIn: Bool { get }
    func signIn() async throws
    func signOut() async throws
}
```

## OAuth connector core

`OAuthConnectorAuthorizationService` is the shared authorization layer for integrations that expose `OAuthConnectorMetadata` in `IntegrationRegistry`.

Current scope:

- builds provider authorization URLs from registry metadata, client id, redirect URI, scopes, state, and PKCE requirements;
- validates redirect callbacks with `code`, `state`, and `error` handling;
- previews `kairo://oauth/{provider}/callback` URLs through `OAuthConnectorLoginCenter.previewCallback`, stores provider/state/code-length metadata, and does not persist the raw authorization code;
- exchanges authorization codes for token sets only for configured public-client connectors that do not require backend token exchange, using the original state and PKCE code verifier from the same login attempt;
- stores `OAuthTokenSet` values in `CredentialStore` under `CredentialKey.oauthTokenSet(providerKey:)`;
- supports non-PKCE connectors that require backend token exchange, such as GitHub app flows.

`OAuthConnectorLoginCenter` turns the registry into connector login options for Settings/onboarding:

- lists OAuth connectors in registry order;
- reports `connected`, `readyToAuthorize`, `needsClientConfiguration`, or `needsReauthorization`;
- exposes granted scopes from stored token sets without leaking token values;
- creates authorization sessions from per-provider iOS client configuration;
- completes configured public-client login by accepting a pasted callback URL and exchanging it for tokens without storing the raw authorization code;
- records redacted callback previews in the shared app storage path so Settings can show callback status without exposing code/token values.

`SettingsView` surfaces these login options as a status list. It can open an authorization URL only when the app has a provider client configuration; otherwise it labels the connector as needing iOS OAuth client setup. Settings also includes an OAuth callback field for validating callback routing and completing public-client token exchange. It shows only redacted status and never displays the raw authorization code or token values.

Runtime OAuth client configuration is intentionally external to source control. Kairo loads public-client metadata from either:

- `Info.plist` key `KairoOAuthClientConfigurations`, keyed by provider, for example `chatgpt.clientID`, `chatgpt.redirectURI`, and optional space/comma-separated `chatgpt.scopes`;
- process environment overrides such as `KAIRO_OAUTH_CHATGPT_CLIENT_ID`, `KAIRO_OAUTH_CHATGPT_REDIRECT_URI`, and optional `KAIRO_OAUTH_CHATGPT_SCOPES`.

Do not place client secrets, authorization codes, access tokens, refresh tokens, or personal callback URLs in these config values. If a provider requires a client secret or backend token exchange, the iOS app must not perform that exchange directly.

Out of scope for this core:

- refreshing tokens;
- calling provider APIs.
- exchanging authorization codes for providers that require a backend-held client secret or backend token exchange.

Those pieces stay provider-specific or backend-owned because Google, Microsoft, GitHub, Notion, and future connectors have different app registration, client secret, consent review, and token exchange requirements.

## 安全要求

- API key 存 Keychain，不進 UserDefaults。
- 不在 analytics、crash log、debug log 中輸出 token。
- 不 commit OAuth client secret、authorization code、access token、refresh token、callback URL 實例或個人帳號資料。
- 支援清除所有 credentials。
- 支援 request redaction。
- Cloud call 前執行 sensitivity check。
- 高敏感資料預設不上雲。
