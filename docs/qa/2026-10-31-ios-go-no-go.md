# Resumely iOS 1.6.0 go or no-go, 2026-10-31

**Verdict: NO-GO for App Review.** The T1 fixes are pushed to draft #226, on your yes.

Payments are not complete. The 10 StoreKit tests have not passed, and the phone test has not run.

**New blocker found today:** the 10 StoreKit tests cannot pass on the iOS 26.5 simulator, not even from the Xcode app. The earlier plan assumed they could. They need a real iPhone or an older simulator. See "StoreKit run".

## What is true today

| Stage | State | Evidence |
|---|---|---|
| Code merged, web | Yes | #204 in web `origin/main` at `1a91c78` |
| Code deployed, web | Yes | Live: `/api/v1/iap/notifications` 405 on GET, `/api/v1/exports/unlock` 401 without a token |
| Migration applied | Yes | Production latest is `20261030094500`. Grant 3, cap 40, default 0 read back |
| Code merged, iOS | **No** | #226 is a draft |
| T1 fixes | **Pushed, not merged** | `d1d0f98` fixes, `c4c4b52` version bump, on the #226 branch |
| Feature enabled | **Not seen** | `EXPORT_CREDITS_ENABLED` is a Vercel setting. Designed off until launch step 8 |
| Unit tests | Pass | See Test results |
| StoreKit tests | **Not passed** | Skipped in the ordinary run. 10 failed, 0 skipped through the Xcode app on the iOS 26.5 simulator. Need a real iPhone or an older simulator |
| Real purchase on 1.6.0 | **None** | Phone test not run. Production has 0 welcome grants and 0 subscriptions |
| Available to users | **No** | Live version is 1.5.6, released 26 Oct (Apple lookup, 31 Oct) |

`scripts/validate-store-version.sh` now reports version drift: repo 1.6.0, store 1.5.6. This is expected. 1.6.0 is a planned release, not the shipped one.

## Final results

All on the final working tree, simulator iPhone 17 Pro, iOS 26.5, Xcode 26.5, 1.6.0 (36):

| Check | Result |
|---|---|
| Full suite | 708 XCTest, 0 failures, 11 skipped. 5 Swift Testing pass |
| Release build, generic iOS Simulator | Succeeded |
| `test_measurement_contract.py` | 7 pass |
| Paywall smoke, EN, sample offers | Both states correct: Pro offered, and Pro hidden with the fair-use note. Screenshots in `audit/pricing-v2-t1/`. Hebrew not re-shot, no copy changed |
| `StoreKit Tests` scheme, command line | 10 failed, by design: proves a skip is impossible |
| `StoreKit Tests` scheme, Xcode app | 10 failed, 0 skipped: the iOS 26.5 simulator bug |
| Web tests | Not run. No web change in this track |

Skipped tests, by name (a skipped test is not evidence):

1. `FitCheckViewModelTests.testLiveFitCheckEndToEndAgainstProduction`, old, needs live production
2. `StoreKitSessionTests.testAPackIsStillAConsumableGrant`
3. `StoreKitSessionTests.testARefundedPlanIsNotSent`
4. `StoreKitSessionTests.testARenewalIsSentAsTheCurrentPlan`
5. `StoreKitSessionTests.testAnExpiredPlanIsNotSent`
6. `StoreKitSessionTests.testBuyingProSendsItAndFinishesOnlyAfterTheGrant`
7. `StoreKitSessionTests.testGuestsSendNothing`
8. `StoreKitSessionTests.testLoadsTwoPacksThenProAndNoRetiredPack`
9. `StoreKitSessionTests.testProOfAnotherAccountIsNotFinishedAndDoesNotLock`
10. `StoreKitSessionTests.testRefreshSendsTheCurrentPlanOnly`
11. `StoreKitSessionTests.testRestoreOnAnotherAccountNamesTheOwner`

Failing tests were seen first for all three findings, on behaviour, not on compile errors.

## Review findings on #226

| Finding | Status |
|---|---|
| 1. Cached Pro state | Fixed, test-first. The sheet reads the server before hiding Pro. Pro comes back if the plan ended. `refreshEntitlements` re-reads on `.noPlan`. Profile Restore was never broken. |
| 2. Score seen in a hidden tab | Fixed, test-first. `ScoreViewPolicy` waits for the active tab and fires when it becomes active. |
| 3. Required StoreKit run | Fixed, test-first. `REQUIRE_STOREKIT_TESTS=1` fails instead of skipping. New `StoreKit Tests` scheme and `StoreKitRequired.xctestplan`. |

Limit of the evidence: finding 2's decision logic is tested, but the wiring inside `OptimizedResumeView` is not, because that needs a signed-in session. Sandbox matrix check C8 covers it.

Found on the way, also fixed: the old probe asked for `resumely.pro.monthly`, which now exists in App Store Connect. The probe passed with the local file not loaded, and a test hung on a real purchase call. The probe now uses a product that exists only in the local file.

Left as is: on a failed read the last known plan stands, so an offline user who just expired still sees Pro hidden until they retry. They could not buy offline anyway. The server's 402 also says `subscription_cap_reached`, which the app ignores. Using it would be cleaner, but it is not needed for this fix.

## StoreKit run

