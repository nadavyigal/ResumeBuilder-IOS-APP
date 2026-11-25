# Work Pack — Resumely Activation Redesign (Cursor execution prompt)

Date: 2026-06-25
Owner: Nadav (founder)
Status: ready to execute

This file is a **self-contained prompt**. Paste it into Cursor (or run it section by section) to implement the full redesign end to end. Claude Code will QA the result afterward against this same document — keep it accurate as you go; don't silently deviate without updating the relevant story's notes.

---

## 0. Source of truth — read these first, in order

1. `audit/design-export-2026-06-25/DESIGN-BRIEF.md` — the business problem (activation funnel, ~81% drop at upload), audience, constraints.
2. `audit/design-export-2026-06-25/DESIGN-TOKENS.md` — the existing brand tokens. **Reuse these. Do not introduce a new color/spacing system.**
3. `audit/design-export-2026-06-25/returns/redesign-notes.md` — per-screen Why / Layout / Copy / Flags for all 16 redesigned screens. This is the actual design spec, screen by screen. Read it fully before starting Story 1.
4. `audit/design-export-2026-06-25/returns/Resumely Redesign.dc.html` — the raw hi-fi mockup (open in a browser to see exact pixel layout, colors, spacing, animation keyframes referenced in the notes). Use this to resolve any ambiguity the notes file leaves open.
5. `audit/product-design-resumebuilder-ios-2026-06-16/audit-notes.md` — original UX/accessibility audit that triggered this redesign.

---

## 1. Non-negotiable guardrails

- **Native iOS / SwiftUI only.** No new third-party UI frameworks. No new dependencies of any kind without stopping and asking first (flag it, don't add it).
- **Reuse the existing design tokens** (`Core/DesignSystem/Tokens/AppColors.swift`, `AppGradients.swift`, `AppTypography.swift`, `AppSpacing.swift`, `AppRadii.swift`, `AppShadows.swift`) and existing components (`Core/DesignSystem/Components/`). Brand colors are unchanged: `#6C63FF → #4EA8FF → #40E0D0` violet→sky→cyan, navy base `#050814`. Only add a new token if a screen genuinely needs one not already defined, and say so explicitly in your story's commit message.
- **Respect the 100pt tab-bar clearance token.** This was the #1 audit finding (content hiding behind the custom tab bar on Home). Every redesigned screen must keep primary content clear of the bottom tab bar at all Dynamic Type sizes.
- **Accessibility is not optional:** Dynamic Type, VoiceOver labels on every tappable control, Hebrew RTL mirroring (tab order, chevrons, stat order all flip — never a mixed-direction screen), and `reduced motion` fallbacks for every animation called out in the notes (scan-line sweeps, conic spinners, confetti, ring-draw/count-up → all need a static/instant fallback).
- **One story at a time, one commit (or small commit set) per story.** Do not blend stories into one giant diff — each story below should land as its own coherent change so it can be reviewed and reverted independently.
- **Backend/state flags are explicitly out of scope for this pass.** Every story below lists "Flags" — things that need new backend endpoints, new data the server doesn't return yet, or new persisted state. For each flag:
  - If the underlying capability already exists in the codebase (check first — several might, e.g. `hasResume`/`hasJob` may be derivable from existing `AppState`/`TailorViewModel` state), wire it up for real.
  - If it genuinely doesn't exist yet, **do not fake it** (no hardcoded fake scores presented as real, no copy promising a capability that isn't there). Either feature-gate the affected UI element (hide/disable with a `// TODO(backend): <flag>` comment) or use the existing demo/placeholder pattern already in the codebase, whichever keeps the screen honest. List every flag you had to stub in your story's summary.
- **Lint + build + relevant unit tests must pass before a story is considered done.** This project already has 24+ test files under `ResumeBuilder IOS APPTests/` — add tests for new ViewModels/logic you introduce (existing pattern: `XXXViewModelTests.swift`), not necessarily for pure-layout SwiftUI views.
- **No unrelated file changes.** If a story's diff touches more than the files listed for it (plus genuinely required shared-component extraction), stop and flag it before continuing.
- **After each story:** update `tasks/progress.md` with what shipped, and run the project's existing build/test commands to confirm green before moving to the next story.

---

## 2. Existing codebase map (confirmed via prior audit — verify still accurate before editing)

