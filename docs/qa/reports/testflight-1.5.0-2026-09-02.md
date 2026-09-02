# TestFlight Readiness Report

**Date:** 2026-09-02  
**Version:** 1.5.0  
**Build:** 28  
**Reviewer:** Codex  
**Result:** CONDITIONAL

## Summary

Build 28 is the release candidate for the founder-created App Store version
1.5.0. It increments past every observed 1.4.9 build and contains all four PRs
merged to `main`. Automated tests, signing, the Release archive, built-product
configuration, and bundle-hygiene checks pass. App Store distribution export is
waiting for the founder to approve macOS Keychain access to the distribution
certificate; authenticated real-device flows remain the final manual gate.

## Prerequisites

- iOS QA Checklist: ⚠️ Automated/simulator gates passed; physical-device flows outstanding (see `ios-qa-2026-09-02.md`)

## Build & Signing

| Check | Result | Notes |
|---|---|---|
| Archive succeeds | ✅ | Xcode archive and built-in store validation passed |
| Bundle ID correct | ✅ | `Resumebuilder-IOS.ResumeBuilder-IOS-APP` |
| Signing team correct | ✅ | Team `8VC4R5M425` |
| Provisioning profile valid | ⚠️ | Development archive valid; App Store export awaits Keychain approval |

## Entitlements and Configuration

| Check | Result | Notes |
|---|---|---|
| Sign in with Apple entitlement | ✅ | Present in signed archive |
| Production API base | ✅ | Present and non-local; value intentionally not recorded |
| Marketing version | ✅ | 1.5.0 |
| Build number | ✅ | 28; build 27 is observed in production telemetry |
| No debug entitlement/UI | ⚠️ | Archive uses development signing until App Store export; distribution entitlement will be rechecked on IPA |

## Core Flow Smoke Test (Real Device)

| Flow | Result | Notes |
|---|---|---|
| Cold launch | ⬜ | Founder-controlled after TestFlight processing |
| Sign in with Apple | ⬜ | Founder-controlled |
| Upload résumé / Match Score | ⬜ | Founder-controlled |
| Optimization | ⬜ | Founder-controlled |
| Application-package export | ⬜ | Founder-controlled |
| Sign out | ⬜ | Founder-controlled |

## Data / Privacy

| Check | Result | Notes |
|---|---|---|
| No test credentials or private keys in repository/binary | ✅ | No private-key/test-secret pattern found; Supabase anon and PostHog client keys are expected public client configuration |
| API points to production | ✅ | Built plist contains a non-local endpoint |
| No internal troubleshooting documents in bundle | ✅ | 11 unintended Markdown resources removed; clean archive count is zero |
| No sensitive token logging | ✅ | The only token-related preview logs say that no token exists; no token value is printed |
| No debug UI in Release | ✅ | Release compilation has no `DEBUG` define; simulator smoke shows normal product UI |

## What's New (English U.S.)

- Export your résumé, existing cover letter, and screening answers together as one application package.
- More reliable Match Score handling, including safer processing of unusual score values.
- Export and stability improvements.

## Known Issues / Manual Gate

- The authenticated physical-device journey must pass on the processed TestFlight build before App Review submission.
- Hebrew/RTL is not claimed as newly supported in this release.

## Recommendation

- [x] Upload to TestFlight after approving the macOS Keychain certificate prompt
- [x] Run the founder-controlled physical-device smoke on the processed build before App Review submission
- [ ] Fix blockers first
