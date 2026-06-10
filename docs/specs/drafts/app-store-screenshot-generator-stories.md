# Development Stories — App Store Screenshot Generator

**Date:** 2026-06-05
**Status:** Draft
**Spec:** `docs/specs/drafts/app-store-screenshot-generator-spec.md`

---

## Story 1 — Catalog and Responsive Architecture

**Size:** M

### Objective

Create a testable 10-slot catalog and responsive screenshot shell without changing normal app behavior.

### Files

- Create `Features/V2/Marketing/MarketingScreenshotCatalog.swift`
- Create `Features/V2/Marketing/MarketingScreenshotLayout.swift`
- Modify `Features/V2/Marketing/MarketingScreenshotView.swift`
- Create `ResumeBuilder IOS APPTests/MarketingScreenshotCatalogTests.swift`

### Acceptance Criteria

- [ ] Exactly 10 ordered slots are addressable by launch argument.
- [ ] Every slot has non-empty unique metadata.
- [ ] Invalid or missing slot values safely fall back to slot 1.
- [ ] Phone and tablet layout classes are covered by focused tests.
- [ ] Normal launch still opens `RootView`.
- [ ] Build and tests pass.

---

## Story 2 — Complete 10-Scene iPhone Renderer

**Size:** L

### Objective

Implement and visually verify all 10 unique iPhone scenes in the existing polished style.

### Files

- Create `Features/V2/Marketing/MarketingScreenshotPanels.swift`
- Modify `Features/V2/Marketing/MarketingScreenshotView.swift`

### Acceptance Criteria

- [ ] Existing slots 1–5 are refined and slot 2 has no truncation.
- [ ] New slots 6–10 accurately represent shipped functionality.
- [ ] No scene requires network, login, or live data.
- [ ] No scene contains real personal information.
- [ ] Every scene is visually distinct and legible on the 6.9-inch target.
- [ ] Simulator smoke captures for slots 1–10 pass visual review.

---

## Story 3 — Build 13-Inch iPad Compositions

**Size:** L

### Objective

Provide tablet-specific compositions for all 10 scenes so the iPad set is polished rather than stretched.

### Files

- Modify `Features/V2/Marketing/MarketingScreenshotLayout.swift`
- Modify `Features/V2/Marketing/MarketingScreenshotPanels.swift`
- Modify `Features/V2/Marketing/MarketingScreenshotView.swift`

### Acceptance Criteria

- [ ] All 10 scenes render at an accepted 13-inch iPad portrait resolution.
- [ ] Tablet scenes use deliberate two-column or constrained layouts.
- [ ] No text truncates or becomes excessively wide.
- [ ] Cards and resume previews retain readable proportions.
- [ ] Simulator smoke captures for slots 1–10 pass visual review.

---

## Story 4 — Automate Capture and Validation

**Size:** M

### Objective

Create one repeatable command that generates and validates the complete iPhone and iPad screenshot package.

### Files

- Create `scripts/generate-app-store-screenshots.sh`
- Create `scripts/validate-app-store-screenshots.sh`
- Modify `dist/app-store-screenshots/README.md`

### Acceptance Criteria

- [ ] Script builds the current scheme once per simulator target.
- [ ] Script launches and captures slots 1–10 for iPhone and iPad.
- [ ] Output filenames are ordered and upload-ready.
- [ ] Validation fails on wrong counts, dimensions, formats, or duplicate hashes.
- [ ] Capture failures stop the script with an actionable message.
- [ ] A contact sheet and manifest are generated.

---

## Story 5 — Generate and Approve Final Assets

**Size:** M

### Objective

Generate the final 20 files, perform visual QA, and replace the old set as the recommended App Store package.

### Files

- Create `dist/app-store-screenshots/app-store-v1/iphone-6.9/*.png`
- Create `dist/app-store-screenshots/app-store-v1/ipad-13/*.png`
- Create `dist/app-store-screenshots/app-store-v1/upload-manifest.md`
- Create `dist/app-store-screenshots/app-store-v1/validation-report.txt`
- Modify `docs/qa/app-store-readiness-checklist.md`
- Update `tasks/todo.md` and `tasks/progress.md`

### Acceptance Criteria

- [ ] Both device directories contain 10 unique validated PNGs.
- [ ] All 20 images pass human visual inspection at full resolution.
- [ ] Copy accurately reflects the submitted v1.0 build.
- [ ] No clipping, ellipses, private data, placeholders, or debug UI remain.
- [ ] The manifest gives exact drag-and-drop order for App Store Connect.
- [ ] Xcode build and relevant tests pass.
- [ ] The historical `rb-aso-002` folder is not deleted until approval.
