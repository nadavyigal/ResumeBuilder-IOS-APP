# 2026-11-13: Dead tested code and Ambassador skeleton removed

Current Phase: 1.6.1 source follow-ups; cleanup decided by the founder from the 2026-11-11 audit.
Active Story: delete unused view models, chat screen, design sheet, Ambassador skeleton, their tests and mocks; trim ChatService to its 2 live calls; add keyword-flow tests.
Next Recommended Story: remove leftover chat endpoints and StreamingClient (touches AIConsentGate); Fit-check removal once WP-45 S10 closes.
Blockers: none.
Last Validation: 2026-11-13 iPhone 17 iOS 26.5 full suite 762 XCTest (11 skipped, 0 failures, 4 new keyword-flow tests) + 1 Swift Testing; app warnings 0.

# 2026-11-13: Share links checked strictly; stale docs archived

Current Phase: 1.6.1 source follow-ups; audit items decided by the founder.
Active Story: `DeepLinkRouter.parseSharedJobURL` accepts only resumebuilder://share with an http(s) job URL; work packs, June sweeps and May benchmarks archived; IAP checklist corrected.
Next Recommended Story: merge #239 and this PR once CI is green.
Blockers: none.
Last Validation: 2026-11-13 iPhone 17 iOS 26.5 full suite 774 XCTest (11 skipped, 0 failures), 4 new DeepLinkRouterTests.
Last Updated: 2026-11-13

# 2026-11-12: 1.6.1 (40) submitted to App Review

