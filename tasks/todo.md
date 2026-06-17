# Current Task

**Objective:** Run the Post-Live D7 Readout without mutating PostHog, App Store Connect, Vercel, or backend state.
**Status:** PostHog source verified; complete D7 window pending.
**Branch:** `codex/post-live-d7-readout`
**Spec:** Post-Live D7 Readout (2026-06-17)

## Files Planned
- [x] `docs/qa/reports/post-live-d7-readout-2026-06-17.md`
- [x] `tasks/progress.md`
- [x] `tasks/session-log.md`
- [x] `tasks/todo.md`

## Implementation Checklist
- [x] Confirm PR #65 is merged into `origin/main`.
- [x] Read D7 Activation dashboard 1720819 through the connected PostHog plugin.
- [x] Record source-access result honestly.
- [x] Record live trailing 7-day iOS event/user counts from HogQL.
- [x] Record launch-anchor traffic from 2026-06-17T00:00:00Z.
- [x] Preserve confirmed launch telemetry from trusted 2026-06-17 live QA packet.
- [x] Classify dashboard hygiene actions as review-only, no deletion.
- [x] State monetization implication based on source maturity.

## Verification
- [x] `git diff --check`
- [x] Targeted reads of updated `docs/qa/reports/post-live-d7-readout-2026-06-17.md`, `tasks/progress.md`, `tasks/session-log.md`, and `tasks/todo.md`
- [x] Connected PostHog plugin read of dashboard 1720819
- [x] Live PostHog HogQL values for trailing 7-day event/user counts
- [ ] Mature activation/retention/funnel drop-off readout (blocked until first complete D7 window on 2026-06-24 from current launch anchor)
