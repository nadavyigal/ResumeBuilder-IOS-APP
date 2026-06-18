# Feature Spec — App Store Screenshot Generator

**Date:** 2026-06-05
**Status:** Approved
**Brief:** `docs/specs/drafts/app-store-screenshot-generator-brief.md`

---

## Objective

We are building a deterministic 10-scene App Store screenshot generator so that the Resumely owner can produce complete, upload-ready iPhone and iPad screenshot sets directly from the app.

## User Story

As the app owner, I want one repeatable capture workflow for all App Store screenshots so that the submitted images are polished, accurate, correctly sized, and easy to regenerate.

## Screenshot Catalog

| Slot | Headline | Product evidence shown |
|------|----------|------------------------|
| 01 | Your resume, tailored for any job | Resume plus job-description targeting and match summary |
| 02 | See exactly what's blocking you | ATS score, section breakdown, and top blockers with no truncation |
| 03 | AI edits that actually fit the role | Before/after bullet rewrite and role-specific improvements |
| 04 | Turn a weak match into a stronger resume | Before/after ATS score and optimized section status |
| 05 | Keep every fact under your control | Manual section editing, factuality guidance, and save state |
| 06 | Templates that pass ATS and impress recruiters | Template selection and realistic resume preview |
| 07 | Export a polished PDF in one tap | Designed preview, PDF export, and share-ready state |
| 08 | Expert analysis for every section | Hiring-manager review, recommendations, and suggested rewrite |
| 09 | A tailored cover letter, ready to use | Role-specific cover-letter preview with save/copy actions |
| 10 | Build the complete application package | Resume, cover letter, job link, and applied/application status |

## Acceptance Criteria

- [ ] `MarketingScreenshotSlot` contains exactly 10 ordered cases.
- [ ] Every slot has a unique headline, subline, caption, and content panel.
- [ ] Screenshot mode remains reachable only through `--marketing-screenshot --screenshot-slot N`.
- [ ] Screenshot mode makes no network, auth, analytics, StoreKit, or persistence calls.
- [ ] All displayed people, companies, jobs, and metrics are clearly fictional and contain no real personal data.
- [ ] Every marketing claim maps to behavior present in the submitted build.
- [ ] Phone and iPad use responsive compositions, not a stretched single-column layout.
- [ ] Text remains fully visible at all final export dimensions.
- [ ] The iPhone set contains 10 unique portrait PNGs at one Apple-accepted 6.9-inch size.
- [ ] The iPad set contains 10 unique portrait PNGs at one Apple-accepted 13-inch size.
- [ ] File names sort in upload order: `01-tailor.png` through `10-submit-package.png`.
- [ ] A manifest lists upload order, dimensions, captions, source simulator, and generation date.
- [ ] A validator fails for missing files, wrong dimensions, unsupported formats, or byte-identical duplicates.
- [ ] The existing `rb-aso-002` output is retained as historical evidence until the new set passes review.
- [ ] Xcode build and relevant tests pass.
- [ ] Simulator smoke captures are visually reviewed for both iPhone and iPad.

## API Changes

None. Screenshot mode must remain fully local and deterministic.

## iOS Changes

### New Files

| File | Purpose |
|------|---------|
| `Features/V2/Marketing/MarketingScreenshotCatalog.swift` | Slot metadata, fictional fixture values, and upload-safe copy |
| `Features/V2/Marketing/MarketingScreenshotPanels.swift` | Ten reusable marketing scene panels |
| `Features/V2/Marketing/MarketingScreenshotLayout.swift` | Responsive phone/tablet composition and typography metrics |
| `scripts/generate-app-store-screenshots.sh` | Build, launch, capture, normalize, and organize all outputs |
| `scripts/validate-app-store-screenshots.sh` | Validate file count, dimensions, format, and uniqueness |
| `ResumeBuilder IOS APPTests/MarketingScreenshotCatalogTests.swift` | Catalog completeness and metadata tests |

### Modified Files

| File | Change |
|------|--------|
| `Features/V2/Marketing/MarketingScreenshotView.swift` | Reduce to the shared shell and route all 10 catalog scenes |
| `ContentView.swift` | Preserve launch-argument routing; add no normal-app behavior |
| `dist/app-store-screenshots/README.md` | Document regeneration and App Store upload order |
| `docs/qa/app-store-readiness-checklist.md` | Mark iPhone and iPad screenshot requirements only after validation |

### Navigation

There is no user-facing navigation. The screenshot renderer remains a launch-argument-only root used by local release tooling.

## Technical Design

### Deterministic Rendering

- Use static `Sendable` value fixtures for all screenshot content.
- Disable animations in screenshot mode or render their final state immediately.
- Avoid dates, live clocks inside app content, asynchronous image loading, and network-backed views.
- Use system symbols and existing app assets only.
- Keep the normal app root untouched when the launch flag is absent.

### Responsive Layout

- Derive a layout class from available width: phone compact, phone large, and tablet.
- Phone scenes retain the current strong vertical composition.
- Tablet scenes use two-column or centered-card compositions with tablet-specific maximum widths.
- Use `ViewThatFits`, explicit line limits, and minimum scale factors only as safeguards; primary copy must fit at intended font sizes.
- Slot 2 must render the full ATS summary without ellipsis.

### Capture Targets

- iPhone: capture on the dedicated iPhone 11 Pro Max simulator and export at the active App Store Connect well's accepted 1242x2688 portrait resolution as an opaque RGB PNG.
- iPad: capture on a 13-inch iPad simulator and export at its native Apple-accepted portrait resolution, preferably 2064x2752.
- Use a consistent status-bar configuration before every capture.

### Output Structure

```text
dist/app-store-screenshots/app-store-v1/
  iphone-6.9/
    01-tailor.png
    ...
    10-submit-package.png
  ipad-13/
    01-tailor.png
    ...
    10-submit-package.png
  upload-manifest.md
  validation-report.txt
```

### Validation

- Check exactly 10 PNGs in each required directory.
- Check every image has the expected pixel dimensions and sRGB/RGB output.
- Hash files and fail if any images within a device set are identical.
- Confirm filenames are contiguous and match catalog order.
- Generate a contact sheet for rapid human review.
- Manually inspect all outputs for clipping, ellipses, inaccurate claims, real personal data, and visual defects.

## Development Stories

1. Story 1: Catalog and responsive architecture — M
2. Story 2: Complete 10-scene iPhone renderer — L
3. Story 3: Build the 13-inch iPad compositions — L
4. Story 4: Automate capture and validation — M
5. Story 5: Generate and approve final App Store assets — M

## Open Questions

1. Use the newest available 6.9-inch iPhone native resolution unless App Store Connect rejects it during upload.
2. Final copy review should favor accurate, concise claims over keyword-heavy captions.

## Out of Scope

- Automatic App Store Connect upload.
- Screenshot localization.
- Video previews.
- Product-page experiments or custom product pages.
- Changes to production feature behavior.
