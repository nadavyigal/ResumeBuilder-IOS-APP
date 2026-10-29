# Resumely pricing v2: plan

Status: PLAN ONLY, waiting for founder approval. No code written. Written 2026-10-29.
iOS branch: `claude/resumely-pricing-v2` (worktree `/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-pricing-v2`).
Web branch: a new worktree `web-pricing-v2` from `main` (the server half lives in `nadavyigal/new-ResumeBuilder-ai-`).

Objective: replace the 1/5/10 export packs with a welcome grant, two cheaper packs and a $9.99 monthly plan, show the paywall only after real value, add paste and sample starts, and make one PostHog funnel from new user to paid user.

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
| Match Score | **Not metered at all.** Only rate limits (`/api/ats/score` in-memory, `/api/public/ats-check` per IP). | web `src/app/api/ats/score/route.ts:60` |
| Paywall | `ExportPaywallSheet` opens on a 402 from `/api/v1/exports/unlock`. Has Restore. Filters products to `.consumable`. | iOS `Features/V2/Paywall/ExportPaywallSheet.swift` |
| Parked | `Features/Profile/PaywallView.swift` is a dead 100/500/2500 scaffold. | delete in S3 |
| Retired-ID test | `testOldProductIdsAreNeverSold` checks `credits_basic/saver/super`. | iOS `ExportCreditsTests.swift:344` |
| Upload | `/api/upload-resume` takes a **file only** (`formData.get("resume")`). No text path. | web `src/app/api/upload-resume/route.ts:60` |
| Paste/sample | Was a "coming soon" affordance, replaced in July by location cues. `resume_upload_coming_soon_tapped` still exists. | iOS `Features/V2/Home/UploadSheetView.swift:183` |
| Analytics | Has `paywall_shown`, `purchase_started/completed/failed/cancelled/pending`, `export_success`, `optimized_preview_rendered`, `free_ats_completed`, `diagnosis_viewed`, `fit_check_completed`. No `onboarding_started`, `cv_uploaded`, `match_score_viewed`, subscription events. | iOS `Core/Analytics/AnalyticsService.swift:122-242` |

---

## 2. The new model

### 2.1 Units (unchanged meaning, so nothing already unlocked breaks)

- **Tailored export** = one optimization unlocked for PDF/DOCX forever. Same as today's credit. Re-downloads stay free.
- **Match Score** = the first score for a new (CV, job) pair. The before/after on the same optimization and every rescan of the same pair are free. This is new metering.

### 2.2 Products

| Product ID (proposed) | Type | Gives | Price |
|---|---|---|---|
| `resumely.exports.5.v2` | Consumable | 5 tailored exports + 5 Match Scores | $3.99 (₪12.90) |
| `resumely.exports.14` | Consumable | 14 tailored exports + 14 Match Scores | $7.99 (you pick the ₪ tier) |
| `resumely.pro.monthly` | Auto-renewable, group **Resumely Pro** | Unlimited exports and scores within fair use | $9.99 / month |

Why packs also add Match Scores: a buyer who runs out of scores but holds export credits would hit a second paywall. Same count, one mental model. (Decision D2.)

Retired forever (server grants 0, app never loads them): `resumely.exports.1`, `resumely.exports.5`, `resumely.exports.10`, plus the older `credits_basic`, `credits_saver`, `credits_super`. Unfinished old transactions bought before the switch are still delivered (see 4.4).

### 2.3 Welcome grant

- 5 tailored exports + 5 Match Scores, once per account, granted on the server.
- Idempotency: a `welcome_grants` table with `user_id` as primary key. The grant inserts the row and adds the credits in one transaction; a second call does nothing. Reinstall or a new device signs into the same account, so it can never re-grant.
- When: lazily, inside every credit read or spend (`get_credit_state`), so no signup hook is needed and old accounts get it the first time they open v2.
- Anonymous sessions: get the 5 Match Scores on their anonymous user id (so a first score needs no account). The 5 exports are added when the account becomes real (exports already require a real account). Converting keeps the same user id, so nothing doubles.
- Known gap: a person can create a second account (or reinstall as a new anonymous user) for another grant. Apple DeviceCheck can mark "this device already got a grant", but it needs a key in App Store Connect and server work. I recommend we ship without it and add it only if PostHog shows grant farming. (Decision D4.)
- The column default `credit_balance = 1` goes to `0`, so a new account gets exactly 5, not 6.

