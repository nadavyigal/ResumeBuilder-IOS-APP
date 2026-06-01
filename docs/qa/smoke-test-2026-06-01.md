# Smoke Test — 2026-06-01

## Build Info
- **Date:** 2026-06-01
- **Branch:** claude/hungry-engelbart-faa58a (ship sprint on top of main / PR #36)
- **Build:** v1.0.0, build 1
- **Device:** Nadav.Yigal's iPhone (arm64, connected — confirmed in `xcodebuild -list`)
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

### Test Suite Results

- **50/50 XCTest tests passed** (iPhone 17 simulator, iOS 26.3.1)
- **5/5 Swift Testing tests passed**
- **Total: 55/55 — PASS**
- No crashes, no restarts
- Debug print added: `AnalyticsService.track()` now logs `"Analytics captured: <event_name>"` in `#if DEBUG` builds

**Note on test fixes applied (pre-existing crash, not caused by this session):**
Root cause: Synchronous `@MainActor` XCTest methods calling `@Observable @MainActor` objects crashed the test runner via ObjC runtime / Swift concurrency mismatch. Fixed by adding `async` to 26 affected test functions in ExpertReportParsingTests, OptimizedResumeViewModelTests, and RuntimeServicesTests. Logic unchanged.

---

## Device Smoke Test — REQUIRES HUMAN

The following steps must be performed manually on a real iPhone with a live account.

**To see analytics events in Xcode console:** Use a **Debug** build (not Release). The `#if DEBUG` print logs `"Analytics captured: <event_name>"`. For Release builds, verify events via the PostHog dashboard instead.

### Steps and Pass/Fail

| Step | Action | Expected | Result |
|------|--------|----------|--------|
| a | Cold launch | `app_launched` fires in console | PENDING |
| b | Guest mode (no sign-in) | `guest_mode_started` fires | PENDING |
| c | Sign in with Apple | `sign_in_completed` fires | PENDING |
| d | Upload a text-based PDF resume | `resume_uploaded` fires; preflight accepts it | PENDING |
| e | Paste job description → tap Optimize | `optimization_started` + `optimization_completed` fire | PENDING |
| f | Tap Export | `export_started` fires | PENDING |
| g | Complete export | `export_success` fires | PENDING |
| h | Exported PDF opens correctly | PDF renders, non-blank | PENDING |
| i | Navigate to Design tab → select template | Preview renders, no blank screen | PENDING |
| j | Navigate to Expert tab | Locked state shows OR expert flow works | PENDING |
| k | Navigate to Me tab → sign out | Profile shows correctly, sign-out works | PENDING |

### PostHog Events Confirmed on Device
_To be filled in after device run._

- [ ] app_launched
- [ ] guest_mode_started
- [ ] sign_in_completed
- [ ] resume_uploaded
- [ ] optimization_started
- [ ] optimization_completed
- [ ] export_started
- [ ] export_success (was previously unconfirmed — code is wired)
- [ ] export_failed (only if export fails)

### Issues Found
_None identified from code audit. Device test pending._

---

## Summary

**Code-verified:** All 11 analytics events are wired to live call sites. `export_success` is confirmed present at `ResumeExportAction.swift:22`. Tests 55/55 pass.

**Pending:** Manual device smoke test. Once the device run is complete, fill in the PENDING rows above and confirm PostHog events in the dashboard.

**Blocker for A2:** This smoke test must be completed and all steps marked PASS before proceeding to A2 (Archive + Upload).
