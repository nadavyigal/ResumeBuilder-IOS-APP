# Current Task

**Objective:** WP-1 — Authenticated real-device smoke, PostHog live-event verification, and ASC upload path resolution before App Store Connect upload.
**Status:** Partially complete — build + analytics fix done; device smoke requires founder action (device was locked during session)
**Branch:** `main`

## Scope
- Fix POSTHOG_API_KEY not reaching Info.plist (blocked analytics from firing)
- Build a signed device binary with PostHog key embedded
- Install on physical iPhone 13 and smoke the core path
- Verify PostHog Live Events receives app_launched, optimization_completed, export_success
- Resolve ASC upload path (EXD-006)

## Checklist
- [x] Read AGENTS.md, CLAUDE.md, progress.md, todo.md, session-log.md, lessons.md
- [x] Diagnose PostHog key not reaching Info.plist (INFOPLIST_KEY_* limitation for custom keys in Xcode 26.5)
- [x] Fix: add Run Script build phase (PlistBuddy) to inject POSTHOG_API_KEY + POSTHOG_HOST after GENERATE_INFOPLIST_FILE
- [x] Verify key in simulator build Info.plist: POSTHOG_API_KEY = phc_*** (see Secrets.xcconfig)
- [x] Build signed device binary (Debug-iphoneos) — BUILD SUCCEEDED
- [x] Verify key in device build Info.plist — confirmed
- [x] Update broken analytics test (testDisabledAnalyticsDoesNotRequireTransport → testServiceIsEnabledWhenTransportIsProvided)
- [x] Run full test suite — all XCTest + 5 Swift Testing tests pass
- [x] Simulate app launch on iPhone 17 simulator — Home screen renders correctly
- [x] Resolve ASC upload path: Fastlane NOT installed, no ASC API key (.p8) found → manual Xcode Organizer path
- [ ] **FOUNDER ACTION REQUIRED**: Unlock iPhone 13 → install device build → authenticate → run optimize → design → expert → export → screenshot each step
- [ ] **FOUNDER ACTION REQUIRED**: Screenshot PostHog Live Events showing app_launched, optimization_completed, export_success
- [ ] **FOUNDER ACTION REQUIRED**: Verify export PDF renders correctly on device

## Device Install Command (run when device is unlocked)
```bash
xcrun devicectl device install app \
  --device 4A1D6EF2-8945-55B8-931A-46980B2A27E2 \
  "/var/tmp/resumebuilder-device-derived/Build/Products/Debug-iphoneos/ResumeBuilder IOS APP.app"
```
Or simply open Xcode → Product → Run with the iPhone 13 selected as destination.

## ASC Upload Path (EXD-006)
- Fastlane: NOT installed (no Fastfile, no gem, not in PATH)
- ASC API key (.p8): NOT found anywhere on the machine
- **Conclusion: Manual upload path via Xcode Organizer**
  1. In Xcode: Product → Archive
  2. Window → Organizer → select the archive
  3. Distribute App → App Store Connect → Upload
  4. Follow the prompts (uses the Apple Distribution certificate already on keychain)
