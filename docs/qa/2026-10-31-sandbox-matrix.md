# Resumely 1.6.0 sandbox test matrix, 2026-10-31

Extends the S6 phone test on the launch page (rows 1 to 14, checks C1 to C7). S6 row numbers stay the same. New rows start at 15.

Nothing here has been run. Every row is open.

## Before you start

| # | Who | Step |
|---|---|---|
| 1 | Founder | Install 1.6.0 (36) on your phone from TestFlight, or run it from Xcode. |
| 2 | Founder | iPhone Settings, App Store, Sandbox Account: sign in with a Sandbox tester. Set renewal rate to the fastest. |
| 3 | Founder | Make 3 Resumely test accounts: **A** (packs), **B** (Pro), **C** (other account). |
| 4 | Founder | **Add the 3 user ids to `EXPORT_CREDITS_USER_IDS` in Vercel and redeploy.** Without this every export is `ungated`, nothing is spent, and rows 2 to 7 prove nothing. The launch page does not say this. |
| 5 | Founder | Send me the 3 user ids. I read their ledgers after each block, read-only. |
| 6 | Founder | Check App Store Connect Notifications V2 has the Sandbox URL `https://www.resumelybuilderai.com/api/v1/iap/notifications`. Rows 6, 7, 11 and 25 depend on it. |

Evidence codes: **S** screenshot, **L** ledger read by me, **P** PostHog event, **T** time noted.

Stop and send me the row number if money moves twice, credits are lost, or a paid purchase is not delivered after a relaunch.

## Packs, free exports, paywall

| # | Account | Do this | Pass means | Proof | Done |
|---|---|---|---|---|---|
| 1 | A | New account, open Profile | "3 PDF downloads left". Match Scores work. | S, L | [ ] |
| 2 | A | Export 3 CVs, then a 4th | Paywall opens only on the 4th, after score and preview. 14-pack preselected. | S | [ ] |
| 3 | A | Buy the 5-pack | Export finishes with no second tap. Balance 4. One ledger row +5. | S, L | [ ] |
| 4 | A | Buy the 14-pack | Balance goes up 14. Israel price shown is ₪, from Apple. | S, L | [ ] |
| 14 | A | Spend to 0, check a job | Score works, no paywall. | S | [ ] |
| 15 | A | Tap Continue on a pack, then Cancel in Apple's sheet | No charge. Sheet stays usable. `purchase_cancelled` once. Balance unchanged. | S, L, P | [ ] |
| 16 | A | Sandbox settings: make the purchase fail (Interrupted Purchase on the tester), then buy | Plain message, no credits, no double charge. A retry works. | S, L | [ ] |
| 10 | Child tester | Ask to Buy: buy a pack, approve later | Sheet says waiting, Continue is off. Reopen stays locked. Export resumes after approval. | S, L | [ ] |
| 17 | Child tester | Ask to Buy: decline | Lock ends within 48 hours. No credits. | S, L | [ ] |

## Pro

| # | Account | Do this | Pass means | Proof | Done |
|---|---|---|---|---|---|
| 5 | B | Subscribe | Exports spend nothing. Profile shows "Pro, renews" and a date and the fair-use count. | S, L | [ ] |
| 6 | B | Wait about 5 minutes | Still Pro, new date. `subscription_renewed` once. | S, P | [ ] |
| 7 | B | Cancel in Settings, wait for expiry | "Pro until" first, then downloads count, then the paywall. `subscription_cancelled` once. | S, P | [ ] |
| 18 | B | **New.** Keep the app in the background while Pro expires. At 0 downloads, export. | Paywall shows the **Pro row** and no fair-use note. This is finding 1 on a real phone. | S | [ ] |
| 19 | B | **New.** Same as 18, but Pro is still shown as hidden: tap Restore | Pro row comes back. "Nothing to restore" shows. | S | [ ] |
| 20 | B | Fair use: at 40 of 40 with 0 packs, export | Paywall shows packs, the fair-use note, no Pro row. Profile shows 40 of 40. | S, L | [ ] |
| 21 | B | Fair use: at 40 of 40 with pack credits | Export spends a pack credit, no paywall. | L | [ ] |
| 22 | B | Fair use: re-download a CV already unlocked at 40 of 40 | Free, nothing counted. | L | [ ] |

Rows 20 to 22 need 40 used exports. Exporting 40 by hand is not practical. **Needs a named yes:** "yes, add 39 test usage rows to account B". I then insert rows for that one account in `subscription_export_usage` and delete them after the row passes.

