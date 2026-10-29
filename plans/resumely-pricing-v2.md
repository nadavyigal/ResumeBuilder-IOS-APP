# Resumely pricing v2: plan

Status: PLAN ONLY, waiting for founder approval. No code written. Written 2026-10-29, revised 2026-10-29 (v2), amended 2026-10-29 (v3, advice A1 to A5 accepted).
iOS branch: `claude/resumely-pricing-v2` (worktree `/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-pricing-v2`).
Web branch: a new worktree `web-pricing-v2` from `main` (the server half lives in `nadavyigal/new-ResumeBuilder-ai-`).

Objective: replace the 1/5/10 export packs with a welcome grant of 3 free PDF exports, two cheaper export packs and a $9.99 monthly plan, keep the Match Score unlimited and free for everyone, show the paywall only after real value, add a sample-CV start, and make one PostHog funnel from new user to paid user.

## Founder changes in v2 (2026-10-29)

1. **Match Score is unlimited for everyone.** No score credits, no score metering, no score paywall. Only PDF exports are counted and paid.
2. **Upload stays file-only.** No paste-text path, no change to `/api/upload-resume`.

## Founder changes in v3 (2026-10-29): advice accepted

- **A1:** welcome grant is **3** free PDF exports (was 5). One server constant, `WELCOME_EXPORTS = 3`.
- **A2:** packs are the main offer. The paywall lists the 14-pack first, preselected, marked "Best value", then the 5-pack, then Pro. Pro gets a 60-day review (section 12).
- **A3:** "Check any job, free, as often as you like" leads on Home (S4) and on the App Store page (checklist item 13).
- **A4:** LinkedIn PDF hint under Upload, with a "How?" sheet (founder chose it 2026-10-29). Copy only.
- **A5:** the post-launch funnel is saved as a PostHog insight in S5, with a 30-day read.

What v2 removed from v1: the `score_unlocks` table, `score_balance`, `authorizeScore()`, every change to the score routes, the 402 for scores, scores inside packs, the "scores ran out before a preview" card, the paste start and the upload route change. Old decisions D2 and D5 are gone.

---

## S1 as built (2026-10-29), web PR nadavyigal/new-ResumeBuilder-ai-#204 (draft)

Two changes from section 4, both simpler and both safe:
- **No `PRICING_V2_ENABLED` switch.** `unlock_export` and `grant_apple_purchase` keep their signatures, so the server code works before and after the migration. Charging is still decided only by `EXPORT_CREDITS_ENABLED` / `EXPORT_CREDITS_USER_IDS`. Once the migration is applied, the only user-visible change is the welcome grant.
- **The two constants live in SQL**, `welcome_export_grant()` = 3 and `subscription_export_cap()` = 40. Changing one is a one-line migration (no app build, no deploy).
- Retired v1 packs are still granted when a paid transaction arrives (never refuse money Apple took); they are retired by "Remove from Sale" in App Store Connect and by the app not loading them.
- The migration `20261029120000_pricing_v2.sql` is written, **not applied**.

---

## S2 as built (2026-10-29), branch `claude/resumely-pricing-v2`

- `ResumelyProducts` replaces `ExportCreditProducts`: sale order 14-pack, 5-pack (`resumely.exports.5.v2`), Pro. The v1 packs are never loaded, but a paid, unfinished v1 transaction is still delivered (the server still grants it).
- Pro: `purchase()` buys it like a pack; `refreshEntitlements()` sends Apple's current Pro transaction to `/api/v1/iap/verify` at launch and after sign-in; `restorePurchases()` = `AppStore.sync()`, then unfinished transactions, then the current plan; renewals and refunds from `Transaction.updates` are delivered and re-read the plan.
- The app shows Pro from `GET /api/v1/credits` (`AppState.subscription`); the server still decides every export.
- Pro bought under another Resumely account: "This subscription belongs to another Resumely account. Sign in with that account." The transaction stays unfinished for that account and never locks this one.
- An expired or refunded Pro transaction does not count as a grant, so it cannot resume a waiting paywall.
- The paywall sheet sells the two packs only. Pro joins it in S3. `paywallEligibility(for:)` also moves to S3.
- **Changes from section 5:** `Resumely.storekit` lives in the test folder (the test bundle needs it) and is **not** wired into the Run scheme, so a run from Xcode on your phone still uses real Sandbox in S6. To try it in the simulator: Edit Scheme > Run > Options > StoreKit Configuration.
- **Not verified from the command line:** the 10 `StoreKitSessionTests` (buy, renew, expire, refund, restore). `xcodebuild test` on iOS 26.5 does not hand the `.storekit` file to the simulator (Apple forums thread 826971), so they skip there. They need one run from Xcode (Product > Test).

