# 2026-11-12: Expert tools order and "Before you send" checklist (story 4, tester call)

- [x] Expert tab lists Cover letter, Screening answers, Achievement quantifier, Summary, ATS report, Resume Rewrite last (`ExpertWorkflowType.displayOrder`; API enum order unchanged).
- [x] Optimized tab: "Before you send" card under the score: Improve match, Add a cover letter (Expert tab), Choose a design (Design tab); done rows checked, next open row highlighted, "All set. Export below." when complete. Only in the tab (`showsNextSteps`), not in Profile/History hosts.
- [x] Hebrew for the five new strings; `NextStepsAndExpertOrderTests` (6); full suite 760, 0 failures; simulator EN.
- [ ] Not done: "Export now or improve more first?" prompt on Export (the tester's other idea); the checklist covers the same need.

# 2026-11-12: Reuse the last check for the same résumé and job (story 5, tester call)

- [x] `TailorViewModel`: remember the last finished check by file bytes (SHA256) + job + account; a repeat restores it without a server call.
- [x] Accepted check: Home opens that optimization instead of offering the review again (accepting again mints and bills a second optimization).
- [x] Cleared on account change (`resetUploadCache`); a failed check is never reused; an unreadable file never reuses.
- [x] Reused optimization deleted (404): run a fresh check (code review finding). File hash runs off the main thread.
- [x] `RepeatCheckReuseTests` (9); `UploadCacheIdentityTests.testSameIdentityReusesTheUpload` now uses a real file; full suite 763, 0 failures.

# 2026-11-12: Copy pass on the Optimized screen (story 3, tester call)

- [x] "Improve fit once" to "Improve match", the name the blocker tip already uses; caption "A second pass on keywords and metrics."
- [x] "Fit improvement applied once... are now current" to "Done. Your résumé and score are updated." (fallback "Done. Your score is updated.")
- [x] Export button says "Export résumé" when nothing else is included; "Export application package" when a cover letter or answers are.
- [x] "See what changed" detail: one "Back to my résumé" button instead of "Improve my resume" + "Edit target job" (both only went back).
- [x] Hebrew for the five new strings; tests updated; full suite; simulator EN + HE.
- [ ] Follow-up: "Refine", "Edit", "Design", "Expert" chips show in English in Hebrew mode (existed before).

# 2026-11-12: Result screen shows score and next step above the fold (story 2, tester call)

Tester did not know the Optimized screen scrolls: the full-page preview filled the phone, its web view scrolled on its own, and the export bar is pinned. Keep the resume first (lesson 2026-07-14) but shorter.

- [x] `ResumePreviewWebView`: `isScrollEnabled` option (default on; Design tab unchanged). Add `RenderedResumeHTMLView` for a read-only full page.
- [x] `OptimizedResumeView`: inline preview shows the top of the page in a fixed-ratio card, no inner scroll, bottom fade, "View full resume" button; tap opens the full page in a sheet built from the HTML already on screen.
- [x] Move "See what changed" above the preview when changes were applied (replaces the static "Applied changes" line); lower link only when it is not shown up top.
- [x] Hebrew for "View full resume".
- [x] Tests for the preview ratio; build; full suite (754, 0 failures, English test language); simulator first screen in English and Hebrew via `--smoke-optimized`.
- [x] Score panel shows above the export bar: card is half a page, "Save to My Resumes" moved below the score.
- [ ] Founder: one look on a real iPhone with a real optimization.

# 2026-11-10: GoTrue error parsing (#227)

- [x] Reproduce raw JSON shown for numeric-code/msg errors and mixed-type fallbacks.
- [x] Parse heterogeneous response dictionaries and choose a nonempty readable string, preserving legacy message/error_description/error fallbacks and raw non-JSON fallback.
- [x] Read-only independent review; all five production error paths use the helper.
- [x] Incorporate pricing source9d2fc2c and preserve both sets of notes; resolve all conflict markers before push.
- [x] Combined full suite: 750 XCTest cases (11 skipped, 0 failures) plus 5 Swift Testing cases pass.
- [ ] Current-head hosted review before integration.
- [ ] Separate existing account-isolation P2: reject successful unlock completion after a session boundary.

# 2026-11-10: Session isolation during refresh (#227)

- [x] Reproduce a late refresh restoring account A after sign-out/account B sign-in.
- [x] Invalidate pending refresh and password retries across explicit session boundaries, including identical same-account credentials.
- [x] Persist rotated credentials only after the session-generation/cancellation checks, with no suspension before installation.
- [x] Cover launch refresh, sign-out, A to B, same-account re-entry, stale failure, ordinary persistence, coalescing, and old-task/new-task cleanup.
- [x] Independent read-only review; confirmed suggestions fixed.
- [ ] Current-head hosted review after push; no merge or release in this task.
- [ ] Separate follow-ups: #226 credit reply ordering; #227 GoTrue error parsing.

# 2026-11-06: Forgot password and change password in the app (1.6.1, plan A)

As a Resumely user who signed up with email, I want to reset a forgotten password from the app's sign-in screen and change my password from Me, and after a reset on the web page get back into the app.

Plan A, approved 2026-11-06. No Apple portal change, no app links.

- [x] `AuthService`: `sendPasswordReset(email:)` (POST `/auth/v1/recover`) and `updatePassword(accessToken:newPassword:)` (PUT `/auth/v1/user`).
- [x] `AppState`: `changePassword(_:)` with a fresh token; `resumebuilder://signin` sets `pendingSignInRequest`.
- [x] `Features/V2/Auth/PasswordSheets.swift`: Forgot password sheet and Change password sheet, each with an `@Observable` view model.
- [x] Sign-in screen: "Forgot password?" in sign-in mode. Me tab: "Change Password" for email accounts only (not Apple, not guests).
- [x] `Config/Info.plist`: register the `resumebuilder` URL scheme. The tab view opens Me and the sign-in sheet on that link.
- [x] Hebrew strings in `Localizable.xcstrings`.
- [x] Web (separate PR): the update-password success screen shows "Open the Resumely app" on iPhone, linking to `resumebuilder://signin`.
- [x] Tests: view model validation, link parsing, AppState routing, request shape. Build, full suite, simulator smoke test.
- [ ] Founder: one run on a real iPhone (forgot password from the app, open the email, save, tap "Open the Resumely app", sign in; then Me > Change Password).

# 2026-11-10: Credits read ordering (#226)

- [x] Reproduce two exports with reversed credits replies for packs and Pro.
- [x] Reject older reads after a newer read starts or an unlock/verified purchase applies a balance, including nil-balance Pro unlocks.
- [x] Invalidate reads on sign-out and setSession; cover same-account re-entry.
- [x] Preserve main's #228 live-release record; correct row 12's evidence limitation without repeating a transaction/submission.
- [x] Independent scoped review; no blocking read-order finding.
- [x] Full suite: 718 XCTest cases (11 skipped, 0 failures) plus 5 Swift Testing cases passed.
- [ ] Current-head hosted review and founder source decision before integration.
- [ ] Separate account-isolation follow-up: reject successful unlock completion across a session boundary before applying balance or returning authorization.

# 2026-11-05: Profile usage refresh after an export (WP-79 S3, PR #226)

Plan: a failing test first, then re-read the plan after a new unlock and on each Me-tab show.

- [x] Root cause: the unlock reply has no Pro fair-use count, and the kept-alive Profile tab read credits once per launch.
- [x] `ExportUsageRefreshTests`: red on "0 of 40" after a Pro export, now green.
- [x] `authorizeExport` re-reads credits in the background after a new unlock; the plan row re-reads on each Me-tab show.
- [ ] Founder retest on the phone: export with Pro and with a pack, then open Me without a relaunch.

# 2026-10-31: Track T1, iOS payment blockers on PR #226 (no commit, no push, founder brief)

Plan: fix the three open review findings with a failing test first, then prepare the launch documents and the local 1.6.0 bump.

- [x] Finding 1: a cancelled or expired Pro user sees the Pro offer again. Paywall reads the server before it hides Pro; `refreshEntitlements` re-reads the plan on `.noPlan`.
- [x] Finding 2: the score-seen mark and `match_score_viewed` wait for the active tab and fire when it becomes active.
- [x] Finding 3: with `REQUIRE_STOREKIT_TESTS=1` a missing product fails, and the dedicated test plan makes a skip impossible. A passing run of all 10 cases is still needed.
- [x] `docs/qa/2026-10-31-pricing-map.md`, `founder-xcode-run.md`, `sandbox-matrix.md`, `ios-go-no-go.md`.
- [x] 1.6.0 version bump, local only, no archive.
- [x] Full test suite and Release build, skipped tests named.

Older entries: [tasks/archive/todo-to-2026-10-29.md](archive/todo-to-2026-10-29.md).
