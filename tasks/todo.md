# Current Task

**Objective:** Ship a full Hebrew version of the Resumely iOS app (native UI strings + language picker + RTL resume preview/PDF + Hebrew App Store metadata).
**Status:** Stories 1-6 complete; user actions pending (ASC submission, real-device QA)
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

## Story 2 — Translate natural-language keys to Hebrew ✅
- [x] Author Hebrew for all 360 catalog keys (terminology aligned to web `he.json`)
- [x] Preserve positional format specifiers (%1$@, %2$lld) exactly; same count/order
- [x] Leave brand tokens (Resumely, ATS, PDF, LinkedIn) untranslated
- [x] Core-flow sweep (Story 2.5): converted plain-String component/VM labels to
      LocalizedStringKey + added Hebrew for 133 newly-exposed labels. Home fully Hebrew.

## Story 3 — Language picker in Me tab ✅
- [x] Add English / עברית segmented Picker in `Features/Profile/ProfileView.swift` bound to LocalizationManager
- [x] Localize Profile chrome (section titles, stat labels, row labels) to LocalizedStringKey
- [x] Verified: picker renders both options + reflects current selection; persisted
      choice drives language+direction across relaunch (en→LTR English, he→RTL Hebrew)

## Story 4 — RTL resume preview + PDF ✅
- [x] Add optional `locale` to `RenderPreviewRequest`; send app language (he/en)
- [x] Client-side RTL post-processing (`ResumeHTMLDirection.applyRTL`) injects
      `dir="rtl"` + RTL CSS on backend HTML when résumé content is Hebrew (robust
      regardless of backend locale support)
- [x] Local fallback template emits `<html dir="rtl">`, RTL CSS, Hebrew font stack
- [x] `LocalResumePDFExporter` direct-draw path: right alignment + RTL writing dir
- [x] PDF export inherits the RTL HTML via WKWebView.createPDF
- [x] Verified: 10/10 RTL-logic unit checks; Hebrew résumé HTML renders correct
      RTL in WKWebView (headers right-aligned, bullets on right, Hebrew font, bidi)
- Note: direction derived from résumé CONTENT (Hebrew chars), not UI language, so
  English résumé never forced RTL. Full backend-auth Hebrew-resume device QA still
  recommended on real hardware per strategy doc.

## Story 5 — Hebrew App Store metadata ✅ (prep — ASC submission is manual)
- [x] Mirror canonical Hebrew listing into `docs/app-store/he-metadata.md`
      (name/subtitle/keywords/promo/description) + iOS submission checklist
- [x] Document Hebrew screenshot generation (launch with -AppleLanguages he)
- [x] No fastlane added (kept dependency-free per rules)
- [ ] USER ACTION: paste into App Store Connect Hebrew localization + submit

## Story 6 — 100% Hebrew coverage sweep ✅ (on branch version-2)
- [x] Convert ALL remaining plain-String UI surfaces: model/VM/enum computed
      labels, error messages, empty states, loading text, ATS insight content,
      diagnosis fallbacks, expert metadata, purchase/auth errors → NSLocalizedString
      (works in Text + HTML + PDF via the Bundle.main swizzle)
- [x] Convert remaining String-param components → LocalizedStringKey
      (GuidanceListView, IssuesSummaryView pillars)
- [x] Authoritative coverage check via `xcodebuild -exportLocalizations`:
      688/688 user-facing strings now have Hebrew (the only untranslated item is
      the auto-generated InfoPlist bundle name "Resumely", identical in both langs)
- [x] BUILD SUCCEEDED; preview-only sample()/#Preview demo data intentionally skipped

## Verification
- [x] Build SUCCEEDED (app target) after every story
- [x] Full test suite: all 88 tests pass, 0 failures (the `TEST FAILED` is a
      pre-existing host-teardown malloc crash — identical on the base commit)
- [x] No test edits needed (locale field is optional/defaulted; mock unchanged)
- [x] QA: Home/Profile each rendered in Hebrew RTL + English LTR on simulator;
      Hebrew résumé HTML renders correct RTL in WKWebView
- [ ] USER ACTION (per strategy doc): real-device QA of a backend-authenticated
      Hebrew résumé → preview + PDF
