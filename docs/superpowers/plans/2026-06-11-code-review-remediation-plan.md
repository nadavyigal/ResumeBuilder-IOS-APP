# Code Review Remediation Plan — 2026-06-11

## Objective

Resolve all findings from the full codebase review (bugs, optimization, cleanup) in this iOS repo, with safe sequencing so auth/user-data fixes land before monetization is enabled.

## Scope

| In scope (this repo) | Out of scope (separate backend repo) |
|----------------------|--------------------------------------|
| SwiftUI app, services, view models | Stripe webhooks / idempotency |
| `supabase/functions/delete_account` | Supabase RLS migrations / policy audit |
| `Config/Info.plist`, `.xcconfig` secrets | AI prompt caching on server |
| Unit tests in `ResumeBuilder IOS APPTests/` | Postgres index tuning |

**Note:** No Stripe code exists here. IAP = StoreKit 2 → `/api/v1/iap/verify`.

---

## Execution Principles

1. **One PR-sized chunk per phase** — do not mix auth hardening with large view refactors.
2. **Tests with behavior changes** — every bug fix gets at least one focused test or XCTest extension.
3. **No monetization flip** until Phase 2 (StoreKit) is complete and verified.
4. **Do not delete dead files** until grep confirms zero references and Xcode target membership is checked.
5. **Mark completed items** in the Progress Tracker below (`[ ]` → `[x]`).

---

## Phase 0 — Baseline (15 min)

- [ ] Read this plan end-to-end.
- [ ] `git checkout -b fix/code-review-remediation`
- [ ] Run existing tests: `xcodebuild test -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17'`
- [ ] Record baseline pass/fail in `tasks/progress.md` (one line).

---

## Phase 1 — Auth & User-Data Security (P0)

**Goal:** Stop silent sign-outs, token races, Keychain backup leakage, and schema exposure on account deletion.

### 1.1 Keychain hardening — B-05, B-15

**Files:** `Core/Auth/KeychainStore.swift`

