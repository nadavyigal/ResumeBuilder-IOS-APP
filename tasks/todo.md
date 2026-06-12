# Current Task

**Objective:** Fix Submit Package so it includes the optimization job link and Expert cover letter, asks the user to save the package, and persists it to Me for export or direct job-link submission.
**Status:** Implemented locally; focused iPhone 17 tests and launch smoke passed.
**Branch:** `codex/fix-submit-package-save-package`

## Scope
- Refresh optimization context before package generation so the job link is present when available
- Generate a reviewable Submit Package draft before creating a Me application
- Save to Me only after explicit user confirmation
- Persist optimized resume attachment, job link, cover letter Expert report, and screening answers
- Keep Me/Application Detail actions for PDF share, cover-letter copy, and job-link submission

## Checklist
- [x] Investigate PR #46 and confirm it is unrelated RunSmart code review remediation
- [x] Split Create Package from Save Package to Me
- [x] Add job-link alias `job_url` to application create requests
- [x] Update Submit Package sheet copy/actions
- [x] Update Me package hub job-link CTA
- [x] Add focused unit coverage for draft generation and save-to-Me persistence
- [x] Move untracked duplicate `* 2.swift` artifacts out of synchronized source folders
- [x] Run `git diff --check`
- [x] Run focused iPhone 17 `OptimizedResumeViewModelTests`
- [x] Run iPhone 17 simulator launch smoke
- [x] Push branch and open PR #57
- [ ] **FOUNDER ACTION**: Pull branch/PR, rebuild in Xcode, and real-device smoke optimize → Improve ATS → Preview & Export PDF → Submit Package → Save Package to Me → Me package actions

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
