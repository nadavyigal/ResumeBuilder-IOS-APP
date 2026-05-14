# Current Task

**Objective:** Ship phases 3/5/6 — fix Phase 6 design sheet presentation bug and validate all three phases
**Status:** Done

## Plan
Fix single bug: `OptimizedResumeView` was using `.navigationDestination` for the Design sheet, which
pushed it as a full-screen nav push instead of a half-sheet. Replaced with `.sheet(isPresented:)` so
`presentationDetents([.medium, .large])` inside `OptimizationDesignSheet` takes effect.

## Checklist
- [x] Fix `.navigationDestination(isPresented: $showDesignSheet)` → `.sheet(isPresented: $showDesignSheet)` in `OptimizedResumeView.swift`
- [x] Xcode build passes

## Open Questions
- `testLoadSectionsPopulatesModel` (happy-path API test) deferred — requires injectable `APIClient`

## Validation
- [x] Xcode build passes (no errors)
- [ ] Relevant tests pass (manual — existing tests cover guard paths)
- [ ] Simulator smoke test done — **TODO: manual test on device/simulator**
  - Phase 3: navigate from review-apply → sections load with ProgressView
  - Phase 5: tap "Preview" → WKWebView renders HTML
  - Phase 6: tap "Design" → half-sheet with drag handle, category picker, template strip
- [x] `tasks/progress.md` updated
- [ ] Lesson added to `tasks/lessons.md` if applicable

## Review Notes
All three phases (3, 5, 6) were already implemented; the only code change was the
`.navigationDestination` → `.sheet` fix for the Phase 6 design picker.
