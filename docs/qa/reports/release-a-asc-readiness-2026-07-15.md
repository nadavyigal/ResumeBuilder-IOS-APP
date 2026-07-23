# Release A — App Store Connect Readiness Report

**Date:** 2026-07-15  
**Configured version/build:** 1.4.2 (12)  
**Reviewer:** Codex  
**Result:** NOT READY

## Summary

Release A compiles and its restored-optimization smoke path works on the iPhone 17 Pro simulator: the Optimized tab visibly renders the résumé. The release is configured as `1.4.2 (12)`, so it no longer reuses the live build number. It is still not ready for an App Store Connect upload: this Mac has no Apple Distribution signing identity, the focused timeout-recovery test aborts the known XCTest host, and final signed-device and ASC metadata checks remain open. An authorized archive attempt compiled through Release code signing but selected the Apple Development profile and was stopped; no valid archive, upload, or submission exists.

## Evidence

| Check | Result | Notes |
|---|---|---|
| Debug iPhone 17 Pro simulator build | Pass | Fresh 1.4.2 (12) build, install, and launch succeeded. |
| Optimized résumé smoke | Pass | A restored completed optimization opened Optimized and displayed the rendered résumé. |
| Generic iOS Release build | Pass | `CODE_SIGNING_ALLOWED=NO` build succeeded and ran Xcode store validation. |
| Focused journey/review tests | Blocked | Apply transition passed; timeout-recovery aborted the known XCTest host with `SIGABRT`, not an assertion failure. |
| Exact 1.4.2 (12) Release build | Pass | Unsigned generic-iOS build succeeded and passed Xcode store validation; resolved plist uses the production API URL. |
| Upload-ready archive | Blocked | The authorized archive reached signing but selected Apple Development and waited on keychain access; no Apple Distribution identity/profile was available. |
| Version/build uniqueness | Pass | Project is configured as `1.4.2 (12)`, succeeding the live `1.4.1 (11)`. |
| ASC metadata and review materials | Pending | Screenshots, privacy answers, reviewer notes, release text, and the current ASC app-name/promo choices need final console confirmation. |

## Required actions before submission

1. Install/select valid Apple Distribution signing, authorize its keychain access, and create a signed archive; validate it in Organizer/App Store Connect.
3. Get the focused first-session/review tests to a clean, non-crashing pass (or formally repair/isolate the test-host defect with a repeatable green gate).
4. Run a clean-install TestFlight device acceptance journey: sign in, submit a job, verify review cards and Apply, then preview, save, and export the optimized résumé.
5. Finalize ASC metadata, screenshots, privacy disclosures, reviewer notes, and release text for the selected version.
6. Remove the Release-build warning caused by the manually supplied `UIDeviceFamily` Info.plist key.

## Recommendation

- [ ] Upload to TestFlight / App Store Connect
- [x] Fix the submission blockers first
