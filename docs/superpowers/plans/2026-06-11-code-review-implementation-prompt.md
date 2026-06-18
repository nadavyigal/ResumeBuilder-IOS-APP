# Implementation Prompt — Code Review Remediation

Copy everything below the line into a **new Cursor Agent session** to execute the plan.

---

## PROMPT START

You are implementing the code review remediation plan for the ResumeBuilder iOS app.

### Read first

1. Plan document: `docs/superpowers/plans/2026-06-11-code-review-remediation-plan.md`
2. Progress tracker in that file — update checkboxes as you complete work.

### Repository

`/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`

Native SwiftUI iOS client. No Stripe in this repo. Backend API is external (`API_BASE_URL`).

### Your mission

Execute the plan **in phase order** (0 → 1 → 2 → 3 → 4 → 5). Do not skip Phase 1 auth fixes. Do not enable `BackendConfig.isMonetizationEnabled` until Phase 2 StoreKit work is complete and tested.

### Rules

- **Minimal diffs** — fix only what each task requires; match existing code style.
- **Tests** — add or extend tests in `ResumeBuilder IOS APPTests/` for every behavior change in Phases 1–3.
- **No commits** unless I explicitly ask.
- **No markdown files** beyond updating the plan checkboxes and `tasks/progress.md` (one-line status).
- **Assumptions** — if DOCX policy (Phase 2.2 Option A vs B) is ambiguous, default to **Option A** (PDF-only UI) unless the plan already has a decision; state assumption before implementing.
- **Backend** — Phase 6 items are tickets only; do not invent backend code in this repo.

### Execution workflow per phase

1. State which phase you are starting.
2. List tasks you will touch (file paths from the plan).
3. Implement all tasks in that phase.
4. Run tests:
   ```bash
   xcodebuild test -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17'
   ```
5. Fix failures before moving on.
6. Update the Progress Tracker in the plan doc (`[ ]` → `[x]`).
7. Append one line to `tasks/progress.md` with phase completion summary.
8. Report:

```
CHANGES MADE:
- [file]: [what changed]

TESTS:
- [pass/fail summary]

NEXT PHASE:
- [what you'll do next unless all phases done]
```

### Phase-specific implementation notes

**Phase 1 — Auth**

- `JWTDecoder`: parse JWT payload (second segment), base64url decode, read `exp` as `TimeInterval`. No signature verification needed for expiry gating only.
- Refresh serialization: use a single `Task` coalescing pattern on `@MainActor AppState`.
- `KeychainStore`: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- `delete_account/index.ts`: remove `details` from 500 JSON; keep server logging.
- `SUPABASE_ANON_KEY`: follow `API_BASE_URL` plist/xcconfig pattern in `BackendConfig.swift`.

**Phase 2 — Upload & IAP**

- `ScanViewModel.handlePickedFile`: preserve file extension in cache path.
- StoreKit 2: `import StoreKit`; use `Product` and `VerificationResult`.
- Do not flip monetization flag.

**Phase 3 — Chat & PDF**

- `ChatViewModel.bootstrapSession`: call `ChatService.fetchActiveSession` then `refreshHistory`.
- Shared PDF validator: `%PDF-` magic bytes + HTTP 2xx.
- `improvements()` stub: remove from `ImproveViewModel.loadAnalysis` parallel fetch if no endpoint exists (preferred over shipping silent empty UI).

**Phase 4 — Perf**

- `HomeViewModel.load`: `async let` both service calls.
- Share one `APIClient` via `AppState` or `RuntimeServices` — inject into services.

**Phase 5 — Cleanup**

- Grep before deleting `MainTabView.swift` and `AppTabBar.swift`.
- Wrap Tailor debug `print()` in `#if DEBUG`.

### Finding ID reference (from review)

| ID | Summary |
|----|---------|
| B-01 | Fake StoreKit transaction IDs |
| B-02 | Refresh on every launch; sign-out on network error |
| B-03 | Concurrent refresh race |
| B-04 | Nil refresh token persisted |
| B-05 | Keychain missing accessibility attr |
| B-06 | DOCX cached as `.pdf` |
| B-07 | delete_account leaks schema in `details` |
| B-08 | Silent local PDF fallback |
| B-09 | Preview download no status/PDF check |
| B-10 | PDFExporter no magic-byte check |
| B-11 | Chat history not loaded on open |
| B-12 | No chat message length cap |
| B-13 | ATS score sends same text twice |
| B-14 | `improvements()` stub |
| B-15 | SecItemAdd status ignored |
| B-16 | Anonymous session conversion swallowed |
| B-17 | DOCX no client preflight |
| B-18 | ReceiptVerifier no validation |
| C-01 | Hardcoded Supabase anon key |
| O-01–O-10 | Performance items (see plan) |
| C-02–C-12 | Cleanup items (see plan) |

### Start command

Begin with **Phase 0** (baseline tests), then **Phase 1** in full. Continue through Phase 5 without stopping unless blocked. If blocked, name the blocker and the smallest decision needed from me.

Do not refactor unrelated code. Do not create a pull request unless I ask.

## PROMPT END