- [ ] Add `kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to `save()` insert dictionary.
- [ ] Check `SecItemAdd` status; throw a small `KeychainStoreError.saveFailed` or log via `OSLog` if not `errSecSuccess`.
- [ ] Add test: save/read round-trip still works (`ResumeBuilder IOS APPTests/` — new `KeychainStoreTests.swift` if needed).

### 1.2 JWT-aware refresh + resilient sign-out — B-02

**Files:** `App/AppState.swift`, new `Core/Auth/JWTDecoder.swift` (or inline helper)

- [ ] Decode `exp` from `session.accessToken` (base64 payload, no verification needed for expiry gate only).
- [ ] `refreshSessionIfNeeded()`: skip refresh if `exp > now + 300s`.
- [ ] On refresh failure: sign out **only** for auth errors (`invalid_grant`, 401 from GoTrue). Keep session on `URLError` / timeout.
- [ ] Add unit tests for expiry gate (mock JWT with near/far `exp`).

### 1.3 Serialize concurrent refresh — B-03

**Files:** `App/AppState.swift`

- [ ] Add `private var refreshTask: Task<String, Error>?` (or `actor TokenRefresher`).
- [ ] `refreshAccessToken()`: if task in flight, `await` it; else create one.
- [ ] `callWithFreshToken` and `deleteAccount` both use the shared refresh path.
- [ ] Test: simulate two parallel `callWithFreshToken` calls with expired token mock → single refresh.

### 1.4 Require refresh token after sign-in — B-04

**Files:** `Core/Auth/AuthService.swift`

- [ ] In `postToGoTrue`, after decode: `guard let refresh = decoded.refresh_token else { throw AuthServiceError.invalidResponse }`.
- [ ] Sign-up path (lines 95–100): same guard when `access_token` is present.
- [ ] Test: decode path rejects nil refresh token.

### 1.5 Account deletion response sanitization — B-07

**Files:** `supabase/functions/delete_account/index.ts`

- [ ] Remove `details: failures` from JSON 500 body (keep `console.error` server-side).
- [ ] Deploy function: `supabase functions deploy delete_account` (manual step — document in PR).

### 1.6 Move Supabase anon key out of source — C-01

**Files:** `Core/API/BackendConfig.swift`, `Config/Info.plist`, `Secrets.xcconfig.template`, `Secrets.xcconfig` (local only)

- [ ] Add `SUPABASE_ANON_KEY` to Info.plist via xcconfig (mirror `API_BASE_URL` pattern).
- [ ] `BackendConfig.supabaseAnonKey` reads from bundle; `preconditionFailure` if missing.
- [ ] Update `Secrets.xcconfig.template` with placeholder.
- [ ] **Do not commit** real key in `Secrets.xcconfig` if not already committed.

### Phase 1 verification

- [ ] Cold launch with valid session → no unnecessary refresh (network log).
- [ ] Airplane mode on launch → user stays signed in.
- [ ] Sign in → Keychain item has `ThisDeviceOnly` (inspect via test assertion on accessibility attribute if feasible).
- [ ] All tests green.

---

## Phase 2 — Resume Upload & Payments (P0)

**Goal:** Fix DOCX mislabeling; make IAP scaffold safe before monetization flag flips.

### 2.1 Fix cached resume extension — B-06

**Files:** `ViewModels/ScanViewModel.swift`

- [ ] Preserve original extension: `cached_resume.\(fileURL.pathExtension.lowercased())`.
- [ ] If extension not `pdf` or `docx`, reject before copy.
- [ ] Test: pick `.docx` → cached path ends in `.docx`; `UploadFilePreflight.mimeType` returns docx MIME.

### 2.2 DOCX preflight policy — B-17

**Files:** `Core/API/UploadFilePreflight.swift`, `Features/V2/Scan/ScanResumeView.swift`, `Features/Onboarding/ImportResumeView.swift`

**Choose one (document decision in PR):**

- **Option A (recommended for MVP):** Restrict UI to PDF only; remove DOCX from picker labels until server DOCX path is verified.
- **Option B:** Add client DOCX text extraction (ZIP + `word/document.xml` parse) and populate `resumeText`.

- [ ] Implement chosen option.
- [ ] Test: PDF still extracts text; DOCX behaves per policy.

### 2.3 Real StoreKit purchase — B-01, B-18

**Files:** `Core/Payments/StoreKitManager.swift`, `Core/Payments/ReceiptVerifier.swift`

- [ ] `loadProducts()`: `Product.products(for: availableProductIDs)`.
- [ ] `purchase(productID:)`: `product.purchase()`, verify `VerificationResult.verified`, return `String(transaction.id)`.
- [ ] `ReceiptVerifier`: guard non-empty IDs; validate `productID` ∈ allowlist.
- [ ] Keep `BackendConfig.isMonetizationEnabled = false` until manual QA on sandbox IAP.
- [ ] Add tests with `StoreKitTest` session or mocked protocol if available.

### Phase 2 verification

- [ ] Upload PDF via Scan → success.
- [ ] Upload DOCX (if still supported) → correct MIME and server acceptance.
- [ ] StoreKit sandbox purchase (when enabled) → real transaction ID shape in verify payload.

---

## Phase 3 — API Boundaries & Chat/PDF UX (P1)

### 3.1 Chat history on open — B-11

**Files:** `Features/V2/Chat/ChatView.swift`, `Features/V2/Chat/ChatViewModel.swift`

- [ ] Add `func bootstrapSession(token: String?) async` on `ChatViewModel`:
  - `fetchActiveSession(optimizationId:)` → set `sessionId`
  - `refreshHistory(token:)`
- [ ] `ChatView.chatContent.task { await vm.bootstrapSession(...) }`.
- [ ] Test: mock `ChatService` returns session + messages → view model populated without send.

### 3.2 Chat message length cap — B-12

**Files:** `ChatViewModel.swift`, optionally `ChatInputBar` in `ChatView.swift`

- [ ] Reject messages > 4000 chars with `errorMessage`.
- [ ] Optional: `onChange` cap on `TextField` binding (like Scan JD 5000 cap).
- [ ] Test: 4001-char message rejected.

### 3.3 PDF download validation & fallback UX — B-08, B-09, B-10

**Files:** `ViewModels/OptimizedResumeViewModel.swift`, `Features/V2/Preview/ResumePreviewWebView.swift`, `Core/Export/PDFExporter.swift`, new `Core/Export/PDFDownloadValidator.swift`

- [ ] Extract shared `looksLikePDF(_:)` + status check helper.
- [ ] `PDFExporter.downloadPDF`: validate magic bytes after `getData`.
- [ ] `ResumePreviewWebView.downloadAndShare`: surface errors; validate PDF header.
- [ ] `downloadPDFWithLocalFallback`: set `errorMessage` or non-blocking banner when falling back; only fall back on timeout/5xx (not 4xx).
- [ ] Tests for non-PDF response rejection.

### 3.4 ATS scoring & improvements — B-13, B-14

**Files:** `Services/ResumeAnalysisService.swift`, `ViewModels/ImproveViewModel.swift`, `Features/V2/Improve/ImproveView.swift`

- [ ] Confirm with backend whether `resume_original == resume_optimized` is correct pre-optimize; document in code comment or fix if wrong.
- [ ] **Improvements stub:** either wire real endpoint OR remove `improvements()` from `loadAnalysis` parallel fetch and delete empty UI section until implemented.
- [ ] Add `// TODO(RES-XXX):` with ticket if deferring.