---

## S3 as built (2026-10-29), same branch, PR nadavyigal/ResumeBuilder-IOS-APP#226

- **Paywall sheet:** 14-pack first, preselected, "Best value"; 5-pack; Pro last with "/ month" and "Renews monthly until cancelled." One Continue button. Restore Purchases, Terms of Use and Privacy Policy links (the app's own legal pages). The estimate footer and "Match Scores stay free and unlimited." are on the sheet. With Pro already active, the Pro row is hidden and a fair-use note shows instead.
- **Copy change from 3.2:** the body drops "in under a minute" until S6 times it on a real phone. Hebrew Pro strings start with "מנוי" so a Latin first word cannot flip the line (seen in the first RTL screenshot).
- **When the paywall opens:** only after this account saw its own Match Score (score panel on the Optimized screen, or the diagnosis) and a rendered preview. Otherwise a one-line notice asks the user to look first. The design preview has no score, so there only the preview is required. If the Optimized screen has no score to show, the paywall opens rather than leaving a dead end.
- **Guest gap (D5):** an optimization needs a session, so a no-session export happens only when the session is lost (sign-out, failed token refresh) while the result stays on screen. That path exported the on-screen copy for free. It now asks for a free account. Code fix plus test; not reproduced on the simulator, which would need a real sign-in on production.
- **Profile:** a "Plan" section for accounts: Pro with its renewal or end date and fair-use count, or "N PDF downloads left"; Manage subscription (Apple's sheet) when Pro is active; Restore Purchases with a result message. `PaywallView.swift` (dead scaffold) and `CreditsView.swift` (only it linked there) are deleted.
- **Harness:** `--smoke-paywall` now shows the 3 offers; add `--smoke-paywall-sub` for the Pro-cap variant, `--smoke-he` for Hebrew. Screenshots in `audit/pricing-v2-s3/`.
- **SSR templates:** the web registry has all 4 SSR templates (`card`, `minimal`, `sidebar`, `timeline`); I could not find which 3 are missing from code alone. If a chosen template fails at export, the app falls back to the server PDF, so the user still gets a PDF, in a plain layout, after a credit is spent. S6 exports one CV per template on a real phone.

---

## 1. What exists today (read from the code, 2026-10-29)

| Area | Fact | Where |
|---|---|---|
| Unit | 1 export credit unlocks 1 optimization forever (every format, every re-download). | web `src/lib/export-credits.ts`, `supabase/migrations/20261021120000_export_credits.sql` |
| Free | New profiles start with `credit_balance = 1` (column default). | same migration, step 1 |
| Gate | Charged only when `EXPORT_CREDITS_ENABLED=true` (or the account is in `EXPORT_CREDITS_USER_IDS`) **and** the request sends `X-Resumely-Client: ios`. Web stays free. | `isExportCharged()` |
| Products | `resumely.exports.1/.5/.10`, consumable only. Server maps ID to credits; unknown IDs grant 0. | web `src/lib/iap.ts:22`, iOS `Core/Payments/StoreKitManager.swift:8` |
| Verify | `POST /api/v1/iap/verify`: Apple signature, bundle, env, `type === 'Consumable'`, `appAccountToken == user.id`, not revoked, then `grant_apple_purchase` (one transaction ID grants once). | web `src/app/api/v1/iap/verify/route.ts` |
| Notifications | Only `REFUND` / `REFUND_REVERSED` handled. Everything else is logged and ignored. | web `src/app/api/v1/iap/notifications/route.ts` |
| Match Score | Not metered, only rate limited. **Stays this way.** | web `src/app/api/ats/score/route.ts:60`, `src/app/api/public/ats-check/route.ts` |
| Paywall | `ExportPaywallSheet` opens on a 402 from `/api/v1/exports/unlock`. Has Restore. Filters products to `.consumable`. | iOS `Features/V2/Paywall/ExportPaywallSheet.swift` |
| Parked | `Features/Profile/PaywallView.swift` is a dead 100/500/2500 scaffold. | delete in S3 |
| Retired-ID test | `testOldProductIdsAreNeverSold` checks `credits_basic/saver/super`. | iOS `ExportCreditsTests.swift:344` |
| Upload | `/api/upload-resume` takes a file only. **Stays this way.** | web `src/app/api/upload-resume/route.ts:60` |
| Analytics | Has `paywall_shown`, `purchase_started/completed/failed/cancelled/pending`, `export_success`, `optimized_preview_rendered`, `free_ats_completed`, `diagnosis_viewed`, `fit_check_completed`. No `onboarding_started`, `cv_uploaded`, `match_score_viewed`, subscription events. | iOS `Core/Analytics/AnalyticsService.swift:122-242` |

---

## 2. The new model

### 2.1 Units

- **PDF export (tailored CV)** = one optimization unlocked for PDF/DOCX forever. Same meaning as today's credit, so nothing already unlocked breaks. Re-downloads stay free.
- **Match Score** = free and unlimited for everyone (guests, anonymous, accounts), protected only by today's rate limits.

### 2.2 Products

| Product ID (proposed) | Type | Gives | Price | Per export |
|---|---|---|---|---|
| `resumely.exports.5.v2` | Consumable | 5 PDF exports | $3.99 (₪12.90) | $0.80 |
| `resumely.exports.14` | Consumable | 14 PDF exports | $7.99 (you pick the ₪ tier) | $0.57 |
| `resumely.pro.monthly` | Auto-renewable, group **Resumely Pro** | Unlimited PDF exports within fair use | $9.99 / month | $0.25 at 40 |

Retired forever (server grants 0 for new sales, app never loads them): `resumely.exports.1`, `resumely.exports.5`, `resumely.exports.10`, plus the older `credits_basic`, `credits_saver`, `credits_super`. Unfinished old transactions that were already paid are still delivered at their old amount (see 4.4).

### 2.3 Welcome grant

- **3 free PDF exports** (`WELCOME_EXPORTS = 3`), once per account, granted on the server. Changing the number later is a server change only, no app build.
- Idempotency: a `welcome_grants` table with `user_id` as primary key. The grant inserts the row and adds the credits in one transaction; a second call does nothing. Reinstall or a new device signs into the same account, so it can never re-grant.
- When: lazily, inside every credit read or spend, so no signup hook is needed and old accounts get it the first time they open v2.
- Real accounts only. Exports already require a real account (anonymous sessions get `401 account_required`), so anonymous users need nothing here; they get the grant when they create the account.
- Known gap: a person can create a second account for another 3. Apple DeviceCheck can mark "this device already got a grant", but it needs a key in App Store Connect and server work. Recommended: ship without it, add it only if PostHog shows grant farming. (D3.)
- The column default `credit_balance = 1` goes to `0`, so a new account gets exactly 3, not 4.

### 2.4 Subscription and fair use

- Entitlement lives on the server: new table `subscriptions` (`original_transaction_id` unique, `user_id`, `product_id`, `expires_at`, `status`, `auto_renew`, `environment`, `grace_until`).
- Active = `status in ('active','grace')` and `now() < coalesce(grace_until, expires_at)`.
- **Fair-use cap (proposal): 40 PDF exports per 30-day period**, counted from the current period start. Re-downloads of an already-unlocked CV never count. A heavy job seeker sends 20 to 30 tailored applications a month, so 40 is above real use. The cost per export is mostly the optimization before it; I do not know your OpenAI cost per optimization (my guess: $0.05 to $0.15). Check the OpenAI dashboard before approving. (D2.)
- Over the cap: spend pack credits if the user has any; otherwise a calm message with the reset date. Never a purchase prompt for a subscriber.
- Spend order: subscription first, then pack and welcome credits (so credits are kept for after a cancel).

### 2.5 Existing users

Recommended: **every existing account also gets the 3-export welcome grant once, on top of what it holds.** Unlocked exports stay unlocked. Anyone who bought an old pack keeps every credit. Most accounts hold 0 or 1 credit and there are very few users, so the cost is tiny and nobody feels penalized by the price drop. (D1. Alternative: top up to 5 instead of adding 5.)

Before the migration runs, one read-only query lists `credit_transactions` where `source='apple_iap'`; if anyone bought an old pack, they keep everything and get the grant too. Not checked this session (Supabase connection needs sign-in).

---

## 3. Paywall placement and copy

### 3.1 Rule

1. The server decides if an export can be unlocked (402 when no credit, no active plan, or over the cap).
2. The app shows the paywall only when this account has seen its own Match Score **and** a PDF preview (flags stored per user id, set by the code that fires `match_score_viewed` and `pdf_preview_viewed`).
3. In the current flow the Export button sits on the Optimized screen next to the preview, so rule 2 almost always holds already. It stays as a guard for the other export entry points (History, Track, Submit Package). If one of those hits a 402 before the user ever saw a preview, it opens the Optimized preview first, not the paywall.

### 3.2 Copy draft (EN / HE). Final review in S3 with the taste pass.

Rules applied: Match Score always "estimate"; no ATS-beating claim; no guarantee; no competitor names. New since v1: the copy can say the Match Score stays free, which is a real reason to trust the app.

- Title: "Download more tailored CVs" / "הורידו עוד קורות חיים מותאמים"
- Body: "A free chatbot gives you text. Resumely gives you a ready PDF, right-to-left in Hebrew, in a clean template, with a before-and-after Match Score estimate. All on your phone, in under a minute." / "צ'אטבוט חינמי נותן לכם טקסט. Resumely נותן PDF מוכן, מימין לשמאל בעברית, בתבנית נקייה, עם הערכת ציון התאמה לפני ואחרי. הכול בטלפון, בפחות מדקה."
- Reassurance line: "Match Scores stay free and unlimited." / "ציוני ההתאמה נשארים בחינם וללא הגבלה."
- Plan row: "Pro, unlimited PDF downloads (fair use)" / "Pro, הורדות PDF ללא הגבלה (שימוש הוגן)"
- Pack rows, in this order: "14 tailored CVs" / "14 קורות חיים מותאמים" with badge "Best value" / "המשתלם ביותר"; "5 tailored CVs" / "5 קורות חיים מותאמים"
- Plan row (last): see above.
- Footer: "The Match Score is an estimate of how well your CV fits the job, not a hiring prediction." / "ציון ההתאמה הוא הערכה של התאמת קורות החיים למשרה, לא תחזית לקבלה לעבודה."
- Required by Apple for the subscription: price and period from StoreKit, "Renews monthly until cancelled", links to Terms of Use (EULA) and Privacy Policy, Restore Purchases.

"Under a minute" must be true: S6 times it on a real phone from Create to PDF preview. If it is not, the line changes.

Prices are always `product.displayPrice` from StoreKit. No typed price anywhere.

---

## 4. Server changes (web repo, story S1)

All behind a new switch `PRICING_V2_ENABLED` (default off) plus the existing test-account list, so merging changes nothing for users.

| File | Change |
|---|---|
| `supabase/migrations/<new>_pricing_v2.sql` | New: `welcome_grants`, `subscriptions`, `credit_balance` default 0, functions `ensure_welcome_grant`, `upsert_subscription`, `get_credit_state`; `unlock_export` gains the subscription and fair-use branch (`source: 'subscription'`). All SECURITY DEFINER, service_role only (same revoke pattern as today). **Applying it needs your explicit yes.** |
| `src/lib/iap.ts` | Product catalog v2: per ID `{ kind, exports }`; retired IDs grant nothing for new sales; `isSubscriptionProduct()`. |
| `src/app/api/v1/iap/verify/route.ts` | Accept `Auto-Renewable Subscription` for `resumely.pro.monthly`: check `appAccountToken`, upsert by `originalTransactionId`, return `{ status, entitlement: { active, expiresAt }, balance }`. Old-ID unfinished transactions: still granted at their old amount (they were paid). |
| `src/app/api/v1/iap/notifications/route.ts` | Handle `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `DID_FAIL_TO_RENEW` (grace), `EXPIRED`, `GRACE_PERIOD_EXPIRED`, `REFUND`/`REVOKE` for subscriptions. Emits server events (section 6). |
| `src/lib/export-credits.ts` | Charge check uses the v2 switch; result carries `source: 'subscription'`; welcome grant ensured before the spend. |
| `src/app/api/v1/credits/route.ts` | Returns `{ balance, subscription: { active, expiresAt, periodExports, periodCap } }`. |
| Tests | Extend `tests/lib/iap.test.ts`, `tests/api/iap-verify-route.test.ts`, `tests/api/export-unlock-route.test.ts`, `tests/api/download-export-gate.test.ts`, `tests/api/bulk-export-credit-gate.test.ts`; new `tests/api/iap-notifications-subscription.test.ts`, `tests/lib/welcome-grant.test.ts`. |

Not touched: score routes (`/api/public/ats-check`, `/api/ats/score`, `/api/ats/rescan`), `/api/optimize`, `/api/upload-resume`.

Env vars to add in Vercel (I do not set them): `PRICING_V2_ENABLED`, and reuse `APPLE_IAP_*`.

### 4.4 Switch-over

1. Ship server with switch off. 2. Founder creates products in ASC. 3. Sandbox on test accounts. 4. Ship iOS 1.6.0. 5. Turn `PRICING_V2_ENABLED` on when 1.6.0 is live. Old app versions (1.5.6) still ask for the old IDs; once those are "Removed from Sale", their paywall shows "not available". (D4: remove on day one, recommended, since the old prices are 3x higher.)

---

## 5. iOS changes (stories S2 to S5)

| File | Change | Story |
|---|---|---|
| `Core/Payments/StoreKitManager.swift` | `ExportCreditProducts` becomes `ResumelyProducts` (packs + subscription, retired list). Load mixed types. `purchase()` handles subscriptions. New `refreshEntitlements()` sends `Transaction.currentEntitlements` to the server at launch and after sign-in. `restorePurchases()` = `AppStore.sync()` then entitlements + unfinished. `deliverInBackground` accepts subscription renewals. | S2 |
| `Core/Payments/ReceiptVerifier.swift` | Decode `entitlement`. New error `ownedByAnotherAccount`: "This subscription belongs to another Resumely account. Sign in with that account." | S2 |
| `Core/Payments/ExportCredits.swift` | Unlock response may say `source: subscription`. | S2 |
| `App/AppState.swift` | `subscription` state, `paywallEligibility(for:)`. | S2/S3 |
| `Features/V2/Paywall/ExportPaywallSheet.swift` | Redesign: 14-pack first, preselected, "Best value" badge; then 5-pack; then Pro as the last row. Copy from 3.2, legal links, Restore. | S3 |
| `Features/V2/Paywall/PaywallSmokeHarness.swift` | Fixture offers for the 3 new products; `--smoke-paywall-sub` variant showing an active plan; Hebrew via `--smoke-he`. | S3 |
| `Features/Profile/PaywallView.swift` | Delete (dead scaffold). Profile gains a "Plan" row: Pro until date / exports left / Restore / Manage subscription (`showManageSubscriptions`). | S3 |
| `ResumeBuilder IOS APP/Resumely.storekit` (new) | Local StoreKit config: 2 consumables, 1 subscription group with the monthly plan, accelerated renewal. Debug scheme only. | S2 |
| `Features/V2/Home/HomeTabView.swift`, `UploadSheetView.swift` | Two starts: Upload file (unchanged path) and Try a sample CV. Home headline (A3): "Check any job, free, as often as you like." / "בדקו התאמה לכל משרה, בחינם, כמה שתרצו." with the subline "Your Match Score is an estimate." / "ציון ההתאמה הוא הערכה." LinkedIn hint under Upload (A4): "No CV file? Save your LinkedIn profile as PDF." / "אין לכם קובץ קורות חיים? שמרו את פרופיל הלינקדאין כ-PDF." with a "How?" / "איך?" sheet: 1. Open linkedin.com in Safari (not the LinkedIn app) and go to your profile. 2. Tap More, then Save to PDF. 3. Save the file to Files, then come back and tap Upload. Text only; the steps are re-checked on a real iPhone in S4 before shipping. | S4 |
| `Features/V2/Home/SampleCV/` (new) | Bundled Hebrew + English sample CV and sample job with a **precomputed** Match Score: no server call, no AI cost, shows in under a second, then "Now try with your CV". | S4 |
| `Core/Analytics/AnalyticsService.swift` | Event contract from section 6. | S5 |
| `Localizable` catalog | All new strings EN + HE, RTL checked in harness screenshots. | S3/S4 |
| Tests | `ExportCreditsTests.swift` (retired IDs extended to the 3 old pack IDs, new catalog and order), new `SubscriptionEntitlementTests.swift`, `PaywallEligibilityTests.swift`, `WelcomeGrantDisplayTests.swift`, StoreKitTest `SKTestSession` tests for buy / renew / expire / refund / restore against the `.storekit` file. | S2 to S5 |

### 5.1 The guest export gap (must verify in S3)

`authorizeExport` lets a guest **with no session** skip the unlock and export the on-screen copy for free (`ExportCredits.swift`, comment on spec section 3, E6). If a no-session guest can reach a PDF today, any price is bypassable. Now that exports are the only paid thing, this matters more than in v1. S3 starts by checking this on the simulator. If reachable, the export button asks for a free account (Sign in with Apple, one tap), which also lands the 3 free exports. (D5.)

---

## 6. Analytics contract (PostHog 270848)

Scheme: `snake_case`, `object_action` in past tense, one event per funnel step, same `distinct_id` (Supabase user id after identify). Properties never carry CV text, email or names.

| Event | Fired by | Where | Properties |
|---|---|---|---|
| `onboarding_started` | app | first Home appear per install | `entry` |
| `cv_uploaded` | app | after a successful file upload or sample load | `method: file \| sample` |
| `match_score_viewed` | app | score card on screen | `source: sample \| own`, `score_bucket` |
| `pdf_preview_viewed` | app | Optimized preview rendered | `optimization_id`, `template` |
| `free_grant_used` | server | the export that takes the welcome grant to 0 | `exports_used: 3` |
| `paywall_viewed` | app | sheet appears | `entry_point`, `balance` |
| `purchase_started` | app | buy tapped | `product_id` |
| `purchase_completed` | app | after server grant | `product_id`, `price`, `currency` |
| `purchase_failed` | app | StoreKit or server failure | `product_id`, `reason` |
| `subscription_started` | server | first verify of a new original transaction | `product_id`, `environment` |
| `subscription_renewed` | server | `DID_RENEW` | `product_id` |
| `subscription_cancelled` | server | auto-renew turned off, and `EXPIRED` | `reason` |
| `export_completed` | app | file handed to the share sheet | `optimization_id`, `source: grant \| pack \| subscription \| ungated` |

`cv_uploaded` keeps the `method` property you asked for; `paste` is not a value because paste is out of scope. Old names (`paywall_shown`, `export_success`, `resume_uploaded`, `free_ats_completed`) keep firing in 1.6.0 so current dashboards do not break, and are removed in 1.6.1. `purchase_cancelled` and `purchase_pending` stay. Funnel: `onboarding_started → cv_uploaded → match_score_viewed → pdf_preview_viewed → export_completed → free_grant_used → paywall_viewed → purchase_completed`.

Unverified: that the server `distinct_id` (user id) and the app's identified id are the same person in PostHog. S5 checks one test account end to end before relying on server events in the funnel.

---

## 7. Stories and PRs

One story at a time; I stop after each with evidence.

| Story | Repo | Done means |
|---|---|---|
| S1 Server pricing v2 | web | migration file written (not applied), grant, subscription entitlement, verify + notifications, tests green, switch off |
| S2 StoreKit v2 + entitlements | iOS | new catalog, subscription buy/restore/renew/expire, `.storekit`, unit + SKTestSession tests green |
| S3 Paywall placement + copy | iOS | eligibility rule, redesigned sheet EN/HE, guest gap decided, Profile plan row |
| S4 Sample CV start + Home headline + LinkedIn hint | iOS | sample score in < 1 s, free-scores headline, LinkedIn hint and How sheet, EN/HE RTL screenshots |
| S5 Analytics | iOS + web | contract above, one test account seen end to end in PostHog, funnel insight saved in PostHog 270848 (A5) |
| S6 QA | both | test matrix below, timing check, App Store Connect checklist final |

PRs: two **draft** PRs, one per repo, one commit series per story, each with the GLOBAL-WORKFLOWS 7b pre-check. Not merged. No App Store Connect changes by me.

---

## 8. Test plan

Unit (automated):
- Welcome grant: first call grants 3; second call, reinstall (same user), new device (same user) grant nothing; anonymous gets nothing until the account is real; conversion grants once.
- Credit math: 5-pack adds 5, 14-pack adds 14; quantity > 1; replay grants once; refund deducts outstanding only; export unlock idempotent; re-download free.
- Entitlements: active, grace, expired, refunded, renewed (new expiry), cancelled-but-not-expired stays active, export 41 in a period falls back to credits then refuses with reset date, subscription spent before credits.
- Match Score: no route returns 402 for a score; a user at 0 credits can still score.
- Retired IDs: all 6 never loaded by the app, never granted by the server for new sales, old unfinished transactions still delivered.
- Paywall eligibility: never before own score + preview; sample score does not count.

Sandbox matrix (S6, on your phone signed into a Sandbox tester; I cannot type Apple passwords):

| # | Flow | Expect |
|---|---|---|
| 1 | New account | 3 free exports shown; scores unlimited |
| 2 | Use all 3 exports | paywall only after score + preview |
| 3 | Buy 5-pack | +5, export resumes without a second tap |
| 4 | Buy 14-pack | +14 |
| 5 | Subscribe | unlimited exports, Profile shows renew date |
| 6 | Renewal (Sandbox month = 5 min) | `subscription_renewed`, still active |
| 7 | Cancel in Settings, let expire | `subscription_cancelled`, falls back to credits, then paywall |
| 8 | Restore on reinstall | subscription back; credits back on sign-in |
| 9 | Restore on another account | "belongs to another account" message, no grant |
| 10 | Ask to Buy / pending | sheet waits, resumes on approval |
| 11 | Refund (Sandbox refund request) | credits deducted / entitlement off |
| 12 | Kill app mid-purchase | delivered at next launch, no double charge |
| 13 | Old 1.5.6 build | old IDs not sold after removal; no crash |
| 14 | Score at 0 credits | score works, no paywall |

Local (simulator, `.storekit`): rows 1 to 8 with StoreKit Testing, but the server cannot verify Xcode-signed transactions, so local runs test the app half only. Real grants need real Sandbox.

Regression: full `xcodebuild test`, web `npm run lint`, `npx tsc --noEmit`, `npm run build`, jest.

---

## 9. Risks

1. **Server cannot verify local `.storekit` transactions.** End-to-end needs the ASC products first. Blocks S6 until you create them.
2. **Guest no-session export bypass** (5.1). Exports are now the only paid thing, so this could make every price moot.
3. **Even 3 free exports may cover a light user's whole search.** Watched with the A5 funnel; the number is a server constant.
4. **Fair-use number is a guess** without OpenAI cost per optimization.
5. **Unlimited scores cost AI calls with no revenue.** Today's rate limits stay; watch the scoring line in the OpenAI bill after launch.
6. **Grant farming** via new accounts (2.3). Mitigation ready (DeviceCheck) but not built.
7. **Israel VAT.** ₪ prices include 18% VAT; after VAT and 15% Apple commission, $9.99 nets about $7, a 5-pack about $2.80, a 14-pack about $5.60. $1,000/month net is about 140 subscribers, or about 180 14-packs, or a mix. Estimate from public rates, not from your payout report.
8. **Missing SSR PDF templates.** I did not find the note in this repo's tasks files. If an export picks one of the 3 missing templates, the paywall would charge for an export that falls back or fails. S3 checks which templates the export can select and flags it; not fixed here.
9. **App Review**: subscription paywall must show price, period, auto-renew text, EULA and privacy links, and Restore. Covered in 3.2.

---

## 10. App Store Connect checklist (you do this; I touch nothing)

1. **Small Business Program**: enroll at developer.apple.com/app-store/small-business-program (15% instead of 30%).
2. **Paid Apps agreement, tax and banking** active (confirm).
3. **Consumable** `resumely.exports.5.v2`: reference name "5 tailored CVs v2", price $3.99 (₪12.90 tier), display name EN "5 tailored CVs" / HE "5 קורות חיים מותאמים", description EN "Five tailored CV downloads as PDF." / HE "חמש הורדות PDF של קורות חיים מותאמים.", review screenshot of the paywall.
4. **Consumable** `resumely.exports.14`: same shape, $7.99, "14 tailored CVs" / "14 קורות חיים מותאמים", description EN "Fourteen tailored CV downloads as PDF." / HE "ארבע עשרה הורדות PDF של קורות חיים מותאמים.". Pick the ₪24.90 or ₪26.90 tier.
5. **Subscription group** "Resumely Pro" (new).
6. **Auto-renewable** `resumely.pro.monthly` in that group: 1 month, $9.99, level 1, display name EN "Pro monthly" / HE "Pro חודשי", description EN "Unlimited tailored CV downloads, fair use." / HE "הורדות קורות חיים מותאמים ללא הגבלה, בשימוש הוגן.". Billing grace period on, 16 days. No free trial (the welcome grant is the trial).
7. **Remove from Sale** `resumely.exports.1`, `.5`, `.10` (D4). Do not delete them.
8. **App Store Server Notifications V2**: Production and Sandbox URL = `https://<prod host>/api/v1/iap/notifications` (check it is already set; subscriptions need it).
9. **Metadata**: mention the subscription in the description; add Terms of Use (Apple standard EULA is fine).
10. **Sandbox tester** with accelerated renewal.
11. **Attach** all three products to version 1.6.0 before submitting.
12. Review note (paste): "Match Scores are free and unlimited. Every new account gets 3 free tailored CV downloads as PDF; after that, PDF downloads need a pack or the monthly plan. The demo account has no free downloads left: open a saved result and tap Export to reach the purchase screen. The Match Score is shown as an estimate. Restore Purchases is on the purchase screen and in Profile."
13. **App Store page copy (A3):** first line of the description and the promotional text lead with free scores. EN: "Check any job, free, as often as you like. Get a Match Score estimate, then a tailored Hebrew or English PDF in under a minute." HE: "בדקו התאמה לכל משרה, בחינם, כמה שתרצו. קבלו הערכת ציון התאמה, ואז PDF מותאם בעברית או באנגלית בפחות מדקה." (Promotional text changes without a new build.)

---

## 11. Decisions I need from you

| # | Question | My recommendation |
|---|---|---|
| D1 | Existing users | Add the 3-export welcome grant on top of current balance |
| D2 | Fair-use cap on Pro | 40 PDF exports per 30 days (check OpenAI cost first) |
| D3 | DeviceCheck against grant farming | Not now; add if data shows abuse |
| D4 | Old products | Remove from sale on 1.6.0 launch day |
| D5 | No-session guest export | If reachable, ask for a free account at export |

## 12. Advice (accepted 2026-10-29)

- **A1. 3 free exports.** Applied in 2.3. Move it back to 5 (or to 2) with one server constant if the A5 funnel says so.
- **A2. Packs first.** Applied in 3.2 and 5. Revenue plan counts packs, not Pro. **60-day rule:** if Pro has fewer than 10 paying subscribers 60 days after `PRICING_V2_ENABLED` turns on, remove it from the paywall and keep two packs.
- **A3. Free scores lead.** Applied in S4 (Home headline) and checklist item 13 (App Store page).
- **A4. LinkedIn PDF hint.** Applied in S4. The LinkedIn iPhone app has no Save to PDF; it works in Safari on LinkedIn's site (third-party guides, no official LinkedIn page found). S4 re-checks the 3 steps on a real iPhone; if LinkedIn changed them, the copy changes before shipping.
- **A5. One funnel to watch.** Applied in S5: a saved PostHog funnel `free_grant_used → paywall_viewed → purchase_completed`, read 30 days after launch. If under 10% of new accounts reach `free_grant_used`, the grant is too big for the usage; if over 50% reach it and under 2% of those buy, the price or the paywall copy is the problem.

## 13. Could not verify this session

- Production credit rows and whether anyone bought an old pack (Supabase MCP needs `/mcp` auth).
- PostHog identity join between app and server events.
- Whether the ASC notifications URL is already set.
- The "3 missing SSR templates" note: not found in this repo's task files.
- Real OpenAI cost per optimization.
