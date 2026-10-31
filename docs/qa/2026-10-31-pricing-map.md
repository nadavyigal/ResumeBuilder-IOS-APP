# Resumely pricing map, 2026-10-31

Verdict: the approved prices match in the plan, the server, the app and the live StoreKit answer for the US storefront. The problems are not in the price numbers. They are one wrong assumption about the demo account, and old web text.

How each fact was checked:
- **Server:** web `origin/main` at `1a91c78`.
- **Live StoreKit:** a temporary test on simulator iPhone 17 Pro, storefront USA, 31 Oct. It only read products. It proves the products exist in App Store Connect and load. It does not prove Israel prices, review status, or a purchase.
- **Production:** read-only SELECT queries on 31 Oct, totals only. No emails, no writes.
- **Web pages:** opened in a browser on 31 Oct.

## 1. What is sold

| Item | Approved (plan 2.2) | Server (`src/lib/iap.ts`) | App (`StoreKitManager.swift:8`) | `Resumely.storekit` | Live StoreKit, US |
|---|---|---|---|---|---|
| `resumely.exports.14` | 14 exports, $7.99, ₪24.90 or ₪26.90 | grants 14 | sold first, preselected | $7.99 | $7.99, "14 tailored CVs" |
| `resumely.exports.5.v2` | 5 exports, $3.99, ₪12.90 | grants 5 | sold second | $3.99 | $3.99, "5 tailored CVs" |
| `resumely.pro.monthly` | $9.99 a month, fair use | subscription | sold third | $9.99, 1 month | $9.99, "Pro monthly", auto-renewable |

The app shows `product.displayPrice` only. No price is typed in the app.

Not checked: the ₪ prices, the Hebrew display names, the 16-day grace period and the review status. The phone test covers the ₪ prices and Hebrew.

## 2. Free allowance and limits

| Rule | Approved | Live in production (31 Oct) |
|---|---|---|
| Welcome grant | 3 | `welcome_export_grant()` returns 3 |
| Fair use on Pro | 40 per billing period | `subscription_export_cap()` returns 40 |
| New account default | 0, then the grant | `credit_balance` default is 0 |
| Match Score | free and unlimited | not metered, rate limits only |
| One export | one optimization unlocked forever, every format | unchanged |

Latest migration in production: `20261030094500`.

**Not exercised yet.** `welcome_grants` has 0 rows and `subscriptions` has 0 rows. No real account has signed in or been created since 30 Oct, so this is no traffic, not a fault. The first real grant in production will be the phone test.

## 3. Existing credits (production, 31 Oct)

| Accounts | Balance | Count |
|---|---|---|
| Real | 3 | 38 |
| Real | 9 | 1 |
| Anonymous | 3 | 107 |
| Anonymous | 1 | 48 |
| Anonymous | 0 | 3 |

Total 198 profiles, 495 credits. Real money: **none**. `credit_transactions` has 0 Production rows from Apple. The only 2 Apple rows are Sandbox, on one account.

**The plan's assumption was wrong.** Plan 2.5 says most accounts hold 0 or 1. In fact 38 of 39 real accounts hold 3, from the old column default. D1 adds 3 on top, so those accounts reach 6, not 3. Anonymous accounts get nothing until they become real.

Decision: keep D1 as approved. It affects 39 accounts and at most 117 extra exports. Nobody paid, and nobody loses anything.

**The launch page is wrong on timing.** It says the grant lands the first time an account exports. In the code it lands on the first read of `GET /api/v1/credits` (`get_credit_state`), so at sign-in or Profile, in any app version.

## 4. The review demo account (changes the brief)

The brief says it needs 3 exports. That is likely wrong: **it most likely holds 9, and will hold 12 after its first read.**

Evidence: the only account with a ledger holds 9, and the ledger matches the 1.5.6 release report:
- Started at 3, 3 used on 10 May, so 0.
- +5 Sandbox and 2 exports on 24 Oct, so 3. The report's "three credits" matches.
- Reset to 0 before review (release report). A reset leaves no ledger row, which fits.
- +10 Sandbox and 1 export on 26 Oct, so 9. That date matches the 1.5.6 review.

This is my inference. I did not read the email on that account, and no real account holds 0, so the "demo account at 0" state no longer exists.

Order matters: a reset before the grant fires leaves 3 free downloads. See the go or no-go file.

## 5. Old paid packs