| Area | File |
|---|---|
| Brand colors | `ResumeBuilder IOS APP/Core/DesignSystem/Tokens/AppColors.swift` |
| Gradients | `ResumeBuilder IOS APP/Core/DesignSystem/Tokens/AppGradients.swift` |
| Typography | `ResumeBuilder IOS APP/Core/DesignSystem/Tokens/AppTypography.swift` |
| Spacing / Radii / Shadows | `ResumeBuilder IOS APP/Core/DesignSystem/Tokens/AppSpacing.swift`, `AppRadii.swift`, `AppShadows.swift` |
| Theme bridge | `ResumeBuilder IOS APP/Core/DesignSystem/Theme.swift` |
| Reusable components | `ResumeBuilder IOS APP/Core/DesignSystem/Components/` (GradientButton, GlassCard, ResumlyTabBar, TemplateThumbnail, etc.) |
| Home tab (upload entry) | `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` |
| Home/upload ViewModel | `ResumeBuilder IOS APP/ViewModels/TailorViewModel.swift` |
| Tab bar + tab enum | `ResumeBuilder IOS APP/Core/DesignSystem/Components/ResumlyTabBar.swift` |
| Me/Account tab | `ResumeBuilder IOS APP/Features/Profile/ProfileView.swift` |
| Account display model | `ResumeBuilder IOS APP/Features/V2/Profile/AccountDisplayInfo.swift` |
| Design tab (locked) | `ResumeBuilder IOS APP/Features/V2/Design/DesignTabView.swift` |
| Expert tab (locked) | `ResumeBuilder IOS APP/Features/V2/Expert/ExpertTabView.swift` |
| ATS score reveal | `ResumeBuilder IOS APP/Features/Score/ScoreResultView.swift` |
| Diagnosis view + VM | `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisView.swift`, `ResumeDiagnosisViewModel.swift` |
| Diagnosis model | `ResumeBuilder IOS APP/Models/ResumeDiagnosis.swift` |
| Issues / quick wins list | `ResumeBuilder IOS APP/Features/V2/Score/IssuesSummaryView.swift`, `QuickWinsSection.swift` |
| Loading/analyzing screen | `ResumeBuilder IOS APP/Features/V2/Home/ResumeOptimizationLoadingView.swift` |
| Fit check | `ResumeBuilder IOS APP/Features/V2/Fit/FitCheckView.swift`, `FitCheckViewModel.swift`, `FitVerdictView.swift` |
| Improve / re-score / apply fixes | `ResumeBuilder IOS APP/Features/V2/Improve/ImproveView.swift`, `ResumeBuilder IOS APP/ViewModels/ImproveViewModel.swift`, `ResumeBuilder IOS APP/ViewModels/OptimizedResumeViewModel.swift` |
| App-level state | `ResumeBuilder IOS APP/App/AppState.swift` |
| Localization manager | `ResumeBuilder IOS APP/Core/Localization/LocalizationManager.swift` |
| RTL helpers | `ResumeBuilder IOS APP/Core/Localization/ResumeRTL.swift` |
| Strings | `ResumeBuilder IOS APP/Resources/Localizable.xcstrings` |
| Tests | `ResumeBuilder IOS APPTests/` |
| Xcode project / scheme | `ResumeBuilder IOS APP.xcodeproj`, scheme "ResumeBuilder IOS APP" |

**Before editing any file above, re-read it in full** — this map was assembled by a prior audit pass and may have drifted.

---

## 3. Execution order

Implement in this order. Each story corresponds 1:1 to a section in `returns/redesign-notes.md` — re-read that section before starting.

### Story 1 — Home redesign (screen A)
**Goal:** Replace the 3-step stack with the upload-first hero + 3-chip progress path described in notes section "A — Home · first run".
**Primary file:** `HomeTabView.swift`. Reuse `TailorViewModel` state as-is (no VM changes expected — confirm).
**Acceptance:** drop-zone hero is the dominant element; progress path replaces the old step cards; all content (including the motivation strip) clears the 100pt tab-bar zone at largest Dynamic Type size; reduced-motion disables the hero glow pulse.

### Story 2 — Upload bottom sheet (screen B)
**Goal:** Insert the app-level sheet from notes section "B" between tapping Upload and the system file picker.
**New file:** `UploadSheetView.swift` (place alongside `HomeTabView.swift`). **Touches:** `HomeTabView.swift` (presents the sheet instead of calling `.fileImporter` directly), `TailorViewModel.swift` (only if new state is genuinely needed for sheet presentation — prefer local `@State` in the view first).
**Acceptance:** "Browse Files" in the sheet triggers the existing `.fileImporter`/`cachePickedFile` pipeline unchanged. "Paste résumé text" and "Try a sample résumé" rows are present; if their backend isn't ready (see flags in notes), they're visibly disabled/TODO-flagged rather than dead-tapping silently.

### Story 3 — Activation funnel: parsing → match job → analyzing → first score (screens E1-E4)
**Goal:** Build/restyle the four funnel screens per notes sections E1-E4.
**Touches:** `ResumeOptimizationLoadingView.swift` (covers E1 parsing and E3 analyzing — it already has a multi-mode enum; extend rather than duplicate), `ScoreResultView.swift` (E4 first score reveal — restyle to match the ring/sub-scores/biggest-win layout), new view for E2 (match-to-job) if one doesn't already exist in `Features/V2/Fit/` or `Features/V2/Home/` (check `FitCheckView.swift` first — it may already cover this job; restyle it rather than creating a duplicate if so).
**Acceptance:** parsing checklist binds to real parse stage callbacks (not a fake timer) with a minimum-display floor; E2's "Skip" produces a real general-rubric score (confirm `FitCheckViewModel`/ATS endpoints support no-JD scoring — if not, flag and stub honestly); E4's verdict copy is banded by score per the notes; all ring/spinner animations have reduced-motion fallbacks.

