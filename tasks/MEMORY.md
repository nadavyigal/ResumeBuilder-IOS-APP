## 2026-05-20 — Post-PR-19 Device Bug Fix Pass

**Worked on:** 4 device bug fixes identified from physical iPhone smoke test after PR #19 merge.

**Completed:**
- Story 1: Added `template_id` to `.designCustomize` POST body in `ResumeDesignService.swift` (fixes 400 error on Apply Design)
- Story 2: Per-template accent colors in `MiniResumeCanvas` via djb2 hash of `templateId` — 8-color palette, all 4 callers updated
- Story 3: `AppState.resumeSectionsNeedRefresh` flag wires Expert apply → Optimized tab force-reload (1.5s delay for backend commit)
- Story 4: `enhancedError()` in `TailorViewModel` appends actionable tip when server error contains "read"+"pdf"
- Build succeeds, all unit tests pass (iPhone 17 simulator)
- Note: `MockResumeLibraryService.downloadResumePDF()` already had text layer from PR #19 — Part A of Story 4 was pre-done

**In progress:** Awaiting user choice on merge/PR/discard (finishing-a-development-branch menu presented).

**Decisions:** Used djb2 hash (not Swift's `hashValue`) for stable per-template color; `resumeSectionsNeedRefresh` fires unconditionally from expert apply (also works from Track tab).

**Next session:** User to pick merge option. If PR: branch is `claude/funny-khayyam-3f7053`, 8 files changed, all uncommitted.
