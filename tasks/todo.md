# Current Task

**Objective:** Ship a full Hebrew version of the Resumely iOS app (native UI strings + language picker + RTL resume preview/PDF + Hebrew App Store metadata).
**Status:** Story 1 in progress
**Branch:** `claude/relaxed-northcutt-cb6240`
**Plan:** Hebrew Version of Resumely (5 stories)

## Verified current state
- App target uses fileSystemSynchronizedGroups → new Swift files auto-compile.
- App uses explicit `Config/Info.plist` (GENERATE_INFOPLIST_FILE = NO).
- `knownRegions = (en, Base)`; `developmentRegion = en`. No `he`.
- Catalog `Localizable.xcstrings`: 360 keys; UI uses natural-language `Text("...")` literals resolved through the catalog. Only 16 *symbolic* keys (tab_home, app_name…) have Hebrew, and those symbolic keys are NOT referenced in code. Real translation work = the natural-language keys.
- No `String(localized:)` / no existing localization helper anywhere.

## Story 1 — Hebrew + language infrastructure ✅
- [x] Add `he` to `knownRegions` in project.pbxproj
- [x] Add `CFBundleLocalizations` (en, he) to `Config/Info.plist`
- [x] Create `Core/Localization/LocalizationManager.swift` (@Observable @MainActor singleton; auto-detect device Hebrew on first launch; persist explicit choice in UserDefaults)
- [x] Create `Core/Localization/Bundle+Localization.swift` (bundle-override pattern, nonisolated class for Swift 6)
- [x] Wire `.environment(\.locale)` + `.environment(\.layoutDirection)` at root in `ResumeBuilder_IOS_APPApp.swift`
- [x] BUILD SUCCEEDED; he.lproj compiled; app launches in Hebrew without crash

## Story 2 — Translate natural-language keys to Hebrew
- [ ] Author Hebrew for all UI keys (terminology aligned to web `he.json`)
- [ ] Preserve format specifiers (%@, %lld) exactly; same count/order
- [ ] Leave brand tokens (Resumely, Stripe, ATS) untranslated where web does

## Story 3 — Language picker in Me tab
- [ ] Add English / עברית control in `Features/Profile/ProfileView.swift` calling LocalizationManager
- [ ] Switch live + persist across relaunch

## Story 4 — RTL resume preview + PDF (device QA)
- [ ] Add optional `locale` to `RenderPreviewRequest`; send `he` when app is Hebrew
- [ ] Verify backend honors locale; else inject `dir="rtl"` + RTL CSS client-side
- [ ] Local fallback template: `<html dir="rtl">`, RTL CSS, Hebrew-capable font
- [ ] PDF export inherits RTL; verify A4 layout/margins
- [ ] Device QA: Hebrew resume → preview RTL → PDF RTL

## Story 5 — Hebrew App Store metadata
- [ ] Prepare he listing (name/subtitle/description/keywords) + Hebrew screenshots
- [ ] (fastlane deliver only with explicit approval)

## Verification
- [ ] Build + unit tests in `ResumeBuilder IOS APPTests`
- [ ] Update affected tests (LiveEndpointStabilizationTests, PDFDownloadValidatorTests)
- [ ] QA matrix: each tab × {English LTR, Hebrew RTL}; PDF on real device
