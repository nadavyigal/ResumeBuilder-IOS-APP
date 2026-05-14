# Security & Config Standards — ResumeBuilder iOS

---

## API Configuration

- `API_BASE_URL` is set in Xcode build settings → Info.plist
- Never hardcode API URLs in source code
- Use the `Endpoint` enum for all route definitions
- Different build configurations (Debug/Release) can use different `API_BASE_URL` values

---

## Token Storage

- JWT tokens are stored in Keychain via `Core/Auth/KeychainStore.swift`
- Never store tokens in `UserDefaults` — it is not encrypted
- Never log tokens to the console: `print(token)` is a security risk
- Tokens are cleared on sign-out via `AuthService.shared.clearSession()`

---

## No Secrets in Source

- No API keys in source code
- No private keys, passwords, or credentials in any file tracked by git
- If a key is needed at runtime, it must come from the Info.plist (populated from build settings, which can be set per environment)
- Use `.gitignore` to exclude any local config files that contain secrets

---

## Sign in with Apple

- `SignInWithAppleCoordinator.swift` handles the Apple ID credential flow
- The credential is exchanged for a backend JWT — the Apple identity token is not stored long-term
- Always verify Apple tokens server-side — never trust them client-side only

---

## Keychain Access

- Use `KeychainStore.swift` for any sensitive data
- Use appropriate `kSecAttrAccessible` level (e.g., `kSecAttrAccessibleAfterFirstUnlock` for tokens that should be available in background)
- Never store sensitive data in `UserDefaults`, `NSCache`, or temp files

---

## Network Security

- All network requests must use HTTPS
- App Transport Security (ATS) exceptions should not be added unless required for a specific domain
- Check `Info.plist` for any `NSAppTransportSecurity` exceptions before TestFlight — they must be justified

---

## Logging

- Use `OSLog` for all logging (`import OSLog`)
- Do not use `print()` in production code (it is visible in Console.app on device)
- Log at appropriate levels: `.debug` for verbose, `.info` for meaningful events, `.error` for failures
- Never log: tokens, user PII, raw API responses containing resume content

---

## Receipt Verification

- IAP receipts are verified server-side via `ReceiptVerifier.swift`
- Never trust client-side receipt validation for unlocking premium features
- If server receipt verification fails, treat as not purchased (fail safe)
