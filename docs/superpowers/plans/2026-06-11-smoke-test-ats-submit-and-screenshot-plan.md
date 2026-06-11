# 2026-06-11 Smoke Test Follow-Up Plan

## Objective

Resolve the remaining real-device smoke failures and align the live product experience with the claims shown in App Store screenshots.

## Findings

### Submit Package

- New smoke logs show no `/api/download`, `/api/v1/applications`, or `/api/v1/expert-workflows/run` calls after the Submit Package interaction.
- The package workflow was not starting because `SubmitApplicationViewModel.canSubmit` required a non-empty company name.
- Live optimization detail can omit `company`, leaving the sheet's primary action disabled without a visible explanation.

### Low ATS Score

- The 18% -> 35% score in the smoke screenshot is coming from the live ATS/optimization result, not from a UI calculation bug.
- The app currently surfaces the score but does not give the user a strong enough guided path from "low match" to "ready to apply."
- The App Store screenshots show clearer blocker, section-score, and before/after narratives than the normal app currently exposes in one coherent flow.

### App Store Screenshot Mismatch

- The attached screenshots are `MarketingScreenshotView` scenes.
- `ContentView` only shows those scenes when launched with `--marketing-screenshot --screenshot-slot N`.
- They are deterministic marketing/release artifacts, not normal user-facing screens.

## Immediate Fix

- Status: implemented on `codex/fix-submit-package-missing-company`.
- Let Submit Package proceed when backend/job parsing misses company or role context.
- Show a lightweight info message in the sheet explaining the fallback.
- Use safe placeholders:
  - Missing role -> `Target Role`
  - Missing company -> `Company not specified`
- Add stage logs so future Xcode logs clearly show whether Submit Package reached PDF, application creation, expert generation, and package-ready states.

## Product Plan

### P0: Smoke Reliability

- Rebuild on real device from the latest branch.
- Smoke: optimize -> open Submit Package -> Create Package.
- Confirm logs include:
  - `Submit package start`
  - `Submit package PDF ready`
  - `Submit package application created`
  - `Submit package expert workflows completed`
  - `Submit package ready`
- Confirm Me/Application list refreshes after package creation.

### P1: ATS Quality Loop

- Status: MVP implemented on `codex/fix-submit-package-missing-company`.
- Added a normal in-app ATS insight panel modeled after the screenshot catalog:
  - headline score before/after
  - score signals
  - top blockers
  - "Improve ATS" primary action
  - explicit "still low because..." explanation when optimized score remains below 55
- After optimization or Expert ATS apply, show a before/after delta card so a low final score is understandable.
- Add smoke fixtures for one strong-match resume/job and one weak-match resume/job so QA can tell backend quality regressions from expected mismatch.

### P2: Screenshot Claim Alignment

- Decide whether each App Store screenshot is:
  - a pure marketing visualization, or
  - a screen/section that should exist in the app.
- For any screenshot claim that users expect to find in-app, build a matching product surface in `Features/V2/`.
- Keep `MarketingScreenshotView` launch-argument-only for App Store capture, but ensure every claim maps to a reachable in-app workflow.

## Validation Plan

- Focused tests for Submit Package missing company/role context: done.
- Focused tests for low-score ATS insight explanation/actions: done.
- Simulator build/test on iPhone 17: done.
- Normal simulator app launch smoke on iPhone 17: done.
- Real-device smoke with the user's actual resume/job.
- PostHog verification for `optimization_completed` and `export_success`.
- Screenshot comparison: live Optimized/ATS screens vs. App Store screenshot claims.