What I saw on 31 Oct, Xcode 26.5, iPhone 17 Pro, iOS 26.5, scheme `StoreKit Tests`, run through the Xcode app:

- `result = Failed`, 10 tests, 0 passed, 10 failed, 0 skipped.
- Every failure is `StoreKitProductsNotLoaded`.
- `storekitd` log: "Resumebuilder-IOS.ResumeBuilder-IOS-APP is not installed for development".

Meaning:
- The strict gate works. A skip is no longer possible, and that is how this showed up.
- This is not `xcodebuild` only, as the code and plan used to say. Apple forum reports (threads 826364, 826971, read through a search summary) call it an iOS 26.5 simulator runtime bug, known, with no workaround on that runtime. They report real devices and iOS 26.0 to 26.2 simulators working. I have not seen that myself.
- Only iOS 26.5 is installed here. Your brief keeps me on the simulator, so I did not install on a phone or download a runtime.

Also found: an app that sees real products while the local file is off would hang on a real purchase. The local-only probe stops that.

## Founder setup

| # | Step | Blocks |
|---|---|---|
| 1 | Run the StoreKit test on a real iPhone, `2026-10-31-founder-xcode-run.md`. Not on the iOS 26.5 simulator | Calling payments complete |
| 2 | Check the App Store Connect "Not seen" rows, pricing map section 8 | TestFlight, phone test |
| 3 | ASC decision below | TestFlight |
| 4 | Add the Terms of Use link to the description for 1.6.0 | App Review (subscription rule) |
| 5 | Create test accounts, add them to `EXPORT_CREDITS_USER_IDS`, redeploy | Phone test |
| 6 | Archive and upload 1.6.0 (36) after the commit | Phone test |
| 7 | Run `2026-10-31-sandbox-matrix.md` | Submission |
| 8 | Attach the 3 products, paste the review note, submit | Launch |

## Agent work

| # | Step | Needs |
|---|---|---|
| 1 | Commit and push T1 to #226 | Done |
| 2 | Refresh the PR body, ask for `@codex review`, run a second-model review, post the pre-check comment | Named yes: these send messages on the PR |
| 3 | Reply to the 3 review threads | Named yes, same reason |
| 4 | Prepare the demo account | Named yes, below |
| 5 | Read ledgers after each matrix block | Test account ids |
| 6 | Fix anything the phone test finds | Results |
| 7 | Later: fix stale copy, pricing map section 7 | Your go |

## Decision: draft 1.5.7 and pricing as 1.6.0

Facts:
- A version 1.5.7 draft was reported created on 29 Oct with the v3 screenshots and no build. I have not seen it. That is a report, not a live check.
- Pricing ships as 1.6.0.
- T2 has since marked all 15 v3 screenshots REGENERATE, and none are cleared for upload. Only en-US exists. See `audit/aso-v3-t2` on branch `aso/screenshots-v3`.

**Recommendation: change the draft's version number from 1.5.7 to 1.6.0 and use it for pricing. Do not ship a separate 1.5.7.**

Why: no 1.5.7 build exists. Building one means a whole review to ship only pictures, and those pictures are not cleared. One version keeps one review.

Then: swap in T2's cleared screenshots before you submit. Screenshots cannot change once it is in review.

I do not know that App Store Connect lets you edit the version number on this draft. My guess is yes while it is in Prepare for Submission. If it refuses, delete the 1.5.7 draft and create 1.6.0. That needs a fresh upload of the screenshots, and it would need your yes.

Your call. This changes App Store Connect, so I do nothing here.

## Decision: review demo account

The brief says it needs 3 exports. **The evidence says it holds 9, and 12 after its next sign-in.** Reasoning in pricing map section 4. This is an inference.

Exporting 12 CVs is not sensible. **Recommendation: say "yes, set the review demo account to 0".**

Order, because a reset alone is undone by the grant:
1. You confirm which account it is. I never print the email.
2. I read its balance and confirm the inference.
3. I run the one-time welcome grant for that account, then set it to 0 with a conditional one-row update.
4. I read it back.

These are 2 production writes. It must also be in `EXPORT_CREDITS_USER_IDS`, which I cannot see. Without that the reviewer never reaches the paywall.

## Decision: website Terms

Checked live on 31 Oct. Terms updated 23 Dec 2025 still say Premium $9 a month, Stripe, a 7-day refund, cancel in account settings, and a free tier of 1 optimization.

- The paywall is safe: it links Apple's EULA (your decision of 30 Oct).
- Onboarding still links these Terms, so a new 1.6.0 user is shown false payment terms.
- Not a build blocker, and a web change.

**Recommendation: ship the web fix before 1.6.0 goes live, not "later".** It is a separate web PR with no app build. Replace the pricing and refund sections with an App Store purchases section.

Exact legal wording is yours to approve.

## Named approvals I need

Paste any of these:

- `yes, run the pre-check on #226`
- `yes, set the review demo account to 0`
- `yes, add 39 test usage rows to account B`

## Taste check

Better for the user: a person whose Pro ended can resubscribe, and a score only counts when seen. Voice: no new user-facing copy. Slop: none found. Scope: the brief, plus the probe fix it forced. The hidden preview milestone was checked and is safe, `renderPreview` already waits for the active tab.