### 2.4 Subscription and fair use

- Entitlement lives on the server: new table `subscriptions` (`original_transaction_id` unique, `user_id`, `product_id`, `expires_at`, `status`, `auto_renew`, `environment`, `grace_until`).
- Active = `status in ('active','grace')` and `now() < coalesce(grace_until, expires_at)`.
- **Fair-use cap (proposal): 40 tailored exports and 100 Match Scores per 30-day period**, counted from the current period start. A heavy job seeker sends 20 to 30 tailored applications a month, so 40 is above real use. I do not know your OpenAI cost per optimization; my guess is $0.05 to $0.15, which keeps 40 exports under ~$6 of the ~$7 net. Check the OpenAI dashboard before approving. (Decision D3.)
- Over the cap: spend pack credits if the user has any; otherwise a calm message with the reset date. Never a second purchase prompt for a subscriber.
- Spend order: subscription first, then pack/welcome credits (so credits are kept for after a cancel).

### 2.5 Existing users (fair handling)

Recommended: **every existing account also gets the welcome grant once, on top of what it holds.** Unlocked exports stay unlocked. Anyone who bought an old pack keeps every credit. Today most accounts hold 0 or 1 credit and there are very few users (2026-07 data: ~50 launchers in a month), so the cost is tiny and nobody can feel penalized by the price drop. (Decision D1. Alternative: top up to 5 instead of adding 5.)

Old-pack buyers since 1.5.6: I could not check production rows this session (Supabase MCP needs auth). Before the migration runs, one read-only query lists `credit_transactions` where `source='apple_iap'`; if any exist, they keep everything and get the grant too.

---

## 3. Paywall placement and copy

### 3.1 Rule (enforced in two places)

1. Server decides **if** a spend is possible (402 when no credit, no subscription, or over cap).
2. App decides **whether to show the paywall**: only when `hasSeenMatchScore && hasSeenPDFPreview` for this account (stored per user id in `UserDefaults`, set by the same code paths that fire `match_score_viewed` and `pdf_preview_viewed`).
3. If the server says "no Match Scores left" but the user has never seen a PDF preview, show a non-paywall card instead: "You used your 5 free Match Scores. Build your tailored CV for one of those jobs, it's still free." It opens their best-scored job. (Decision D5.)

A sample-CV score does not count as `hasSeenMatchScore` for the paywall rule (it is not their CV).

### 3.2 Copy draft (EN / HE). Final review in S3 with the taste pass.

Rules applied: Match Score always "estimate"; no ATS-beating claim; no guarantee; no competitor names.

- Title: "Keep tailoring your CV" / "ממשיכים להתאים את קורות החיים"
- Body: "A free chatbot gives you text. Resumely gives you a ready PDF, right-to-left in Hebrew, in a clean template, with a before-and-after Match Score estimate. All on your phone, in under a minute." / "צ'אטבוט חינמי נותן לכם טקסט. Resumely נותן PDF מוכן, מימין לשמאל בעברית, בתבנית נקייה, עם הערכת ציון התאמה לפני ואחרי. הכול בטלפון, בפחות מדקה."
- Plan row: "Pro, unlimited tailoring (fair use)" / "Pro, התאמות ללא הגבלה (שימוש הוגן)"
- Pack rows: "5 tailored CVs" / "5 קורות חיים מותאמים"; "14 tailored CVs" / "14 קורות חיים מותאמים"
- Footer: "The Match Score is an estimate of how well your CV fits the job, not a hiring prediction." / "ציון ההתאמה הוא הערכה של התאמת קורות החיים למשרה, לא תחזית לקבלה לעבודה."
- Required by Apple for the subscription: price and period from StoreKit, "Renews monthly until cancelled", links to Terms of Use (EULA) and Privacy Policy, Restore Purchases.

"Under a minute" must be true: S6 times it on a real phone from Create to PDF preview. If it is not, the line changes.

Prices are always `product.displayPrice` from StoreKit. No typed price anywhere.

---

## 4. Server changes (web repo, story S1)

