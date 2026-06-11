# Current Task

**Objective:** Fix real-device smoke failures where Preview & Export PDF and Submit Package fail from the shared PDF path.
**Status:** Code fix implemented on `main`; simulator Debug build and focused OptimizedResumeViewModel tests pass. Founder real-device re-smoke remains the next action.
**Branch:** `main`

## Scope
- Investigate real-device Xcode logs for PDF export and Submit Package failures
- Make PDF export resilient when WKWebView/backend download fails
- Keep Submit Package unblocked by generating a valid shareable PDF from loaded resume sections
- Verify simulator build and focused tests
- Document lesson/progress

## Checklist
- [x] Read smoke logs and identify shared PDF dependency
- [x] Add local text-layer PDF fallback for loaded optimization sections/contact data
- [x] Validate backend download payload starts with `%PDF-` before sharing
- [x] Preserve auth/payment failures instead of masking them with local fallback
- [x] Add focused local PDF signature test
- [x] Run Debug simulator build on iPhone 17 simulator
- [x] Run focused OptimizedResumeViewModel test suite on iPhone 17 simulator
- [ ] **FOUNDER ACTION**: Pull latest `main`, rebuild in Xcode, and smoke optimize → Improve ATS → Preview & Export PDF → Submit Package
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
