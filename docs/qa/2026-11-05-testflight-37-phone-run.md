# Resumely 1.6.0 (37) TestFlight phone run, 2026-11-05

Founder's iPhone 17, iOS 27.0.1, internal TestFlight group "Resumely 1.6.0 Founder QA". Apple Sandbox. Evidence: founder screenshots, production ledger (`credit_transactions`, read-only), PostHog events, Vercel request logs.

Earlier rows (packs, cancel, restore, Pro buy, ownership, cancel, expiry, resubscribe) passed on build 36 between 1 and 3 Nov. That record is Codex T2's `audit/release-1.6.0/phone-testing-live.md` in the `aso/screenshots-v3` worktree (uncommitted there).

## Build

| Item | Result |
|---|---|
| Build | 1.6.0 (37), commit `342167f`, head of #226 with the usage refresh fix `80f36fc` |
| Archive | Release, succeeded. Bundle 1.6.0 / 37, `API_BASE_URL` production, no `.storekit` file, no test bundle |
| Upload | 09:45 Asia/Jerusalem, `xcodebuild -exportArchive`, `testFlightInternalTestingOnly` true. Upload succeeded |
| TestFlight | Ready to Test, added to the Founder QA group (internal only). No external group, no App Review |

## Rows

| Row | Check | Result | Evidence |
|---|---|---|---|
| 6 | Pro renews by itself | PASS | qa-pro resubscribed 3 Nov 11:35, server period 4 Nov 11:35 to 5 Nov 11:35, auto-renew on. Founder: Profile "renews Nov 5" |
| S3 fix | Export, then Me without relaunch: count +1 | PASS on 37 | Founder report, qa-pro. On 36 the count lagged until relaunch |
| 12 | Pay, close the app, reopen | PASS, weaker than written | 10:28:19 purchase started, 10:28:32 one +5 `resumely.exports.5.v2` Sandbox row, 10:28:34 one export debit, balance 4. The grant lands about 2 s after Apple's confirmation, before a person can close the app, so a kill before the grant was not reproduced |
| 27 | Relaunch twice, Restore | PASS | 10:31:44 the same transaction was re-sent at relaunch (`iap_verified`), server added no row. After Restore: one ledger row for the transaction, 12 rows, balance 4. Founder screenshot: 4 left |

## First attempt at row 12, not a failure

The founder closed the app at about 10:13 while Apple's sheet was still open. PostHog shows `paywall_viewed` at 10:12:10 and the next event `app_launched` at 10:13:57, with no `purchase_started`, and no 5-pack ever reached `/api/v1/iap/verify`. Apple dropped the purchase: no charge, no grant, balance 0 on the server and on Me. An earlier "4 left" report for that attempt was not supported by the ledger. Lesson: read the ledger before trusting a screen report of a number.

## Seen, not a release blocker

- With qa-pro's Pro on the same Apple ID, every qa-five launch sends that Pro to the server 1 to 4 times and gets 403 `account_mismatch`. Correct outcome, no grant, but it adds `iap_verify_failed` events. A family sharing one Apple ID would inflate that count.
- Restore on qa-five shows only "This subscription belongs to another Resumely account". Correct (matrix row 9), but a pack-only user might find it confusing.

## Still open before submitting 1.6.0

- StoreKit unit tests on a real phone: 1 passed, 9 failed on 1 Nov (Sandbox refused the local-file purchases). Not repeated today. The Sandbox rows above cover the same paths with Apple's real Sandbox.
- Rows 11 and 25 (refund, revoke): **not run, founder's named yes 2026-11-05.** No Sandbox path sends a real `REFUND` or `REVOKE` for this app. What stands in their place: the web tests with signed payloads (`applies a verified REFUND once`, `applies REFUND_REVERSED as a re-grant`). The first real refund after launch is the true test.
- Rows 10, 17 (Ask to Buy), 20 to 22 (fair use at 40), 26, 28, 29 (airplane mode, network loss), 30, 31 (old packs): not run.

## Testing verdict

The six must-pass money rows (3, 5, 7, 12, 18, 27) passed across builds 36 and 37. Row 18 is covered by the 3 Nov resubscribe: after expiry the paywall offered Pro and the founder bought it there. Testing is closed for submission.
- WP-79 S6 demo account to 0, S7 accountant, S8 screenshots from #225 and submit.