| Product | Grants | Live StoreKit, US | Status |
|---|---|---|---|
| `resumely.exports.1` | 1 | $3.99 | on sale for 1.5.6, retire after 1.6.0 approval |
| `resumely.exports.5` | 5 | $12.99 | same |
| `resumely.exports.10` | 10 | $19.99 | same |

- The new app never loads these IDs (`ResumelyProducts.orderedIDs`).
- A paid, unfinished one is still delivered (`retiredPackIDs`, and `EXPORT_PACKS` on the server).
- Live 1.5.6 still sells them. On 25 Oct a device showed ₪12.90, ₪39.90, ₪59.90.
- Until they are removed, a 1.5.6 user pays $3.99 for 1 export and a 1.6.0 user pays $3.99 for 5. Accepted in D4. It is one more reason to remove them on approval day.
- The older `credits_*` IDs grant 0.

## 6. Channel differences that are intentional

| Difference | Why it stays |
|---|---|
| Web exports are free, iOS exports are charged | `isExportCharged` needs the `X-Resumely-Client: ios` header (spec F1) |
| Web sells no packs and no Pro | `MONETIZATION_GATE_OPEN = false`. Paddle parked 2026-10-23 |
| Charging is off for most accounts until step 8 | `EXPORT_CREDITS_ENABLED`, so 1.5.6 users are not stuck. Vercel setting not seen by me |
| Pro row says "unlimited PDF downloads (fair use)" while the server caps at 40 | Founder decision 2026-10-29. The count shows in Profile |
| Paywall Terms link goes to Apple's standard EULA | Founder decision 2026-10-30 |

## 7. Stale copy to fix

Fix before submission:

| Where | Says | Should say |
|---|---|---|
| Launch page review note | "The demo account has no free downloads left" | True only after the demo account is prepared |
| Live App Store description (1.5.6, 1,403 characters) | No mention of the plan, Terms or free checks | Needs a Terms of Use link for the subscription, and the A3 first line |

Fix soon after launch (does not block 1.6.0, the paywall no longer links these pages):

| Where | Says | Problem |
|---|---|---|
| resumelybuilderai.com/terms, updated 23 Dec 2025, `src/messages/en.json:628` | Premium $9/month, Stripe, 7-day refund, cancel in account settings, free tier of 1 optimization | Nothing here matches what is sold. Onboarding still links it |
| /pricing, `src/messages-overrides/funnel/en.json` | "Premium" $9.99, unlimited optimizations, Expert Modes. Button off, "not open yet" | Not sold. Other name and other promise than iOS Pro |
| Privacy, `src/messages/en.json:414` and `:491` | Payments go through Stripe | No line on Apple handling App Store purchases |
| Web paywall, `src/messages/en.json:1811` | "Secure payment via Stripe" | Behind the closed gate, so hidden |
| `meta.pricing.description` | "ATS resume optimization" | Old positioning |
| App errors: `StoreKitManager.swift:153,155,159,161`, `ExportCredits.swift:21`, `ExportPaywallSheet.swift:263` | "export credits", "credits" | The paywall and Profile say "PDF downloads" and "tailored CVs". Rare error paths, needs EN and HE |

Not stale: the Pro price. Web says $9.99, the app sells $9.99. Only the Terms page says $9.

## 8. App Store Connect checklist

| # | Item | State on 31 Oct |
|---|---|---|
| 1 | Small Business Program | Not seen |
| 2 | Paid Apps agreement, tax, banking | Not seen |
| 3 | `resumely.exports.5.v2` | Loads at $3.99, name matches |
| 4 | `resumely.exports.14` | Loads at $7.99, name matches. ₪ tier not seen |
| 5 | Subscription group "Resumely Pro" | Implied by Pro loading. Name not seen |
| 6 | `resumely.pro.monthly` | Loads at $9.99 monthly. Grace period and trial not seen |
| 7 | Remove old packs | Not yet, correct. Do it on 1.6.0 approval |
| 8 | Notifications V2 URL | Route live (405 on GET, 31 Oct). The setting itself not seen |
| 9 | Terms named in the description | Not in the live description |
| 10 | Sandbox tester | Not seen |
| 11 | Attach 3 products to 1.6.0 | Not done, see go or no-go |
| 12 | Review note | Needs the demo decision |
| 13 | A3 first line | Not in the live description. Not in `docs/app-store/en-metadata.md` |

I did not sign in to App Store Connect. "Not seen" means unknown, not missing.
