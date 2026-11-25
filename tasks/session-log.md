## 2026-11-10: GoTrue parsing and source reconciliation (#227)

After the separate #226 ordering fix passed its suite and was pushed, merged its source9d2fc2c locally into #227. Both sets of notes and main's #228 live-release record are retained, with row12 still marked unrun as specified. A merge-resolution script stopped early because a historical lesson contained a literal marker example; a subsequent shell commit retained three note conflicts. Caught before push, resolved all anchored conflict-marker lines and amended only that unpublished merge. Swift source merged without conflicts.

Exposed the existing pure GoTrue parser to tests without changing its baseline behavior; three modeled provider errors then failed. Replaced the homogeneous dictionary decoder with heterogeneous JSON plus nonempty string fallbacks. Five new tests cover numeric reauthentication, reset-email rate limiting, ordinary message keys, mixed/null/empty fields and malformed/non-JSON responses. Independent review approved; combined full-suite evidence and hosted review are recorded in the current precheck. No live password/reset operation, new UI copy, version bump, upload or release. Store-version check confirmed live1.6.0; all7 measurement-contract tests pass. Taste: useful readable errors; existing provider wording/voice; no added filler; scope limited to parsing and required source reconciliation. No new dependency or skill changes.

## 2026-11-10: PR #227 suspended-refresh security repair

Executed the first task in the founder-approved progress plan. Used existing clean `claude/ios-password-reset` checkout at `/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-password-reset`; fetched and matched remote head b9a4c43 before editing. Root cause: AppState installed a late refresh unconditionally, and AuthService persisted it before the caller could validate ownership. Explicit session assignments now invalidate a generation and cancel old work; validated credential rotation keeps that generation stable. Both refresh entry points share the guarded path, stale failures cannot sign out a replacement account, and old cleanup cannot clear the replacement refresh task.

Regression evidence: 11 tests / 14 failures on old production source; fixed targeted run 31/31 passes. Full suite 739 XCTest cases (11 skipped, no failures) plus 5 Swift Testing cases passes, including independent-review additions for persistence and old/new refresh coalescing. Final cleanup rebuild/full suite passed again with the same counts; git diff --check clean. Results: /tmp/resumely-session-final-20261110.xcresult. The independent reviewer made no production calls and reported no remaining findings. This task does not resolve the separate GoTrue parsing P2 or #226 credits finding and does not authorize merge, upload or release. No build/version changes.

## 2026-11-10: PR #226 credits-ordering follow-up

Created `/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-credits-response-ordering`, branch `fix/credits-response-ordering`, from remote pricing head 06d367c. The original pricing checkout has an existing date-only progress edit and was left intact. Locally merged main 2b6367a; preserved #228's live1.6.0 record and all pricing submission history while resolving the progress-file conflict. No product PR was merged.

Baseline three reversed-response regressions produced four assertion failures. The repair invalidates older reads on each new read, unlock/purchase balance write (including nil balance), sign-out and session install. Targeted six ordering plus three existing export-usage tests pass. Independent read-only review approved the scoped fix and retained a separate successful-unlock/session-switch P2 for later repair. Payment QA row12 is corrected to unrun as specified; its fast-grant observation remains. Full results and push head are recorded in the PR precheck. No live billing, transaction, upload or submission action. Taste check: useful user state correction; existing UI/voice preserved; no product filler introduced; scope restricted to ordering/evidence repair. Retrospective: explicit held responses reproduced the bug; a nil-balance unlock must invalidate reads as well.

## 2026-10-31 — Track T1, iOS payment blockers

Fixed the three open #226 findings test-first and prepared the launch documents. Committed and pushed on the founder's yes (d1d0f98, c4c4b52). Files changed: `AppState.swift`, `StoreKitManager.swift`, `ExportPaywallSheet.swift`, `OptimizedResumeView.swift`, `ResumePreviewWebView.swift`, `project.pbxproj`, test files, `Resumely.storekit`, new `StoreKit Tests.xcscheme`, `StoreKitRequired.xctestplan`, `docs/qa/2026-10-31-*.md`, `audit/pricing-v2-t1/`.

Decisions: probe with a local-only product because real products now exist in App Store Connect; keep D1 although 38 of 39 real accounts hold 3; recommend reusing the 1.5.7 draft as 1.6.0.

**Next action:** PR pre-check on a yes, then the founder's StoreKit run on a real iPhone.

Taste check for the session-isolation repair: better for users, yes, sign-out stays effective; product voice, yes, no copy change; AI filler, none introduced in product; scope, yes, only refresh isolation and its required records/tests. Retrospective: suspended continuations exposed the race; independent review strengthened the coalescing test handshake. No skill changes or new dependencies needed.

Older entries: [tasks/archive/session-log-to-2026-10-29.md](archive/session-log-to-2026-10-29.md).
