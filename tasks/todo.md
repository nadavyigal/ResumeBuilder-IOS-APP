# Current Task

**Objective:** Fix real-device Submit Package startup failure when company context is missing, and plan ATS/screenshot alignment work.
**Status:** Code fix implemented on `codex/fix-submit-package-missing-company`; focused OptimizedResumeViewModel tests pass. PR/publish remains next.
**Branch:** `codex/fix-submit-package-missing-company`

## Scope
- Investigate real-device Xcode logs for Submit Package not starting
- Keep Submit Package unblocked when company/role context is missing
- Add visible fallback copy and submit-stage logs
- Explain why the ATS score is low and why App Store screenshot scenes are not normal app screens
- Create plan for ATS/UI alignment work
- Verify focused tests and document lesson/progress

## Checklist
- [x] Read smoke logs and confirm Submit Package did not reach PDF/application/expert API calls
- [x] Identify missing-company disabled button root cause
- [x] Allow submit with safe role/company fallbacks
- [x] Add sheet guidance for missing role/company context
- [x] Add submit-stage logs for future Xcode smoke traces
- [x] Add focused missing-company Submit Package test
- [x] Create ATS/screenshot alignment plan
- [x] Run focused OptimizedResumeViewModel test suite on iPhone 17 simulator
- [ ] Publish PR for this fix
- [ ] **FOUNDER ACTION**: Pull merged fix, rebuild in Xcode, and smoke optimize → Improve ATS → Preview & Export PDF → Submit Package
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
