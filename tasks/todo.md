# Current Task

**Objective:** Dev Story 1 — Fix Preview Rendering (Issues 1, 2, 3)
**Status:** Done
**Spec:** `docs/specs/drafts/core-output-quality-spec.md`

## Plan
Two surgical fixes:
1. `ResumePreviewWebView`: pass `resumeData: nil` instead of calling `resumeDataForPreview()`, delete the two dead helpers
2. `ResumeDesignService.applyCustomization`: change `!= false` → `== true` to avoid treating `nil` as success

## Checklist
- [x] `resumeData: resumeDataForPreview()` → `resumeData: nil` in `renderPreview()`
- [x] Delete `resumeDataForPreview()` method (lines 136–168)
- [x] Delete `nonEmptyLines(in:)` helper (lines 170–175)
- [x] `response.success != false` → `response.success == true` in `applyCustomization`
- [x] Xcode build passes (no errors)
- [x] All tests pass

## Validation
- [x] Xcode build passes (** BUILD SUCCEEDED **)
- [x] All tests pass (14 tests, 0 failures)
- [ ] Simulator smoke test — **TODO: manual test**
  - Preview shows user's real name and title
  - Experience entries show job titles, companies, dates
  - PDF download matches preview HTML
