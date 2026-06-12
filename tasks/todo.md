# Current Task

**Objective:** Archive v1.0 (4) from `main` and resubmit to App Store review.
**Status:** Code gates cleared; founder archives in Xcode.
**Branch:** `main`

## Pre-Archive (done in repo)
- [x] Commit string catalog + build 4 bump
- [x] Merge PR #57 to `main`
- [x] App Review notes in `docs/qa/app-store-readiness-checklist.md`
- [x] Screenshot upload paths documented (`iphone-6.7/`, `ipad-13/`)

## Founder — Archive & ASC
- [ ] Xcode: confirm branch `main`, Product → Clean Build Folder
- [ ] Product → Archive → Validate → Distribute → App Store Connect → Upload
- [ ] ASC: upload screenshots from `dist/app-store-screenshots/rb-aso-002/` (see upload-manifest)
- [ ] ASC: paste App Review notes + demo email/password from checklist
- [ ] ASC: select build **1.0 (4)** → Submit for Review

## ASC Upload Path
1. Xcode: Product → Archive
2. Organizer → Distribute App → App Store Connect → Upload
3. Authorize Apple Distribution key in Keychain when prompted
