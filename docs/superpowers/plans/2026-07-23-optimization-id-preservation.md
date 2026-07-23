# Optimization ID Preservation (WP-53)

## Status

Implemented and verified on `codex/wp-53-optimization-id-preservation`.

This is the active plan. Two proposals from the original draft were rejected
during review and are intentionally omitted:

- Do not preserve a local ID after a successful authoritative history response
  says no recoverable optimization exists. That could unlock stale or deleted
  state.
- Do not rewrite the existing apply-body rejection as a thrown error. The
  current path already surfaces the server message, emits one failure event,
  leaves `applySuccessOptimizationId` nil, and does not navigate.

## Goal

Prevent a transient optimization-history failure from permanently deleting the
user's persisted `latestOptimizationId`, while ensuring late recovery responses
cannot overwrite a newer optimization or restore state after sign-out.

## Root Cause

`AppState.reconcileLatestOptimization()` cleared `latestOptimizationId` before
its awaited history request. The property's setter writes through to
`UserDefaults`, so a network failure permanently removed the identifier. The
Optimized tab then rendered its locked state even though the user had completed
an optimization.

The first implementation review exposed a second race: while the history request
was suspended, sign-out or a newer optimization could change state. A late
success or failure could then apply the captured result to the wrong state.

## Causal Chain

```text
history fetch throws
  → persisted latestOptimizationId was already cleared
  → catch did not restore it
  → OptimizedResumeTabView could not create its view model
  → preview and export became unavailable
```

## Approved Implementation

### AppState recovery

- Keep the persisted ID while the history request is in flight.
- Capture the authenticated user, optimization ID, and recovery generation
  before awaiting the request.
- Discard every late success, empty result, or failure when that captured state
  is no longer current.
- Increment the generation when the session or optimization ID changes.
- Restore the captured ID on a current-request failure.
- Preserve the existing authoritative success behavior:
  - keep the matching completed item;
  - otherwise recover the newest completed item;
  - clear state when the successful response contains no recoverable item.

### Apply rejection

- Keep production behavior unchanged.
- Regression-test that a successful HTTP response containing an error body
  displays the error, keeps the selection retryable, and does not report apply
  success.

## Files

| File | Responsibility |
|---|---|
| `ResumeBuilder IOS APP/App/AppState.swift` | Persisted optimization state, recovery generation, and stale-result guards |
| `ResumeBuilder IOS APPTests/FirstSessionJourneyTests.swift` | Failure persistence and suspended-request race coverage |
| `ResumeBuilder IOS APPTests/ResumeOptimizationParsingTests.swift` | Existing apply-body rejection contract |
| `tasks/lessons.md` | Persistent-state and async-recovery rules |
| `tasks/progress.md` | Current release and hotfix status |
| `tasks/session-log.md` | Implementation and verification handoff |
| `tasks/todo.md` | Remaining merge, release, and physical-device gates |

## Verification

- Red regression observed before the fix: both in-memory and persisted IDs
  became `nil`.
- Focused recovery and optimization suites pass on iOS 26.5.
- Full suite passes with only the intentional live-fixture skip.
- Unsigned generic-iOS Release build succeeds.
- Debug simulator build, install, launch, accessibility snapshot, and screenshot
  smoke pass.

## Remaining Release Gate

After merge and hotfix release, run an authenticated physical-device regression:

1. Complete an optimization and confirm preview/export are available.
2. Terminate the app.
3. Force the history request offline.
4. Relaunch and open the Optimized tab.
5. Confirm preview/export remain available.
6. Restore the network and confirm normal reconciliation still succeeds.

## Post-Ship Measurement

On a new shipped build, `optimization_state_recovery_failed` may remain non-zero
because networks still fail. The success signal is that affected users can still
reach `optimized_preview_rendered`, `export_cta_seen`, and `export_success`.
Do not report an activation-rate verdict until the clean cohort reaches the
existing sample gate.
