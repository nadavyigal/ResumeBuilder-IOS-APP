# WP-13 Fit-First Live Smoke — 2026-06-23

**Branch:** `feat/wp-13-fit-check-internal` (`isFitCheckEnabled=true`)  
**Host:** iPhone 17 Simulator (xcodebuild test)  
**Endpoint:** `POST https://www.resumelybuilderai.com/api/public/ats-check` (live, not mock)

## Result: PASS

| Check | Status | Evidence |
|-------|--------|----------|
| Live HTTP call | PASS | `[APIClient] HTTP response status=200 bytes=3143` |
| Verdict decode | PASS | `HTTP decode success for ats-check`; `testLiveFitCheckEndToEndAgainstProduction` passed |
| Optimize handoff | PASS | `onOptimize` received trimmed JD |
| EXD-012 score note | PASS | Asserted process-descriptive ("estimated" / "fit" in scoreNote) |
| Analytics: `fit_check_started` | PASS | `Analytics captured: fit_check_started` |
| Analytics: `fit_check_completed` | PASS | `Analytics captured: fit_check_completed` |
| Analytics: `fit_check_optimize_tapped` | PASS | `Analytics captured: fit_check_optimize_tapped` |
| Analytics: `fit_check_skipped` | PASS | `Analytics captured: fit_check_skipped` |
| Hebrew RTL strings | PASS | `testHebrewFitCheckStringsResolveRTL` — layoutDirection `.rightToLeft`, localized strings ≠ English keys |

## Command

```bash
xcodebuild test \
  -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:"ResumeBuilder IOS APPTests/FitCheckViewModelTests/testLiveFitCheckEndToEndAgainstProduction" \
  -only-testing:"ResumeBuilder IOS APPTests/FitCheckViewModelTests/testHebrewFitCheckStringsResolveRTL"
```

**TEST SUCCEEDED** — 2 tests, 0 failures (~15.5s for live endpoint test).

## Notes

- Fit check latency ~15s on live endpoint (acceptable for smoke; monitor in production).
- Public release build uses `release/wp-13-v1.1-build-6` with `isFitCheckEnabled=false`.
