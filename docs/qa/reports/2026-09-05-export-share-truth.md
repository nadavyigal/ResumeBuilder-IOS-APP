# September 5 — export/share truth and measurement integration

## Changed behavior

File preparation still persists the historical export-completion flag and emits `export_success`, with unchanged package flags. Both mean artifact readiness. The optimized export card now says File ready/Files ready instead of Exported. The existing shared `UIActivityViewController` reports `export_share_result` with `outcome=completed|cancelled|failed`, once per presentation. Errors take precedence over completion. Copy distinguishes the selected activity completing, cancellation, and failure; no outcome claims employer submission or recipient delivery. A dismissal without a supported callback leaves File ready, without inventing an outcome.

The review prompt still evaluates artifact readiness after the share sheet dismisses, including after cancellation or failure. Its eligibility, internal exclusions, durable once-per-version claim and `source=export_success` remain unchanged. This preserves activation and review history; changing that policy is a separate product decision.

Package assembly and résumé/cover-letter/screening-answer URLs are unchanged. Home already preserves guest résumé/job inputs and diagnosis on authentication transitions; no directly reproduced continuity blocker justified changing onboarding.

## Current source and release evidence

Baseline main `a992fb1` includes merged #181 (1.5.0 build 28), #147 package export, and #142 deterministic auth tests. WP-73 #182 was still open when inspected. This batch reuses its measurement command and version validator, without importing stale progress history or changing build settings. It fixes release clamping, per-user maturity, low-count rate suppression and the inherited credential-file fallback. The command now requires `AGENTIC_OS_POSTHOG_API_KEY` in the environment.

Apple's cache-busted lookup returned version **1.5.0**, released **2026-09-02T19:44:22Z**. Build **28** is supported by repository release source, QA/archive record and telemetry; App Store Connect selection was **not independently verified** in this batch. The lookup does not expose the build number.

## Fixed measurement read

- Project 270848; library `resumely-ios-urlsession`; exact `app_version=1.5.0` AND `build_number=28`.
- As of **2026-09-05T00:00:00Z**, fixed window **[2026-08-14T00:00:00Z, 2026-09-05T00:00:00Z)**, clamped to the latest historical semantics boundary.
- Build inventory: 25 events, four people; first **2026-09-02T11:33:58Z**, last **2026-09-02T12:43:20Z**. Every event precedes release. No post-release production evidence.
- Supplemental prerelease classification: four internal people, zero external people. Exclusion is person-level `max(is_internal_tester IN ('true','True'))` across the full fixed-window library events, before exact-build/public funnel counting. These are prerelease counts, not production activation.
- Primary activation remains `optimization_completed`; `export_success` is a separate artifact-readiness diagnostic. No valid public activation rate is available.
- Release age 52.3 hours: **not yet measurable**. Earliest possible 168-hour boundary **2026-09-09T19:44:22Z**; the daily command first reaches it on September 10 at midnight UTC. Each individual selection must also have 168 elapsed hours; younger users remain pending. Below ten per funnel step, counts only.
- Existing WP-73 live reads repeated byte-identically (SHA256 `e1502a395e738f63d03fe9e455136c6bb90886f85d7eaa1aaab50eee1dd9ae43`). Fixed bounds do not guarantee immutable data: late ingestion/person merges can change later results.
- Live reads used the inherited authorized local credential loader before it was removed. The corrected public-cohort HogQL was accepted and returned zero counts. No secrets were printed or written.

## Verification

- Final restored-source simulator build: **BUILD SUCCEEDED**, `/tmp/resumely-final-build.log`; temporary fixture absent.
- Red contract: new share tests failed compilation on missing `ShareOutcome` / coordinator, as intended.
- Full iOS 26.5 suite: **426 passed, 1 skipped, 0 failed** (427 total across XCTest/Swift Testing), iPhone 17 Pro; `/tmp/resumely-share-dd/Logs/Test/Test-ResumeBuilder IOS APP-2026.09.05_14-31-46-+0300.xcresult`.
- Final focused iPhone 17 run: **41/41 passed**, including actual UIKit-handler synthetic success/cancel/error/error precedence, duplicate callbacks, independent repeated presentations, analytics contract, package extras, review gate, guest continuity and auth refresh; `/tmp/resumely-share-dd/Logs/Test/Test-ResumeBuilder IOS APP-2026.09.05_14-34-46-+0300.xcresult`.
- Measurement: six offline tests passed; live version validator passed 1.5.0 and rejected a temporary synthetic 0.0.0 project with exit 1. The validator is routed from AGENTS.md.
- Simulator visual evidence: synthetic actual export card rendered File ready on iPhone 17 and cancellation on iPhone SE (both iOS 26.5). The narrow layout remained readable. See [ready](export-share-truth-assets/iphone17-ready.png) and [cancelled](export-share-truth-assets/se-cancelled.png). The real shared UIKit sheet displayed the synthetic PDF ([sheet](export-share-truth-assets/iphone17-sheet.png)); the failure/retry card also rendered correctly on SE ([failure](export-share-truth-assets/se-failed.png)). The completed card also rendered on SE ([completed](export-share-truth-assets/se-completed.png)). Outcomes were seeded for visual checks; actual handler mapping is covered by the automated tests. Temporary harness was removed from final source. The first harness attempt exited because it evaluated the environment-dependent card too early; the corrected mounted-view harness rendered successfully.

## Limits and next action

Synthetic completion is evidence of callback wiring and state mapping, not third-party delivery. Physical-device authenticated export, Files/Mail/AirDrop cancellation/retry, Hebrew wording review, and ASC build selection remain unverified. No hardware or live account interaction was assumed. Review this PR together with #182: the useful script work is integrated here, so #182 needs reconciliation rather than a duplicate landing. Merge review is the next action; shipping remains a separate founder-controlled release. No web product, production configuration, App Store submission or shared vault/dashboard changes were made.