### 3.5 Anonymous session conversion — B-16

**Files:** `App/AppState.swift`

- [ ] On conversion failure, set `anonymousConversionPending = true` (UserDefaults).
- [ ] Retry on next `setSession` / foreground.
- [ ] Optional: debug-only log; no PII.

### 3.6 Minor bug fixes — B-19, B-20

- [ ] `ResumeAnalysisService.mapATSResult`: `flatMap` → `map` (clarity).
- [ ] `StreamingClient.streamDisplayedText`: `Task.checkCancellation()` in loop.

### Phase 3 verification

- [ ] Open Chat on existing optimization → prior messages visible.
- [ ] Oversized chat message blocked in UI.
- [ ] PDF export with mocked 500 → user sees error, not corrupt share sheet.
- [ ] Improve tab behaves correctly re: improvements section.

---

## Phase 4 — Performance & Architecture (P2)

### 4.1 Parallel home load — O-01

**Files:** `ViewModels/HomeViewModel.swift`

- [ ] `async let` for exports + history lists.
- [ ] Test timing optional; behavior test for both populated.

### 4.2 Shared APIClient — O-05

**Files:** `Core/API/RuntimeServices.swift`, `App/AppState.swift`, all services with `APIClient()`

- [ ] `RuntimeServices.sharedAPIClient` or inject from `AppState.apiClient`.
- [ ] Replace per-service `APIClient()` instances (19 call sites).
- [ ] Verify upload still uses long-timeout session inside `APIClient`.

### 4.3 Detail cache eviction — O-04

**Files:** `ViewModels/OptimizedResumeViewModel.swift`

- [ ] Replace unbounded `detailCache` with LRU (max 10) or `NSCache`.
- [ ] Mirror `PreviewHTMLCache` pattern in `ResumePreviewWebView.swift`.

### 4.4 Expert reports cache — O-07

**Files:** `Features/V2/Expert/ExpertModesViewModel.swift`

- [ ] TTL cache (30s) + in-flight task deduplication for `loadSavedReports`.

### 4.5 ResumeDesignService via APIClient — O-10

**Files:** `Services/ResumeDesignService.swift`

- [ ] Route `renderPreview` through `apiClient.postJSON` with 60s timeout.

### 4.6 Backend score round-trip — O-02 (coordination)

- [ ] File backend ticket: `POST /api/ats/score` accepting `resume_id` to avoid full-text fetch + resend.
- [ ] iOS change only after backend ships.

### 4.7 View decomposition — O-06 (optional, last)

