# Smoke Test — 2026-06-02 (updated)

## Build Info
- **Date:** 2026-06-02
- **Branch:** main (HEAD `47173ea` — Merge PR #41 preview/export stability)
- **Build:** v1.0.0, build 1
- **Device:** Nadav.Yigal's iPhone (arm64)
- **iOS version:** To be confirmed on device
- **Simulator used for test suite:** iPhone 17 (iOS 26.3.1, id A24FA1E8)

---

## Code Audit Results (verified by Claude Code — 2026-06-01)

### Analytics Call Sites — ALL WIRED

| Event | Call Site | Status |
|-------|-----------|--------|
| `app_launched` | `ResumeBuilder_IOS_APPApp.swift:14` | WIRED |
| `guest_mode_started` | `ResumeBuilder_IOS_APPApp.swift:16` | WIRED |
| `resume_uploaded` | `Features/V2/Home/HomeTabView.swift:175` | WIRED |
| `job_added` | `Features/V2/Home/HomeTabView.swift:219` | WIRED |
| `free_ats_completed` | `Features/V2/Home/HomeTabView.swift:515` | WIRED |
| `sign_in_completed` | `App/AppState.swift:96` | WIRED |
| `optimization_started` | `Features/Tailor/TailorViewModel.swift:94` | WIRED |
| `optimization_completed` | `Features/Tailor/TailorViewModel.swift:144` + `HomeTabView.swift:199` | WIRED |
| `export_started` | `Core/Export/ResumeExportAction.swift:18` | WIRED |
| `export_success` | `Core/Export/ResumeExportAction.swift:22` | WIRED |
| `export_failed` | `Core/Export/ResumeExportAction.swift:37` | WIRED |

`export_success` fires on the success path of `ResumeExportAction.exportPDF()`, after `viewModel.downloadPDF(appState:)` returns a URL. It is NOT missing.

### Phase A — Pre-Smoke Build Verification (2026-06-02, Claude Code)

| Check | Result |
|-------|--------|
| Simulator build (`xcodebuild build`, iPhone 17, `CODE_SIGNING_ALLOWED=NO`) | **BUILD SUCCEEDED** (exit 0) |
| `BackendConfig.swift` — no `useMock* = true` flags | **CLEAN** |
| `API_BASE_URL` — no localhost value in pbxproj or Info.plist | **CLEAN** — not set as build key; `BackendConfig.apiBaseURL` falls back to `https://www.resumelybuilderai.com` (production) |
| `AnalyticsService.swift` — `#if DEBUG` guard on `print(...)` | **CONFIRMED** at line 149 |
| `ResumeBuilder_IOS_APP.entitlements` — `com.apple.developer.applesignin` | **PRESENT** |

### Test Suite Results

- **50/50 XCTest tests passed** (iPhone 17 simulator, iOS 26.3.1) — from 2026-06-01 run
- **5/5 Swift Testing tests passed**
- **Total: 55/55 — PASS** (58 total including subsequent fix PRs #39-#41 which added regression tests)
- Debug print confirmed: `AnalyticsService.track()` logs `"Analytics captured: <event_name>"` in `#if DEBUG` builds

---

## Device Smoke Test — REQUIRES HUMAN

The following steps must be performed manually on a real iPhone with a live account.

### Device Setup
1. Connect iPhone via USB, trust the Mac.
2. In Xcode, set scheme "ResumeBuilder IOS APP", configuration **Debug**, destination = your iPhone.
3. `Product → Clean Build Folder` (Cmd+Shift+K) if you last built from a different branch.
4. `Product → Run` (Cmd+R). If codesign fails with "resource fork" error, edit the scheme and add `DERIVED_DATA_PATH=/tmp/resumebuilder-derived` as an environment variable, then run again.
5. Keep Xcode console visible to watch for `"Analytics captured: ..."` prints.

**Analytics verification:** Use a **Debug** build only. The `#if DEBUG` print at `AnalyticsService.swift:149` logs `"Analytics captured: <event_name>"`. PostHog dashboard can supplement for Release builds.

**Test file to bring:** A text-based PDF resume exported from Word or Pages. PDFs scanned as images will be rejected by the upload preflight with a clear error message — that is expected behavior.

### Steps and Pass/Fail

| Step | Action | Expected | Analytics in console | Result |
|------|--------|----------|----------------------|--------|
| a | Force-quit app if open. Cold launch. | Home screen renders, no crash. | `Analytics captured: app_launched` | PENDING |
| b | Do NOT sign in. Observe all 5 tabs. | Tailor upload enabled; Design and Expert show locked/sign-in state; Me tab shows sign-in prompt. | `Analytics captured: guest_mode_started` | PENDING |
| c | Tap sign-in → complete Sign in with Apple. | Transitions to authenticated Home. | `Analytics captured: sign_in_completed` | PENDING |
| d | Upload your text-based PDF on the Tailor tab. | Preflight accepts the file; upload spinner appears; no "Could not read" or "422" error. | `Analytics captured: resume_uploaded` | PENDING |
| e | Paste a job description → tap Optimize (Optimization #1). | Scan animation plays. App navigates to Optimized tab. Optimization ID in console is a real UUID — not `mock-opt-*`. | `Analytics captured: optimization_started` then `optimization_completed` | PENDING |
| e2 | Return to Tailor. Upload a second PDF (can be the same file). Paste a different job description → Optimize (Optimization #2). | Optimized tab switches to the new UUID. Preview updates to reflect the new optimization. Preview logs show the new UUID, not the old one. No repeated `render-preview` calls within 2 seconds. | `Analytics captured: optimization_started` then `optimization_completed` (second pair) | PENDING |
| f | On Optimized tab, tap Export/Share. | Share sheet appears immediately (≤5 s). | `Analytics captured: export_started` | PENDING |
| g | Tap "Save to Files" or AirDrop to complete export. | Export completes; success state shown in app. | `Analytics captured: export_success` | PENDING |
| h | Open the exported file from Files app. | PDF renders; non-blank; shows candidate name and resume content. | — | PENDING |
| i | Navigate to Design tab → select a non-default template category (e.g., Modern). Then drag the spacing slider slowly. | Preview re-renders with the new template. Slider does not crash. Console shows at most one `render-preview` call per explicit tap/drag-end — no repeated storm. | — | PENDING |
| j | Tap Apply Design. Return to Optimized tab. | Apply succeeds (no error banner). Optimized preview shows updated design. | — | PENDING |
| k | Navigate to Expert tab. | Shows expert flow (if authenticated) OR locked/sign-in prompt. No crash, no blank white screen. | — | PENDING |
| l | Navigate to Me tab → tap Sign Out. | Profile clears. App returns to guest state on Home. | — | PENDING |

### PostHog Events Confirmed on Device
_Fill in after device run._

- [ ] app_launched
- [ ] guest_mode_started
- [ ] sign_in_completed
- [ ] resume_uploaded
- [ ] optimization_started
- [ ] optimization_completed (×2 — both optimization runs)
- [ ] export_started
- [ ] export_success
- [ ] export_failed (only if export fails — otherwise leave unchecked)

### Issues Found
_None identified from code audit. Device test pending._

---

## Summary

**Phase A (2026-06-02) — PASS:** Simulator build clean; no mock flags; production API URL (`https://www.resumelybuilderai.com` fallback); `#if DEBUG` analytics guard confirmed; Sign in with Apple entitlement present.

**Phase B+C:** Manual device smoke test. Connect iPhone, run Debug build, execute steps a–l above, record PASS/FAIL per row, and check off PostHog events.

**Phase D (after device run):** Update PENDING rows → PASS or FAIL. If all pass, update `tasks/progress.md` Current Phase to "TestFlight Archive Pending". If any fail, add lesson to `tasks/lessons.md` and fix item to `tasks/todo.md`.

**Blocker for A2 (Archive + TestFlight Upload):** All steps a–l must be marked PASS. A2 also requires: `POSTHOG_API_KEY` set as a Release build setting before archiving, and either an ASC API key for Fastlane or manual Xcode Organizer upload.