### Story 4 — Fixes list, apply & re-score (screen E5)
**Goal:** Rebuild the fixes list per notes section E5 — sticky live-score header, applied/open/pending fix card states, before/after diff block, sticky "Apply all" footer.
**Touches:** `IssuesSummaryView.swift` and/or `Features/V2/Improve/ImproveView.swift` (check which currently renders the fixes list — restyle in place), `ViewModels/ImproveViewModel.swift` (existing `rescanATS()` should drive the live re-score; do not duplicate scoring logic).
**Acceptance:** applying a fix updates the sticky header score live (optimistic local update reconciled with server re-score, never a stale number); crossing the target score triggers Story 8's S1 celebration screen.

### Story 5 — Locked tab teasers (screens C1, C2, C3)
**Goal:** Replace each tab's generic "Go to Home" empty state with the blurred-preview + 2-step-checklist teaser per notes sections C1-C3.
**New file:** `LockedTabTeaser.swift` (shared component in `Core/DesignSystem/Components/`) parameterized by preview content + copy + checklist items, per the notes' "shared component" instruction.
**Touches:** `DesignTabView.swift`, `ExpertTabView.swift`, and the Optimized tab's locked state (find it — likely in `Features/V2/Score/` or `Features/V2/Home/`, check before assuming a new file is needed).
**Acceptance:** all three locked tabs use the one shared component; checklist rows reflect real `hasResume`/`hasJob` state (derive from existing `AppState`/`TailorViewModel`, don't invent new state if it already exists); C2's template thumbnails reuse the real `TemplateThumbnail.swift` render path, not a mockup image.

### Story 6 — Me/Account redesign + RTL fix (screen D)
**Goal:** Implement the redesign per notes section D, and fix the actively-broken mixed English/Hebrew/RTL state flagged in the original audit.
**Touches:** `ProfileView.swift`, `AccountDisplayInfo.swift`, `LocalizationManager.swift` (only if the RTL environment-flip isn't already applied at the right scope — verify `layoutDirection` is applied to this entire view tree, not partially).
**Acceptance:** no screen state can render mixed English+Hebrew/mixed-direction content — verify by toggling the language picker and confirming the whole screen flips, including stat-row order and chevrons; value-prop card, stats row, and trust card all present per notes.

### Story 7 — Upload error recovery (screens R1, R2, R3)
**Goal:** Build the three recovery screens per notes sections R1-R3, generalizing R1+R2 into one parameterized `UploadFailureView` as instructed in the R2 notes.
**New files:** `UploadFailureView.swift` (parameterized by `.scannedImage` / `.wrongType` / `.tooLarge`), `ConnectionLostView.swift` (R3).
**Touches:** wherever upload/parse failures currently surface (likely `HomeTabView.swift` or `TailorViewModel.swift` — find existing error-handling path before adding a new one) and `UploadFilePreflight` (confirm it already classifies scanned-image vs wrong-type vs too-large; only extend if it doesn't).
**Acceptance:** every failure mode routes through the shared component with the same 3 recovery options (paste text / choose another file / try a sample) where the underlying capability exists; R3's "resume from saved progress" framing is only shown if local persistence of in-flight inputs genuinely survives a connection drop — otherwise ship the simpler honest fallback (full retry) per the notes' flag.

### Story 8 — Target reached + save-account handoff (screens S1, S2)
**Goal:** Build the celebration screen and the account-save sheet per notes sections S1-S2.
**New files:** `TargetReachedView.swift` (S1), `SaveAccountSheetView.swift` (S2).
**Touches:** wherever the score-crossing-target trigger should live (likely `ImproveViewModel.swift` after a re-score, wired from Story 4), `AppState.swift` (only if guest→account merge logic doesn't already exist — confirm before adding).
**Acceptance:** S1 fires once per milestone, not repeatedly; "Continue with Apple" is wired to the existing Sign-in-with-Apple capability (confirm entitlement already configured — do not add a new auth provider); "Maybe later" leaves the guest session fully intact (verify guest state survives app restart before shipping that copy as a guarantee, per the notes' flag).

---

## 4. Reporting requirements (after each story and at the end)

- Update `tasks/progress.md`: Status, Current Phase, Active Story, Last Completed Story, Next Recommended Story, Blockers, Last Validation, Last Updated date — per this repo's existing convention (see prior entries in that file).
- If any flag from a story couldn't be wired for real (backend not ready), list it explicitly in `tasks/lessons.md` under a new dated entry, not silently dropped.
- At the end of all 8 stories: run the full test suite, confirm clean build, push the branch, and either open a PR or report the branch name + commit count per this repo's session-end convention. Do not leave work local-only without saying so explicitly.
- Leave the branch/PR ready for Claude Code to QA against this document screen-by-screen.