Current Phase: 1.6.1 in App Review; PR #237 merged (543b001); founder passed build 40 on his iPhone.
Active Story: none in code. 1.6.1 Waiting for Review since 18:56, auto-release to all users after approval.
Next Recommended Story: after approval, run `scripts/validate-store-version.sh` expecting 1.6.1; then story 6 outreach kit (#235, spec first).
Blockers: none; Apple review (up to 48 hours).
Last Validation: 2026-11-12, 770 XCTest (11 skipped, 0 fail) + 5 Swift Testing; founder TestFlight phone pass on 40; ASC fields read back.
Last Updated: 2026-11-12

# 2026-11-12: 1.6.1 (40) release build for TestFlight

Current Phase: 1.6.1 release; tester-call fixes #231 to #234 plus #226 and #227 on main.
Active Story: 1.6.1 (40) uploaded 18:31 on the founder's yes; processed, What to Test saved, in Founder QA group (1 invite).
Next Recommended Story: founder on-device check of build 40 from TestFlight; App Store submission is a separate yes.
Blockers: none; founder phone check of build 40 next.
Last Validation: 2026-11-12, 770 XCTest (11 skipped, 0 fail) + 5 Swift Testing, iPhone 17 iOS 26.5, EN; store check PASS; Release archive 40 checked; `-exportArchive` "Upload succeeded".
Last Updated: 2026-11-12

# 2026-11-12: Expert order and "Before you send" checklist (story 4, tester call)

Current Phase: 1.6.1 source follow-ups; tester-feedback fixes. Web #214, iOS #231, #232 merged; #233 (story 5) open.
Active Story: Expert tab puts cover letter first, rewrite last; Optimized tab shows a "Before you send" checklist.
Next Recommended Story: story 6, add the web outreach kit to the iOS Expert tab (spec first).
Blockers: none.
Last Validation: 2026-11-12, full suite 760 XCTest (11 skipped, 0 fail) + 5 Swift Testing, iPhone 17 iOS 26.5; simulator EN.
Last Updated: 2026-11-12

# 2026-11-12: Same résumé and job reuse the last check (story 5, tester call)

Current Phase: 1.6.1 source follow-ups; tester-feedback fixes. Web #214, iOS #231 and #232 merged.
Active Story: repeat "Check my fit" on same file+job+account reuses the last check; accepted check opens its résumé; deleted one re-runs.
Next Recommended Story: story 4, expert tools order (cover letter first) and a "Next step" card.
Blockers: none.
Last Validation: 2026-11-12, full suite 764 XCTest (11 skipped, 0 fail) + 5 Swift Testing after Codex fixes (V2 cache file, busy first).

# 2026-11-12: Optimized screen copy pass (story 3, tester call)

Current Phase: 1.6.1 source follow-ups; tester-feedback fixes. Web #214 and iOS #231 merged.
Active Story: clear labels: "Improve match", "Done. Your résumé and score are updated.", "Export résumé", "Back to my résumé".
Next Recommended Story: story 4, expert tools order (cover letter first) and a "Next step" card.
Blockers: none. Hebrew chips Refine/Edit/Design/Expert untranslated (pre-existing).
Last Validation: 2026-11-12, full suite 754 XCTest (11 skipped, 0 fail) + 5 Swift Testing; simulator EN and HE.
Last Updated: 2026-11-12

# 2026-11-12: Optimized screen shows the score on the first screen (story 2, tester call)

Current Phase: 1.6.1 source follow-ups; tester-feedback fixes (tester call 2026-11-12). Web PR #214 (no "Not specified") merged.
Active Story: résumé card shows top half of page, no inner scroll, "View full resume" sheet; score panel above export bar.
Next Recommended Story: story 3, copy pass: "Improve fit once", "are now current", export label, back button.
Blockers: none. Needs one founder look on a real iPhone with a real optimization.
Last Validation: 2026-11-12, full suite 754 XCTest (11 skipped, 0 fail) + 5 Swift Testing; simulator EN, HE, and HE app on EN device (Codex RTL fix).
Last Updated: 2026-11-12

# 2026-11-11: Repo audit and dead-code cleanup (iOS)

Current Phase: 1.6.1 source follow-ups; repo hygiene pass on `claude/project-audit-cleanup-cacbdb`.
Active Story: remove unreachable screens, unused types, stale flag and stray docs; refresh README and architecture doc.
Next Recommended Story: founder review of `docs/audits/2026-11-11-repo-audit.md` items 1-5, then the Resumely web audit.
Blockers: PR #230 open, code-reviewer APPROVED, Codex review pending; review-list items need founder decisions.
Last Validation: iPhone 17 iOS 26.5 full suite after cleanup 750 XCTest (11 skipped, 0 fail) + 5 Swift Testing; app warnings 3 to 0.
Last Updated: 2026-11-11

# 2026-11-10: GoTrue error parsing and combined source validation (#227)

Status: GoTrue parsing repaired after reproducing three modeled response failures; independent read-only review approved. Combined full build/suite passed: 750 XCTest cases (11 existing skips, zero failures) plus 5 Swift Testing cases. Results: /tmp/resumely-combined-full-20261110.xcresult. Not merged/released.
Current Phase: 1.6.1 source follow-ups; pricing source 9d2fc2c incorporated locally without merging either product PR.
Active Story: display the provider's readable error when GoTrue includes numeric codes/nested details; preserve existing string-key and non-JSON fallbacks.
Last Completed Story: #226 credits ordering repair pushed; session-refresh isolation repair retained. Main's #228 live1.6.0 record and row12 unrun evidence correction survive the source merge.
Next Recommended Story: current-head hosted review and remaining successful-unlock/session-boundary P2; founder integration order #226 then #227, then real-phone password-flow QA and separate release decision. Web #209 stays draft until repaired1.6.1 is public.
Blockers: hosted review; named source/release approval; physical QA limitations. Existing successful-unlock account-switch P2 remains a separate follow-up, not a claim of server credit transfer.
Last Validation: old parser fails numeric reauthentication, reset-email rate-limit, and heterogeneous/empty-message fallback tests. Independent reviewer found no remaining parser issues and no conflict markers in the merged records. scripts/validate-store-version.sh confirmed repo/store1.6.0 released2026-11-07T03:07:05Z; measurement-contract Python tests7/7 pass. Combined source build and suite passed with the counts above; git diff --check clean.
Last Updated: 2026-11-10

# 2026-11-10: PR #227 session-refresh isolation repair

Status: implemented and locally verified; independent read-only review has no remaining findings. Hosted review of the new head is pending. Not merged or released.
Current Phase: 1.6.1 security follow-up on `claude/ios-password-reset`, stacked on pricing PR #226.
Active Story: prevent an in-flight refresh from restoring a signed-out session or retrying an old password operation.
Last Completed Story: reproduced the suspended-refresh bug; moved refresh persistence behind AppState's session-generation/cancellation checks; unified launch and retry refreshes and protected new-task cleanup.
Next Recommended Story: current-head hosted review, then the separate #226 credit-response ordering task; integrate repaired #226 before #227. Keep GoTrue numeric-code/msg parsing as a separate #227 follow-up.
Blockers: #226 dependency/credit ordering; #227 GoTrue error parsing P2; hosted review and founder source/release decisions. No readiness claim from green checks alone.
Last Validation: iPhone 17, iOS 26.5; red baseline 11 AppStateRefreshTests with 14 assertion failures; targeted fixed run 31/31 passes; full suite 739 XCTest cases (11 skipped, 0 failures) plus 5 Swift Testing cases passed. Final source rebuild/full suite passed again with the same counts, no new refresh-token compiler warning, and git diff --check clean. Results: /tmp/resumely-session-final-20261110.xcresult. Independent reviewer requested new-task cleanup and persistence regressions; both added and reviewed, deterministic MainActor entry handshake replaces fixed yields. No live auth calls in the new regression tests; no UI changes, so no new UI smoke required.
Last Updated: 2026-11-10

# 2026-11-06: Forgot and change password in the app (1.6.1 plan A)

Status: branch `claude/ios-password-reset` (stacked on `claude/resumely-pricing-v2`, PR #226), PR open, not merged, no build uploaded. Ships as 1.6.1 after Apple approves 1.6.0.
Current Phase: Payments v2; 1.6.0 (39) in App Review.
Active Story: sign-in has "Forgot password?" (Supabase `/auth/v1/recover`); Me has "Change Password" for accounts with an email identity (PUT `/auth/v1/user`); the app registers `resumebuilder://`, and `resumebuilder://signin` opens Me and its sign-in sheet. Web draft PR nadavyigal/new-ResumeBuilder-ai-#209 adds "Open the Resumely app" on the reset success screen; merge it only after 1.6.1 is live.
Last Completed Story: 1.6.0 (39) submitted; web reset page live (#208).
Next Recommended Story: founder runs the flow once on a real iPhone, then bump to 1.6.1 and upload after 1.6.0 is approved.
Blockers: Apple review of 1.6.0.
Last Validation: 2026-11-08 full suite 730 tests, 0 failures, 11 skipped (18 in `PasswordFlowsTests`, incl. CodeRabbit fixes: retry bound to the starting account, 403 `bad_jwt` treated as an expired session). Simulator: `resumebuilder://signin` opens sign-in from foreground, background and a cold launch; Forgot password sent a reset to +review, Resend "Delivered".
Last Updated: 2026-11-06

# 2026-11-10: Credits reply ordering repair (#226)

Status: implemented; targeted regressions pass and independent read-only review approved. Full build/suite passed: 718 XCTest cases (11 existing skips, 0 failures) plus 5 Swift Testing cases; git diff --check clean. Results: /tmp/resumely-credits-full-20261110.xcresult. PR remains draft; no merge/release or billing operation.
Current Phase: reconcile pricing-v2 source with main's #228 live-release record and repair stale balance/usage replies.
Active Story: prevent older credits reads from overwriting newer balance or Pro usage.
Last Completed Story: three baseline tests reproduced stale balance/usage (4 assertions failed); read generations plus synchronous write invalidation fix the race. Main's dated 1.6.0 live record is preserved above the older submission history. Row 12's unrun kill-before-grant scenario is no longer described as a pass.
Next Recommended Story: hosted review of this head, then #227 GoTrue parsing follow-up and source refresh against this pricing branch; #226 integration precedes #227.
Blockers: final high-risk review and founder source-integration approval; physical QA limitations remain. Separate pre-existing P2: a successful A unlock can still apply its balance/authorization after switching to B; fix by binding successful completion to the session generation. Not a server-credit grant to B, and not fixed by this read-ordering change.
Last Validation: targeted CreditsResponseOrderingTests 6/6 and ExportUsageRefreshTests 3/3 passed (iPhone 17, iOS 26.5, English), independent agent review approved with the successful-unlock case retained separately. No new StoreKit purchase or production write.
Last Updated: 2026-11-10

# 2026-11-08: 1.6.0 live (build 39 most likely)

Status: 1.6.0 live on the App Store since 2026-11-07T03:07:05Z. Submitted 2026-11-05 16:57 Asia/Jerusalem with build 39 and 3 products (`resumely.exports.14`, `resumely.exports.5.v2`, `resumely.pro.monthly`), release setting automatic after approval. The public lookup does not show the build number; 39 was the only build attached at submission, so the live build is most likely 39. Not checked in App Store Connect.
Release source: commit `953fb12` on branch `claude/resumely-pricing-v2` (PR #226, still a draft). `main` does not contain the 1.6.0 code, so `main` is older than the live app until #226 merges. The full 1.6.0 history (upload, ASC setup, submission) is in #226's `tasks/progress.md`.
Current Phase: Post-release of 1.6.0. Payments v2 live in the binary; server billing flag off.
Active Story: 1.6.1 on PR #227 (password reset and change, stacked on #226). The PR Steward's 2026-11-08 sweep found a blocking account-switch risk in its password retry; `b9a4c43` addresses it and awaits current-head review.
Last Completed Story: 1.6.0 released.
Next Recommended Story: current-head review and merge of #226 so `main` matches the live app, then #227 (1.6.1). Founder decides separately when to set `EXPORT_CREDITS_ENABLED` on (Vercel + redeploy, his yes), then remove the old 1.5.6 packs from sale. Check the 3 products' state in App Store Connect (not checked this session).
Blockers: public billing stays off until the founder's named yes. Hosted Codex review is out of credits.
Last Validation: 2026-11-08: App Store lookup (id 6776752349) returned 1.6.0, released 2026-11-07T03:07:05Z (3 of 3 polls with varying URLs). Status-file change only; no build, test or code change.
Last Updated: 2026-11-08

# 2026-11-05: 1.6.0 (39) submitted to App Review with 3 products (PR #226)

Status: submitted 16:57 Asia/Jerusalem on the founder's yes. Submission holds 5 items: iOS 1.6.0 (39), `resumely.exports.14`, `resumely.exports.5.v2`, `resumely.pro.monthly`, subscription group Resumely Pro. Release setting: automatic after approval. PR #226 is still a draft, not merged.
Current Phase: Payments v2, in App Review.
Active Story: wait for Apple (up to 48 hours).
Last Completed Story: ASC setup and submit. Review login is `nadav.yigal+review2@gmail.com` (created 15:46, added to `EXPORT_CREDITS_USER_IDS`, live via redeploy 69keojuuq at 15:50, ledger +3 then 3 exports, balance 0). Pack display names now "14 PDF downloads" / "5 PDF downloads" (Hebrew "14/5 הורדות PDF"), prices unchanged. Subtitle "Tailor Your Resume to Any Job" approved by the founder. Age rating questions: new Social Media = No, Social Media under 13 = No; rating stays 4+.
Next Recommended Story: after approval and release, the founder decides when to set `EXPORT_CREDITS_ENABLED` on (Vercel + redeploy, his yes), then remove the old 1.5.6 packs from sale. Before that: S7 accountant, WP-35 legal entity. Web password reset is fixed and live (web PR #208 merged 2026-11-05, Supabase template on `/auth/confirm`, Resend key rotated in the `resumebuilderaiteam` Resend account, leaked key deleted). Left on web: 11 old docs still hold the dead key.
Blockers: Apple review.
Last Validation: 2026-11-06: reset email for +review sent with the new Resend key, Delivered; its link opened in a clean browser lands on "Choose a new password". 2026-11-05: ASC "5 Items Submitted"; review2 ledger balance 0.
Last Updated: 2026-11-06

# 2026-11-05: 1.6.0 (39) set up in App Store Connect, not submitted (PR #226)

Status: ASC version renamed 1.5.7 to 1.6.0 and saved with build 39 (38 removed; 36 and 37 are internal-only and cannot attach). Founder's What's New and PRICING description text, new review notes, review login `nadav.yigal+review@gmail.com` saved and read back. Store screenshots replaced with the T2 release set (iPhone 6.3" and iPad 13", 4 each, from #225); old v3 screenshots and the App Preview video removed from every iPhone size (still in the Asset Library). Review screenshot for the 14 pack, 5 pack and Pro replaced with `audit/release-1.6.0-39/paywall-review-en.png` (build 39 code, "PDF downloads"). Not submitted.
Current Phase: Payments v2, App Review submission.
Active Story: submit 1.6.0 with the 3 products (founder approved "submit 1.6.0").
Last Completed Story: ASC setup above.
Next Recommended Story: founder resets the review account password (website reset, mail arrives at his main Gmail) and saves it in ASC; founder yes on renaming the two pack display names from "tailored CVs" to "PDF downloads"; then Add for Review and Submit.
Blockers: review password (founder only); pack display names (founder yes).
Last Validation: 2026-11-05: ASC fields read back after reload; build 39 attached; paywall screenshot from a Debug build of 953fb12 on iPhone 17 Pro simulator (1206x2622).
Last Updated: 2026-11-05

# 2026-11-05: 1.6.0 (39) uploaded for App Store submission (PR #226)

Status: 1.6.0 (39) archived and uploaded at 15:04 Asia/Jerusalem on the founder's yes, commit 953fb12, `testFlightInternalTestingOnly` false so it can attach to the App Store version. Apple is processing it. Not merged, not submitted.
Current Phase: Payments v2, launch preparation.
Active Story: none in code.
Last Completed Story: copy fixes 1 to 5 (3cd83c1) and the build 39 bump (953fb12). Archive checked: 1.6.0 / 39, `API_BASE_URL` https://www.resumelybuilderai.com, no `.storekit` file, no test bundle, Hebrew strings carry "הורדות PDF".
Next Recommended Story: when 39 shows as processed in App Store Connect, attach it to 1.6.0 (replacing 38), paste the store texts from `docs/qa/2026-11-05-asc-1.6.0-texts.md` (copy-checked version in the founder's chat), check the two pack IAP display names say PDF downloads. Then S7 accountant, S8 screenshots (#225), submit.
Blockers: S7 accountant; S8 screenshots.
Last Validation: 2026-11-05: 712 XCTest, 0 failures, 11 skipped on 3cd83c1 (iPhone 17 Pro, iOS 26.5); Release archive 39 succeeded; `xcodebuild -exportArchive` "Upload succeeded".
Last Updated: 2026-11-05

# 2026-11-05: 1.6.0 copy fixes before submission (PR #226)

Status: five copy fixes from the /clean-copy audit committed and pushed to PR #226 on the founder's yes. Not merged. Build 38 is now stale: it does not contain these strings.
Current Phase: Payments v2, launch preparation.
Active Story: none in code.
Last Completed Story: copy fixes 1 to 5. (1) Share text says "estimated" Match Score. (2) Diagnosis headline "Estimated match for this job: N%". (3) One name for what is sold: "PDF downloads" on the purchase sheet, purchase messages and errors, matching the App Store text. (4) Hebrew for 21 strings that showed English. (5) Removed "free checks remaining this week" and the "Checks left" tile, which contradicted free unlimited Match Scores.
Next Recommended Story: new build 39 (archive and upload on the founder's yes), attach it to 1.6.0 instead of 38. Check that the IAP display names in App Store Connect say PDF downloads too. Then the Risk items from the audit (ATS wording, 7-second stat, 60-second promise, Premium, Apple ID) in 1.6.1, and the Hebrew gender pass as its own story.
Blockers: S7 accountant; S8 screenshots; build 39 upload needs the founder's yes.
Last Validation: 2026-11-05: full suite on iPhone 17 Pro, iOS 26.5: 712 XCTest, 0 failures, 11 skipped; 5 Swift Testing pass. First run had 1 failure (EXD-018 test caught plan wording in the 402 message), fixed, rerun green. Simulator smoke: purchase sheet in English and Hebrew shows "Get more PDF downloads", "14 PDF downloads", "5 PDF downloads".
Last Updated: 2026-11-05

# 2026-11-05: 1.6.0 (37) on TestFlight, phone run (WP-79 S4, PR #226)

Status: 1.6.0 (37) uploaded 09:45 on the founder's yes, in the internal Founder QA group only. Phone run done: `docs/qa/2026-11-05-testflight-37-phone-run.md`. Not merged, not submitted.
Current Phase: Payments v2, launch preparation.
Active Story: none in code. WP-79 S4 phone run: rows 3, 5, 7, 18 and 27 passed; row 12's kill-before-grant scenario remains unrun (evidence correction 2026-11-10). Rows 11 and 25 not run on the founder's named yes (2026-11-05).
Last Completed Story: on TestFlight 37: row 6 Pro renewal PASS, S3 usage refresh PASS (count +1 without relaunch), row 12 normal fast-grant path observed (one +5 grant, one debit, balance 4), not the required kill-before-grant recovery, row 27 PASS (re-sent transaction added no row, Restore kept 4). First row 12 attempt closed the app inside Apple's sheet: no purchase, no charge, correct.
Next Recommended Story: ASC draft renamed 1.5.7 to 1.6.0 (saved). Builds 36 and 37 were uploaded internal-testing-only and cannot be attached; build 38 (same code) archived, upload waits on the founder's yes. Store texts drafted in `docs/qa/2026-11-05-asc-1.6.0-texts.md`, waiting on his OK. Review account ready at 0 (ledger verified 13:16). Then App Store Connect 1.6.0 setup with build 37, S7 accountant, S8 screenshots (#225), submit. After release: EXPORT_CREDITS_ENABLED on, old packs off sale.
Blockers: S7 accountant; S8 screenshots. Not run by design: StoreKit unit tests on a phone (1 pass / 9 fail on 1 Nov), rows 10, 11, 17, 20 to 22, 25, 26, 28 to 31.
Last Validation: 2026-11-05: Release archive 1.6.0 (37) succeeded and was verified; ledger, PostHog and Vercel logs read for every row above. No app source change since 80f36fc (712 XCTest, 0 failures, 11 skipped).
Last Updated: 2026-11-05

# 2026-11-05: Profile usage refresh after an export (WP-79 S3, PR #226)

Status: fixed test-first and pushed to draft PR nadavyigal/ResumeBuilder-IOS-APP#226. Not merged.
Current Phase: Payments v2, launch preparation. Go or no-go: `docs/qa/2026-10-31-ios-go-no-go.md`.
Active Story: WP-79 S4, founder StoreKit run on a real iPhone, plus the retest below.
Last Completed Story: S3 usage refresh. Root cause: the unlock reply has no Pro fair-use count, and the kept-alive Me tab read credits once per launch. `authorizeExport` now re-reads credits in the background after a new unlock; the plan row re-reads each time the Me tab is shown.
Next Recommended Story: founder retest on the phone: export with Pro, open Me, see the used count go up by 1 without a relaunch; same with a pack (downloads left goes down by 1). Then the StoreKit run, then merge on the founder's yes.
Blockers: 10 StoreKit tests cannot pass on the iOS 26.5 simulator, need a real iPhone or an older simulator; demo account likely at 9, not 0; ASC version decision; T2 marked all 15 v3 screenshots REGENERATE.
Last Validation: 2026-11-05: `ExportUsageRefreshTests` red first (Pro row stayed "0 of 40"), now 3 pass. Full suite, iPhone 17 Pro, iOS 26.5: 712 XCTest, 0 failures, 11 skipped (10 `StoreKitSessionTests`, 1 live FitCheck), 5 Swift Testing pass. Release build, generic iOS Simulator, succeeded. `code-reviewer` APPROVED. Simulator smoke of the Me tab not run: it needs a signed-in account.
Last Updated: 2026-11-05

# 2026-10-31: Track T1, iOS payment blockers on #226

Status: three open review findings fixed test-first, commit d1d0f98. 1.6.0 (36) bump, commit c4c4b52. Pushed to draft PR nadavyigal/ResumeBuilder-IOS-APP#226 on the founder's yes. Not merged. No archive.
Current Phase: Payments v2, launch preparation. Go or no-go: `docs/qa/2026-10-31-ios-go-no-go.md`, verdict NO-GO for App Review.
Active Story: T1, waiting on the founder for the StoreKit run on a real iPhone, the App Store Connect version decision and the demo account yes. PR pre-check done at 9e367c5: Codex clean, code-reviewer approved, 5 CodeRabbit findings confirmed. All five fixed and pushed on the founder's yes, in the commit after 9e367c5 (probe `internalID`, founder Xcode doc, sandbox matrix, todo). 709 XCTest, 0 failures, 11 skipped on that tree.
Last Completed Story: cached Pro state (paywall reads the server before hiding Pro, Pro comes back, `.noPlan` re-reads), hidden-tab score view (`ScoreViewPolicy`), required StoreKit run (`REQUIRE_STOREKIT_TESTS=1` fails, `StoreKit Tests` scheme, `StoreKitRequired.xctestplan`, local-only probe product).
Next Recommended Story: pre-check result on the new head, founder StoreKit run on a real iPhone, then TestFlight 1.6.0 and the sandbox matrix.
Blockers: 10 StoreKit tests cannot pass on the iOS 26.5 simulator, need a real iPhone or an older simulator; phone test not run; demo account likely at 9, not 0; ASC version decision; T2 marked all 15 v3 screenshots REGENERATE.
Last Validation: 2026-11-01 on a clean tree at 2ea9eae: result bundle Passed, 714 total (709 XCTest plus 5 Swift Testing), 703 passed, 0 failed, 11 skipped, iPhone 17 Pro, iOS 26.5. Release build succeeded at 9e367c5, no app source changed since. StoreKit Tests scheme through the Xcode app: 10 failed, 0 skipped (iOS 26.5 simulator bug, storekitd "not installed for development"). Phone test not run.
Last Updated: 2026-11-01

# 2026-10-30: Pricing v2, S6 QA and launch checklist (no code)

Status: S2 to S6 done on draft PR nadavyigal/ResumeBuilder-IOS-APP#226 (head d69a67c code); server on draft PR nadavyigal/new-ResumeBuilder-ai-#204 (ab8c8ee, Codex clean). Not merged; migration not applied.
Current Phase: Payments v2, launch preparation. Launch page: https://claude.ai/artifact/YavCxgtJ3fTtUsPUxLq3ED (plan "S6 as built").
Active Story: none in code. Paywall Terms link now opens Apple's standard EULA (6bf8b20, founder decision 2026-10-30). Waiting on the founder: migration yes, App Store Connect products, phone test; website Terms still describe the old Stripe plan (update later).
Last Completed Story: S6: re-ran every automated check on both heads, wrote the final App Store Connect checklist and launch order, and wrote the phone test (14 rows + C1 to C7).
Next Recommended Story: the 1.6.0 version bump and TestFlight archive once App Store Connect products exist; later, an App Store section on the website Terms.
Blockers: founder decisions above; real purchases need the App Store Connect products and the founder's phone.
Last Validation: iOS 6bf8b20: 686 tests, 0 failures, 11 skipped, Release build passes. Web ab8c8ee: lint 0 errors, tsc 24 old errors, jest 1,165 pass, build passes, 4 local Postgres tests pass.
Last Updated: 2026-10-30

# 2026-10-30: Pricing v2, S5 analytics funnel (same draft PRs)

Status: S5 iOS commit 778fb89 on draft PR nadavyigal/ResumeBuilder-IOS-APP#226; web commit 5cc86cb on draft PR nadavyigal/new-ResumeBuilder-ai-#204. Not merged; migration not applied.
Current Phase: Payments v2 (plan "S5 as built" note).
Active Story: S5 pre-check. Funnel insight saved in PostHog 270848: Y9EUhHmW (https://us.posthog.com/project/270848/insights/Y9EUhHmW), empty until 1.6.0 ships. Second-model review: no P0/P1; P2 (onboarding_started would fire for existing users after the update) fixed in c660808. Web: Codex P2 (duplicate cancellation events on Apple retries) fixed in web a904f2e. iOS Codex on 6253985: P2 (a failed preview blocked the paywall and so the server PDF) fixed in aec3a1e.
Last Completed Story: S5 events: onboarding_started, cv_uploaded (file/sample), match_score_viewed (own/sample), pdf_preview_viewed, paywall_viewed, export_completed (grant/pack/subscription/ungated, from the server's new welcome_grant source). Old names keep firing.
Next Recommended Story: S6 QA and Sandbox on the founder's phone.
Blockers: founder yes to apply the S1 migration; ASC products before Sandbox; one Xcode run for the 10 StoreKitSessionTests; one real test account end to end in PostHog (needs a real sign-in, S6).
Last Validation: at aec3a1e: Release build succeeds; full suite 685 tests, 0 failures, 11 skipped, iPhone 17 Pro, iOS 26.5.
Last Updated: 2026-10-30

# 2026-10-30: Pricing v2, S4 Home headline, sample CV, LinkedIn hint (same draft PR)

Status: S4 on branch `claude/resumely-pricing-v2`, code commit 351a507, draft PR nadavyigal/ResumeBuilder-IOS-APP#226 (S2 + S3 + S4). Not merged.
Current Phase: Payments v2 (plan "S4 as built" note).
Active Story: S4 review. Codex on d22750a: P1 (Plan UI belongs in Features/V2) and P2 (late credits reply could land on the next account), fixed in 547b86e. Second-model review on 351a507: P0 (S4 state inside #if DEBUG broke Release builds), fixed in 547b86e and verified with a Release build; VoiceOver label for the sample score; empty test replaced. Codex on aadca56: P2 (Pro stayed on sale if active Pro was reported after the sheet loaded), fixed in 3d36920.
Last Completed Story: S4: Home leads with "Check any job, free, as often as you like." and "Your Match Score is an estimate."; "Try a sample CV" sheet (made-up CV, job and score 64, labelled as an example, bundled, no network, then opens the file picker); LinkedIn "Save to PDF" hint with a 3-step How sheet; upload unchanged; EN/HE screenshots in `audit/pricing-v2-s4/`.
Next Recommended Story: S5 analytics contract and the saved PostHog funnel.
Blockers: founder yes to apply the S1 migration; ASC products before Sandbox (S6); one Xcode run for the 10 StoreKitSessionTests; LinkedIn steps not checked on a real iPhone.
Last Validation: at 3d36920: Release build (generic iOS Simulator) succeeds; full suite 678 tests, 0 failures, 11 skipped, iPhone 17 Pro, iOS 26.5.
Last Updated: 2026-10-30

Older entries: [tasks/archive/progress-to-2026-10-29.md](archive/progress-to-2026-10-29.md).