**Files:** `Features/V2/Improve/OptimizedResumeView.swift`

- [ ] Extract `ATSScoreCard`, `ATSInsightPanel`, `SectionEditor`, `ExportBar` into separate files.
- [ ] Only if time permits; not blocking other phases.

### Phase 4 verification

- [ ] Home tab loads visibly faster (manual).
- [ ] No regression in upload/chat/expert flows after APIClient sharing.

---

## Phase 5 — Cleanup (P3)

### 5.1 Dead code removal

- [ ] Delete `Features/Home/MainTabView.swift` (C-02) — confirm zero refs.
- [ ] Delete or merge `Core/DesignSystem/Components/AppTabBar.swift` (C-03).
- [ ] Remove `OnboardingViewModel.refreshIfNeeded()` (C-04).

### 5.2 Debug logging

- [ ] Wrap `TailorView.swift` and `TailorViewModel.swift` prints in `#if DEBUG` (C-07, C-08).

### 5.3 Consolidate PDF download — C-09

- [ ] Single `PDFDownloadService` or extend `PDFExporter` used by `OptimizedResumeViewModel` and `ResumePreviewWebView`.

### 5.4 Feature flags & stubs — C-05, C-06, C-10, C-11

- [ ] Add ticket references to Stage 2 flags in `BackendConfig.swift`.
- [ ] Comment `RuntimeFeatures.isResumeLibraryEnabled` with removal plan.
- [ ] Add `// TODO(Stage2-RES-XXX):` on `StoreKitManager`, `improvements()`, `rejectChange()`.

### 5.5 Large file splits — C-12, O-09

- [ ] Split `DomainModels.swift` by domain (incremental — start with Chat + Expert structs).
- [ ] Defer if high conflict risk; track as follow-up PR.

### Phase 5 verification

- [ ] Clean build, no new warnings.
- [ ] Grep confirms removed symbols unreferenced.

---

## Phase 6 — Backend Follow-Up (separate repo)

Track these in the backend project; not blocking iOS PR merge except where noted.

| ID | Item | Owner |
|----|------|-------|
| B-21 | Stripe webhook idempotency audit | Backend |
| B-22 | `profiles` dual FK (`user_id` / `auth_user_id`) RLS alignment | Backend / Supabase |
| O-02 | ATS score by `resume_id` endpoint | Backend |
| B-12 | Server-side chat message max length (defense in depth) | Backend |
| B-18 | Server-side IAP transaction verification | Backend |

---

## Progress Tracker

Copy status here as phases complete:

```
Phase 0: [x]
Phase 1: [x]  (1.1–1.6; delete_account deploy still manual)
Phase 2: [x]  (2.1–2.3; isMonetizationEnabled=false)
Phase 3: [x]  (3.1–3.6; mapATSResult keeps flatMap for Optional<Int?>)
Phase 4: [x]  (4.1–4.5; 4.6–4.7 deferred)
Phase 5: [x]  (5.1–5.4; 5.5 deferred)
Phase 6: [ ]  (backend tickets — separate repo)
```

---

## Suggested PR Stack

| PR | Phases | Title |
|----|--------|-------|
| 1 | 1 | `fix(auth): harden session refresh and keychain` |
| 2 | 1.5 + 2.1–2.2 | `fix(upload): resume cache MIME + delete_account response` |
| 3 | 2.3 | `feat(iap): real StoreKit 2 purchase verification` |
| 4 | 3 | `fix(chat,pdf): history restore, validation, limits` |
| 5 | 4 | `perf: shared APIClient, parallel loads, caches` |
| 6 | 5 | `chore: remove dead code and consolidate PDF download` |

---

## Test Commands

```bash
# Unit tests
xcodebuild test \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ResumeBuilder\ IOS\ APPTests

# Build only (CI smoke)
xcodebuild build \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Related Documents

- Implementation prompt (paste into new Cursor session): `docs/superpowers/plans/2026-06-11-code-review-implementation-prompt.md`
- Original review: Cursor chat "full code review" 2026-06-11
