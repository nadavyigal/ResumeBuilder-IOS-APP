# Current Task

**Objective:** Dev Story 3 — Fix Expert Apply Ordering (Issue 4)
**Status:** Done
**Spec:** `docs/specs/drafts/core-output-quality-spec.md`

## Plan
Swap `mergeExpertApply` and `forceReloadSections` ordering in `ExpertModesViewModel.apply`.
- Call `mergeExpertApply` first (immediate optimistic update visible to user)
- Fire `forceReloadSections` in a background `Task` (non-blocking server sync)

## Checklist
- [x] Swap order: `mergeExpertApply` before `forceReloadSections` in `apply(_:token:appState:)`
- [x] Wrap `forceReloadSections` in `Task { }` so it does not block the apply call
- [x] Xcode build passes (no errors)

## Validation
- [x] Xcode build passes (** BUILD SUCCEEDED **)
- [ ] Simulator smoke test — **TODO: manual test**
  - Tap Apply on Summary Lab → Professional Summary updates immediately in OptimizedResumeView
  - Tap Apply on Full Resume Rewrite → all section bodies update immediately
  - Tap Apply on Achievement Quantifier → Experience bullets update immediately
  - Cover Letter apply shows saved toast (no section change expected)