## Restore, accounts, sign-out

| # | Account | Do this | Pass means | Proof | Done |
|---|---|---|---|---|---|
| 8 | B | Delete the app, reinstall, sign in, Restore | Pro back. Packs back with the sign-in. | S | [ ] |
| 9 | C | Same phone, same Apple ID, sign in as C, Restore | "This subscription belongs to another Resumely account. Sign in with that account." No grant. C can still buy a pack. | S, L | [ ] |
| 23 | A then C | **New.** Sign out of A, sign in as C, open Profile | C sees its own balance. No A balance or plan leaks, not even for a moment. | S | [ ] |
| 24 | C then A | **New.** Sign out, sign back in as A | A's balance and any waiting purchase lock come back. 3 free downloads are not granted again. | S, L | [ ] |

## Refund and revocation

| # | Account | Do this | Pass means | Proof | Done |
|---|---|---|---|---|---|
| 11 | A, B | Refund a pack and a Pro purchase | Pack downloads go down by what is left. Pro turns off. | L | [ ] |
| 25 | B | Revocation (`REVOKE`) | Pro turns off. Nothing else changes. | L | [ ] |

**Known gap, rows 11 and 25.** The app has no refund button (`beginRefundRequest` is not used). I do not know a Sandbox path that sends a real `REFUND` or `REVOKE` for this app. My best guess: there is none without adding a debug button, and `REVOKE` needs Family Sharing, which these products do not use.

If you cannot trigger them, mark them **not run**, not passed. What stands in their place, and it is weaker: the web tests with signed payloads, `applies a verified REFUND once`, `applies REFUND_REVERSED as a re-grant`, and `testARefundedPlanIsNotSent` once the Xcode run passes. The first real refund after launch is the true test.

## Duplicate delivery and interruption

| # | Account | Do this | Pass means | Proof | Done |
|---|---|---|---|---|---|
| 12 | A | Pay, then kill the app before the grant | Delivered at next launch. No second charge. | L | [ ] |
| 26 | A | **New.** Airplane mode right after paying, reopen, turn network on | Sheet says the purchase went through and stays locked. Grant lands once, export resumes. | S, L | [ ] |
| 27 | A | **New.** After 12 or 26, relaunch twice and tap Restore | Ledger still has one row for that transaction. | L | [ ] |
| 28 | A | **New.** Grant lands, then kill the app during PDF generation. Reopen, Export the same CV. | No second credit spent. PDF is delivered. One `export_unlocks` row. | L | [ ] |
| 29 | A | **New.** Lose network during export after the unlock | Clear error. Next tap spends nothing. | S, L | [ ] |

## Old packs and old builds

| # | Account | Do this | Pass means | Proof | Done |
|---|---|---|---|---|---|
| 13 | Any | Old 1.5.6 build, after old packs are removed | No crash. Paywall has nothing to buy (expected, launch step 8). | S | [ ] |
| 30 | D (old tester) | **New.** On 1.5.6, buy an old pack, kill before the grant. Update to 1.6.0, open. | Delivered at the old amount. Old pack never shows on sale. | S, L | [ ] |
| 31 | Existing | **New.** Open 1.6.0 on an account with old credits | Keeps them, plus the 3 once. The sign-in after does not add 3 again. | L | [ ] |

Row 30 must run before old packs are removed from sale.

## Device-only checks (S6, unchanged)

| # | Do this | Pass means | Done |
|---|---|---|---|
| C1 | Run the StoreKit tests in Xcode | See `2026-10-31-founder-xcode-run.md`. Needs a real iPhone or an older simulator. The iOS 26.5 simulator cannot pass it. | [ ] |
| C2 | LinkedIn steps in Safari | "Save to PDF" reachable as written | [ ] |
| C3 | Sample CV to file picker | Picker opens after the sheet closes | [ ] |
| C4 | One export per template | No plain fallback PDF | [ ] |
| C5 | Funnel, live | Rows 1 to 3 show as one person | [ ] |
| C6 | Hebrew pass | RTL, nothing clipped | [ ] |
| C7 | Time it, 3 times on mobile data | If all under a minute the claim may return | [ ] |
| C8 | **New.** Open the app on Home with a saved CV. Do not open Optimized. Then open it. | No `match_score_viewed` before the tab opens, one after. Finding 2. | [ ] |

## Done means

- Every row passed, or is marked not run with a reason.
- Rows 3, 5, 7, 12, 18 and 27 must pass. These are the money and resubscribe paths.
- Rows 11 and 25 may stay not run only with your named yes.
