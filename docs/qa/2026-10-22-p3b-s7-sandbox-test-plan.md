# P3b S7: Sandbox purchase test and App Review submission

Written 2026-10-22. Owner: founder (taps and App Store Connect), Claude Code (database reads,
migrations after a named yes). No real money moves in this plan: TestFlight and App Review buy in
Sandbox (StoreKit spec F6). No paid sale before 2026-10-31 (EXD-037).

## 0. Before the test (in this order)

| # | Step | Who | Done when |
|---|---|---|---|
| 0.1 | Merge web #195, then #196, then retarget #197 to `main` and merge, then retarget #198 and merge (runbook: comment on web #195) | Founder yes for each | All four on `main`, Vercel production deployed |
| 0.2 | #174 history repair (`supabase/migrations_archive/README.md`), then apply `20261021120000_export_credits`, `20261022120000_harden_security_definer_grants`, `20261023120000_apple_iap_verification` | Founder named yes; Claude applies through the Supabase MCP | Claude reports the three versions in `schema_migrations` and the function grants |
| 0.3 | Vercel, Production env (Settings, Environment Variables): `APPLE_IAP_BUNDLE_ID=Resumebuilder-IOS.ResumeBuilder-IOS-APP`, `APPLE_IAP_APP_APPLE_ID=<App Store Connect, App Information, Apple ID (digits)>`, `APPLE_IAP_ALLOWED_ENVIRONMENTS=Production,Sandbox`, `EXPORT_CREDITS_USER_IDS=<test account id>,<App Review demo account id>`. Leave `EXPORT_CREDITS_ENABLED` unset. Delete `APPLE_VERIFY_TRANSACTIONS_URL` and `APPLE_VERIFY_BEARER_TOKEN` if present. Redeploy | Founder | Claude confirms `/api/v1/iap/verify` no longer answers 503 for a signed-in call |
| 0.4 | User ids: Supabase dashboard, Authentication, Users, search each email, copy the UUID | Founder | Two UUIDs in step 0.3 |

## 1. Create the three products (S5), App Store Connect

Apps, Resumely, Monetization, In-App Purchases, the blue "+":

| Type | Reference name | Product ID | Price (base United States) |
|---|---|---|---|
| Consumable | Resumely 1 export | `resumely.exports.1` | $3.99 |
| Consumable | Resumely 5 exports | `resumely.exports.5` | $12.99 |
| Consumable | Resumely 10 exports | `resumely.exports.10` | $19.99 |

For each one:
1. Availability: all countries where the app is sold.
2. Price Schedule: base country United States at the price above. Check that Israel shows the matching ILS tier (W3).
3. App Store Localization, English (U.S.): display name `1 tailored export` (or `5 tailored exports`, `10 tailored exports`); description `Exports one tailored résumé in any format, as often as you need.` (adjust the count).
4. Add Hebrew: display name `ייצוא מותאם אחד` / `5 ייצואים מותאמים` / `10 ייצואים מותאמים`; description `ייצוא קורות חיים מותאמים למשרה, בכל פורמט וכמה פעמים שצריך.`
5. Review Information: screenshot of the paywall sheet (Claude supplies it from the TestFlight build in step 3), review note: `One credit exports one tailored résumé. Credits never expire.`
6. Status must read "Ready to Submit". Product IDs can never be reused, so type them exactly.

Then App Information, App Store Server Notifications, Version 2:
- Production Server URL: `https://www.resumelybuilderai.com/api/v1/iap/notifications`
- Sandbox Server URL: the same URL.

Use the `www` host: the bare domain answers 307, and Apple does not follow redirects.

## 2. TestFlight build

Claude prepares the release branch with iOS #207 for **1.5.6**, using the usual release checklist. 1.5.5 carries the #205 and #206 session fixes without waiting on payments. **Build 1.5.6 only after web #195 is live in production:** the app calls `/api/v1/exports/unlock` before every export, and before #195 that route answers 404, so every export would fail. You archive and upload as usual.

## 3. The test, on your iPhone (about 15 minutes)

TestFlight purchases are Sandbox and free; the Apple sheet shows "[Environment: Sandbox]".

| # | Do | Expect |
|---|---|---|
| 3.1 | Install the TestFlight build. Sign in with the **test account** from step 0.3 (a fresh account, so its balance is 1) | Home as usual |
| 3.2 | Tailor a résumé, export it | PDF share sheet opens. The free credit is spent (balance 0) |
| 3.3 | Tailor a second résumé, export it | The paywall sheet opens: three packs with App Store prices, "Credits never expire.", the restore line, a close button. No PDF is made |
| 3.4 | Tap the close button | Sheet closes, no PDF |
| 3.5 | Export again, tap the 5-export pack, confirm the Sandbox sheet | The paywall closes and the PDF share sheet opens **without a second tap** |
| 3.6 | Export the same résumé again | Opens with no paywall and no charge (balance stays 4) |
| 3.7 | Switch the language to Hebrew, tailor a third résumé, export | Spends 1 (balance 3), no paywall |
| 3.8 | Optional, recovery: buy again with Wi-Fi and cellular turned off right after the Apple sheet confirms; reopen the app online | The credits appear after relaunch (the unfinished transaction is re-sent) |
| 3.9 | Tell Claude "S7 done" | Claude reads the ledger read-only: one `apple_iap` row, `product_id resumely.exports.5`, `environment Sandbox`, delta 5, and the `paywall_shown`, `purchase_completed`, `iap_verified` events in PostHog |

Stop and send Claude a screen recording if any row fails.

## 4. Submit for review

1. The App Review demo account must be in `EXPORT_CREDITS_USER_IDS`, and must sit one export away from the paywall. Claude sets its balance to 0 with a one-row update after your yes, so the reviewer sees the paywall on the first export.
2. Version page, "In-App Purchases and Subscriptions": select all three products.
3. App Review notes, add: `Export credits: sign in with the demo account below, tailor any résumé and tap Export. The export-credit sheet opens; buy any pack (Sandbox). One credit exports one tailored résumé, in any format, as often as needed. Credits never expire and stay on the account.`
4. Submit.

## 5. After approval, on or after 2026-10-31 (S8)

Your yes in that message: Vercel Production `EXPORT_CREDITS_ENABLED=true`, then empty `EXPORT_CREDITS_USER_IDS`. Kill switch: unset `EXPORT_CREDITS_ENABLED`; exports are free again at once, and balances are kept.

## Not covered

- Refund notifications: Sandbox refunds cannot be triggered from TestFlight. Server tests cover REFUND and REFUND_REVERSED (web #197, 16 local database checks). The first real refund is read in the day-7 review.
- Web checkout: Phase 3 (Paddle) is parked as of 2026-10-23 (vendor not decided; drafts #199 to #202). Web exports stay free.
