# Current Task

**Objective:** WP-1 — Release-readiness committed; device smoke + PostHog live-event verification remain as founder actions before ASC upload.
**Status:** Code/build/tests complete. All founder-action items below are unblocked.
**Branch:** `claude/tender-banach-89238f`

## Scope
- Apply App Store readiness fixes (Inject Runtime Config, BackendConfig, warning cleanup, bundle exclusions)
- Verify clean build with API_BASE_URL + POSTHOG keys in Info.plist
- Run full test suite
- Build signed device binary
- Resolve ASC upload path (EXD-006)
- Document founder device smoke steps

## Checklist
- [x] Apply Inject Runtime Config build script (API_BASE_URL + POSTHOG_API_KEY + POSTHOG_HOST via PlistBuddy)
- [x] BackendConfig.swift uses preconditionFailure; no hardcoded fallback URL
- [x] TailorView.swift deprecated onChange fixed; ImproveViewModel.swift guard-let warnings fixed
- [x] Secrets.swift.example excluded from app bundle (PBXFileSystemSynchronizedBuildFileExceptionSet)
- [x] API_BASE_URL = https://www.resumelybuilderai.com in Debug + Release build settings
- [x] Verify API_BASE_URL + POSTHOG_API_KEY + POSTHOG_HOST in simulator Debug Info.plist — confirmed
- [x] Full test suite: 72 XCTest passed (0 failures) on iPhone 17 simulator
- [x] Simulator smoke — Home screen renders (screenshot: /var/tmp/resumebuilder-smoke-wt/wp1-home.png)
- [x] Device binary (Debug-iphoneos) built and signed — all 3 Info.plist keys confirmed
- [x] ASC upload path resolved: Fastlane NOT installed, no .p8 key → manual Xcode Organizer
- [ ] **FOUNDER ACTION**: Install device binary on real device (see command below)
- [ ] **FOUNDER ACTION**: Sign in, run optimize → design → expert → export; screenshot each step
- [ ] **FOUNDER ACTION**: Screenshot PostHog Live Events showing app_launched + optimization_completed + export_success
- [ ] **FOUNDER ACTION**: Confirm export PDF renders correctly
- [ ] **FOUNDER ACTION**: Create Release archive via Xcode Organizer → Distribute App → App Store Connect

## Device Install Command
Open the worktree in Xcode with your device connected, then Product → Run.
Or via terminal when device is trusted and unlocked:
```bash
xcrun devicectl device install app \
  --device <YOUR-DEVICE-UDID> \
  "/var/tmp/resumebuilder-device-wt/Build/Products/Debug-iphoneos/ResumeBuilder IOS APP.app"
```

## ASC Upload Path (EXD-006 resolved)
- Fastlane: NOT installed (no Fastfile, no gem, not in PATH)
- ASC API key (.p8): NOT present on this machine
- **Path: Manual Xcode Organizer**
  1. Xcode: Product → Archive (uses Release config + automatic signing)
  2. Window → Organizer → select archive
  3. Distribute App → App Store Connect → Upload
  4. Authorize Apple Distribution key access in Keychain when prompted
  5. Complete upload in Xcode — no .p8 file needed for GUI upload