All behind a new switch `PRICING_V2_ENABLED` (default off) plus the existing test-account list, so merging changes nothing for users.

| File | Change |
|---|---|
| `supabase/migrations/<new>_pricing_v2.sql` | New: `welcome_grants`, `score_unlocks (user_id, resume_hash, jd_hash)`, `subscriptions`, `profiles.score_balance int default 0`, `credit_balance` default 0, functions `ensure_welcome_grant`, `unlock_score`, `grant_apple_purchase_v2` (adds exports + scores), `upsert_subscription`, `get_credit_state`; `unlock_export` gains the subscription/fair-use branch. All SECURITY DEFINER, service_role only (same revoke pattern as today). **Applying it needs your explicit yes.** |
| `src/lib/iap.ts` | Product catalog v2: per ID `{ kind, exports, scores }`; retired IDs map to nothing; `isSubscriptionProduct()`. |
| `src/app/api/v1/iap/verify/route.ts` | Accept `Auto-Renewable Subscription` for `resumely.pro.monthly`: check `appAccountToken`, upsert by `originalTransactionId`, return `{ status, entitlement: { active, expiresAt } , balance, scoreBalance }`. Consumables grant exports + scores. Old-ID unfinished transactions: still granted at their old credit amount (they were paid), then never sold again. |
| `src/app/api/v1/iap/notifications/route.ts` | Handle `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `DID_FAIL_TO_RENEW` (grace), `EXPIRED`, `GRACE_PERIOD_EXPIRED`, `REFUND`/`REVOKE` for subscriptions. Emits server events (section 6). |
| `src/lib/export-credits.ts` | Charge check uses the v2 switch; result carries `source: 'subscription'`. |
| `src/lib/score-credits.ts` | New: `authorizeScore()` mirrors `authorizeExport()`; 402 `score_credits_required`. |
| `src/app/api/public/ats-check/route.ts`, `src/app/api/ats/score/route.ts`, `src/app/api/ats/rescan/route.ts`, `src/app/api/optimize/route.ts` | Call `authorizeScore()` for iOS requests on a new pair only. Rescans and the after-score are free. Exact first-score route confirmed during the build. |
| `src/app/api/v1/credits/route.ts` | Returns `{ balance, scoreBalance, subscription: { active, expiresAt, periodUsage } }`. |
| `src/app/api/upload-resume/route.ts` | Accepts `resumeText` (300 to 20,000 chars) instead of a file, for paste (S4). |
| Tests | Extend `tests/lib/iap.test.ts`, `tests/api/iap-verify-route.test.ts`, `tests/api/export-unlock-route.test.ts`; new `tests/lib/score-credits.test.ts`, `tests/api/iap-notifications-subscription.test.ts`, `tests/lib/welcome-grant.test.ts`. |

Env vars to add in Vercel (I do not set them): `PRICING_V2_ENABLED`, and reuse `APPLE_IAP_*`.

### 4.4 Switch-over

1. Ship server with switch off. 2. Founder creates products in ASC. 3. Sandbox on test accounts. 4. Ship iOS 1.6.0. 5. Turn `PRICING_V2_ENABLED` on when 1.6.0 is live. Old app versions (1.5.6) still load the old IDs; once old IDs are "Removed from Sale" in ASC, their paywall shows "not available" and exports for them stay at 402. Decision D6: keep old products on sale until 1.6.0 adoption is ~90%, or remove on day one. I recommend removing on day one: the old prices are 3x higher.

---

## 5. iOS changes (stories S2 to S5)

| File | Change | Story |
|---|---|---|
| `Core/Payments/StoreKitManager.swift` | `ExportCreditProducts` becomes `ResumelyProducts` (packs + subscription, retired list). Load mixed types. `purchase()` handles subscriptions. New `refreshEntitlements()` sends `Transaction.currentEntitlements` to the server at launch and after sign-in. `restorePurchases()` = `AppStore.sync()` then entitlements + unfinished. `deliverInBackground` accepts subscription renewals. | S2 |
| `Core/Payments/ReceiptVerifier.swift` | Decode `entitlement` and `scoreBalance`. New error `ownedByAnotherAccount` with copy "This subscription belongs to another Resumely account. Sign in with that account." | S2 |
| `Core/Payments/ExportCredits.swift` | Unlock response may say `source: subscription`; new `ScoreCreditsError.scoreCreditsRequired`. | S2 |
| `App/AppState.swift` | `scoreBalance`, `subscription` state, `paywallEligibility(for:)`. | S2/S3 |
| `Features/V2/Paywall/ExportPaywallSheet.swift` | Redesign: plan card first, two packs, copy from 3.2, legal links, Restore. Opens for export 402 and score 402. | S3 |
| `Features/V2/Paywall/PaywallSmokeHarness.swift` | Fixture offers for the 3 new products; `--smoke-paywall-sub` variant showing an active plan; Hebrew via `--smoke-he`. | S3 |
| `Features/Profile/PaywallView.swift` | Delete (dead scaffold). Profile gains "Plan" row: Pro until date / credits left / Restore / Manage subscription (`showManageSubscriptions`). | S3 |
| `ResumeBuilder IOS APP/Resumely.storekit` (new) | Local StoreKit config: 2 consumables, 1 subscription group with the monthly plan, sandbox prices, accelerated renewal for testing. Wired into the Debug scheme only. | S2 |
| `Features/V2/Home/HomeTabView.swift`, `UploadSheetView.swift` | Three starts: Upload file, Paste text (LinkedIn "About + Experience" or CV text), Try a sample CV. | S4 |
| `Features/V2/Home/SampleCV/` (new) | Bundled Hebrew + English sample CV and sample job with a **precomputed** Match Score (no server call, no AI cost, under a second), then "Now try with your CV". | S4 |
| `Core/Analytics/AnalyticsService.swift` | Event contract from section 6. | S5 |
| `Localizable` catalog | All new strings EN + HE, RTL checked in harness screenshots. | S3/S4 |
| Tests | `ExportCreditsTests.swift` (retired IDs extended to the 3 old pack IDs, new catalog, order), new `SubscriptionEntitlementTests.swift`, `PaywallEligibilityTests.swift`, `WelcomeGrantDisplayTests.swift`, StoreKitTest `SKTestSession` tests for buy / renew / expire / refund / restore against the `.storekit` file. | S2 to S5 |

### 5.1 The guest export gap (must verify in S3)

`authorizeExport` lets a guest **with no session** skip the unlock and export the on-screen copy for free (`ExportCredits.swift`, comment on spec section 3, E6). If a no-session guest can reach a PDF today, any price is bypassable. S3 starts by checking this on the simulator. If it is reachable, I propose the export button asks for a free account (Sign in with Apple, one tap) when there is no session, which also lands the welcome grant. (Decision D7.)

---

## 6. Analytics contract (PostHog 270848)

Scheme: `snake_case`, `object_action` in past tense, one event per funnel step, same `distinct_id` (Supabase user id after identify). Properties never carry CV text, email or names.

| Event | Fired by | Where | Properties |
|---|---|---|---|
| `onboarding_started` | app | first Home appear per install | `entry` |
| `cv_uploaded` | app | after a successful upload / paste / sample load | `method: file \| paste \| sample` |
| `match_score_viewed` | app | score card on screen | `source: sample \| own`, `score_bucket`, `is_estimate: true` |
| `pdf_preview_viewed` | app | Optimized preview rendered | `optimization_id`, `template` |
| `free_grant_used` | server | the spend that takes the welcome grant to 0 | `kind: export \| score` |
| `paywall_viewed` | app | sheet appears | `trigger: export \| score`, `balance`, `score_balance` |
| `purchase_started` | app | buy tapped | `product_id` |
| `purchase_completed` | app | after server grant | `product_id`, `price`, `currency` |
| `purchase_failed` | app | StoreKit or server failure | `product_id`, `reason` |
| `subscription_started` | server | first verify of a new original transaction | `product_id`, `environment` |
| `subscription_renewed` | server | `DID_RENEW` | `product_id`, `period` |
| `subscription_cancelled` | server | `DID_CHANGE_RENEWAL_STATUS` auto-renew off, and `EXPIRED` (`reason`) | `reason` |
| `export_completed` | app | file handed to the share sheet | `optimization_id`, `source: grant \| pack \| subscription \| ungated` |

Old names (`paywall_shown`, `export_success`, `resume_uploaded`, `free_ats_completed`) keep firing in 1.6.0 so current dashboards do not break, and are removed in 1.6.1. `purchase_cancelled` and `purchase_pending` stay (useful, not in your list). Funnel: `onboarding_started → cv_uploaded → match_score_viewed → pdf_preview_viewed → free_grant_used → paywall_viewed → purchase_completed`.

Unverified: that the server `distinct_id` (user id) and the app's identified id are the same person in PostHog. S5 checks one test account end to end before relying on server events in the funnel.

---

## 7. Stories and PRs

One story at a time; I stop after each with evidence.

| Story | Repo | Done means |
|---|---|---|
| S1 Server pricing v2 | web | migration file written (not applied), routes + tests green, switch off |
| S2 StoreKit v2 + entitlements | iOS | new catalog, subscription buy/restore/renew/expire, `.storekit`, unit + SKTestSession tests green |
| S3 Paywall placement + copy | iOS | eligibility rule, redesigned sheet EN/HE, guest gap decided, Profile plan row |
| S4 Activation | iOS + web | paste and sample starts, sample score in < 1 s, RTL screenshots |
| S5 Analytics | iOS + web | contract above, one test account seen end to end in PostHog |
| S6 QA | both | test matrix below, timing check, App Store Connect checklist final |

PRs: two **draft** PRs, one per repo, one commit series per story, each with the GLOBAL-WORKFLOWS 7b pre-check. Not merged. No App Store Connect changes by me.

---

## 8. Test plan

Unit (automated):
- Welcome grant: first call grants 5+5; second call, reinstall (same user), new device (same user) grant nothing; anonymous gets scores only; conversion adds exports once.
- Credit math: pack v2 adds 5+5, pack 14 adds 14+14; quantity > 1; replay grants once; refund deducts outstanding only; export unlock idempotent; score unlock free on rescan/after-score.
- Entitlements: active, grace, expired, refunded, renewed (new expiry), cancelled-but-not-expired stays active, over fair-use cap falls back to credits then refuses with reset date, subscription spent before credits.
- Retired IDs: all 6 never loaded by the app, never granted by the server for new sales, old unfinished transactions still delivered.
- Paywall eligibility: never before score + preview; sample score does not count; no-scores-before-preview shows the free-CV card.

Sandbox matrix (S6, on your phone signed into a Sandbox tester; I cannot type Apple passwords):

| # | Flow | Expect |
|---|---|---|
| 1 | New account | 5 exports + 5 scores shown |
| 2 | Use all 5 exports | paywall only after score + preview |
| 3 | Buy 5 pack | +5/+5, export resumes without a second tap |
| 4 | Buy 14 pack | +14/+14 |
| 5 | Subscribe | unlimited, Profile shows renew date |
| 6 | Renewal (Sandbox month = 5 min) | `subscription_renewed`, still active |
| 7 | Cancel in Settings, let expire | `subscription_cancelled`, falls back to credits, then paywall |
| 8 | Restore on reinstall | subscription back; credits back on sign-in |
| 9 | Restore on another account | "belongs to another account" message, no grant |
| 10 | Ask to Buy / pending | sheet waits, resumes on approval |
| 11 | Refund (Sandbox refund request) | credits deducted / entitlement off |
| 12 | Kill app mid-purchase | delivered at next launch, no double charge |
| 13 | Old 1.5.6 build | old IDs not sold after removal; no crash |

Local (simulator, `.storekit`): rows 1 to 8 with StoreKit Testing, but the server cannot verify Xcode-signed transactions, so local runs test the app half only. Real grants need real Sandbox.

Regression: full `xcodebuild test`, web `npm run lint`, `npx tsc --noEmit`, `npm run build`, jest.

---

## 9. Risks

1. **Server cannot verify local `.storekit` transactions.** End-to-end needs the ASC products first. Blocks S6 until you create them.
2. **Guest no-session export bypass** (5.1). Could make every price moot.
3. **Fair-use number is a guess** without OpenAI cost per optimization.
4. **Score metering changes a free feature.** The 5 free scores plus free rescans keep activation open; watch `match_score_viewed → pdf_preview_viewed` after launch.
5. **Grant farming** via new accounts (2.3). Mitigation ready (DeviceCheck) but not built.
6. **Israel VAT.** ₪ prices include 18% VAT; after VAT and 15% Apple commission, $9.99 nets about $7. $1,000/month net is about 140 subscribers, or a mix with packs (~$2.80 net per 5-pack in Israel). Guess, from public rates, not from your ASC payout report.
7. **Missing SSR PDF templates.** I did not find the note in this repo's tasks files. If an export picks one of the 3 missing templates, the paywall would charge for an export that falls back or fails. S3 checks which templates the sheet's "export" can select and flags it; not fixed here.
8. **App Review**: subscription paywall must show price, period, auto-renew text, EULA and privacy links, and Restore. Covered in 3.2.

---

## 10. App Store Connect checklist (you do this; I touch nothing)

1. **Small Business Program**: enroll at developer.apple.com/app-store/small-business-program (15% instead of 30%). Takes effect the month after approval.
2. **Paid Apps agreement, tax and banking** active (already true if 1.5.6 sells; confirm).
3. **Consumable** `resumely.exports.5.v2`: reference name "5 tailored CVs v2", price $3.99 (₪12.90 tier), display name EN "5 tailored CVs" / HE "5 קורות חיים מותאמים", description EN "Five tailored CV exports and five Match Score estimates." / HE "חמש הורדות של קורות חיים מותאמים וחמש הערכות ציון התאמה.", review screenshot of the paywall, review note below.
4. **Consumable** `resumely.exports.14`: same shape, $7.99, "14 tailored CVs" / "14 קורות חיים מותאמים". Pick the ₪24.90 or ₪26.90 tier.
5. **Subscription group** "Resumely Pro" (new). Group display name EN "Resumely Pro" / HE "Resumely Pro".
6. **Auto-renewable** `resumely.pro.monthly` in that group: 1 month, $9.99, level 1, display name EN "Pro monthly" / HE "Pro חודשי", description EN "Unlimited tailored CVs and Match Score estimates, fair use." / HE "קורות חיים מותאמים והערכות ציון התאמה ללא הגבלה, בשימוש הוגן.". Billing grace period: on, 16 days (matches server `grace_until`). No free trial in v1 (the welcome grant is the trial).
7. **Remove from Sale** `resumely.exports.1`, `.5`, `.10` (per D6). Do not delete them.
8. **App Store Server Notifications V2**: Production and Sandbox URL = `https://<prod host>/api/v1/iap/notifications` (check it is already set; subscriptions need it for renewals and cancels).
9. **App Privacy / metadata**: mention the subscription in the description; add Terms of Use (Apple standard EULA link is fine) in the description or EULA field.
10. **Sandbox tester** account for the S6 matrix; set its renewal rate to accelerated.
11. **Attach** all three products to the 1.6.0 version before submitting.
12. Review note (paste): "Resumely sells export credits and an optional monthly plan. Every new account gets 5 free tailored CV exports and 5 free Match Score estimates. To reach the purchase screen with the demo account below, open a saved result and tap Export; the demo account has no free credits left. The Match Score is shown as an estimate. Restore Purchases is on the purchase screen and in Profile."

---

## 11. Decisions I need from you

| # | Question | My recommendation |
|---|---|---|
| D1 | Existing users | Add the welcome grant on top of current balance |
| D2 | Packs also add Match Scores | Yes, same count |
| D3 | Fair-use cap | 40 exports + 100 scores per 30 days (check OpenAI cost) |
| D4 | DeviceCheck against grant farming | Not now; add if data shows abuse |
| D5 | Scores run out before any PDF preview | Free "build your CV" card, not the paywall |
| D6 | Old products | Remove from sale on 1.6.0 launch day |
| D7 | No-session guest export | If reachable, ask for a free account at export |

## 12. Could not verify this session

- Production credit rows and whether anyone bought an old pack (Supabase MCP needs `/mcp` auth).
- PostHog identity join between app and server events (PostHog checked only through code).
- Whether the ASC notifications URL is already set.
- The "3 missing SSR templates" note: not found in this repo's task files.
- Real OpenAI cost per optimization.
