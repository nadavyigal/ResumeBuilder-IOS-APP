# Payments Phase 2 closure — October 24, 2026

## Current result

Implementation and production backend prerequisites are ready for the real Sandbox test. Phase 2 is **not complete** until an Apple-signed Sandbox purchase grants credits and resumes the intended export on the physical phone. No public billing activation or App Review submission was performed.

## Verified backend

- Web PRs #195, #196, #197 and #198 are merged.
- Production Supabase project `brtdyamysfmctrhuankn` lists `20261021120000_export_credits`, `20261022120000_harden_security_definer_grants`, and `20261023120000_apple_iap_verification` after the baseline/purge migrations.
- `unlock_export` and `grant_apple_purchase` EXECUTE ACLs contain only postgres and service_role.
- Read-only aggregate of `credit_transactions where source = 'apple_iap'` returns no rows. No real purchase has been verified.
- The production unlock route exists (GET is 405, as expected for a POST route); authenticated configuration still needs verification.
- Vercel connector returns 403 for team access; authenticated browser fallback used. Three Apple verification config values and the founder-selected test-account allowlist were saved for Production only. EXPORT_CREDITS_ENABLED remains unset. Redeployed existing main cd4ab91; deployment 77PjJSPyGV1nAaoMYhRrYrfKmETa is Ready and assigned to www.resumelybuilderai.com. After deployment, unauthenticated /iap/verify returns 401 (configuration available), and a forged notification returns 400 (no database mutation).

## iOS corrections on top of #207

Base: `7a9367a4c0d5e08e6df8fa4d6dc1534d4db3e68b`. Worktree: `/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-payments-phase2-2026-10-24`, branch `codex/payments-phase2-2026-10-24`.

The original checkout has uncommitted multi-account lock work, preserved untouched. This isolated follow-up handles the same finding with compatibility for the old persisted format added.

1. Save pending locks per account so B's pending purchase cannot erase A's lock across relaunch.
2. Recheck the active account after background verification before publishing its balance/export signal.
3. Listen to Transaction.updates independently of unfinished replay, following [Apple's guidance](https://developer.apple.com/documentation/storekit/transaction/updates) to start listening immediately at launch. Actual StoreKit stream timing remains a device/Sandbox check.
4. Use readable localized EN/HE copy for unexpected export errors; log the internal server code.
5. Terminal refund clearing was already fixed in #207's recordDelivery; retained and regression-tested.

## Validation

- Red: new multi-account and internal-error tests fail against #207's original source (three assertions).
- Green: 20 focused XCTest cases, zero failures.
- Full: 579 XCTest cases, one skipped, zero failures; five additional Swift Testing cases pass.
- Unsigned arm64 device Release build: pass.
- Signed arm64 device Release build: pass, candidate overrides 1.5.6 (35); generated API_BASE_URL is `https://www.resumelybuilderai.com`.
- EN/HE simulator smoke: full sheet, all three rows and close control visible, RTL correct. Prices in this DEBUG harness are fixtures, not evidence of StoreKit product loading.
- Initial iPhone 13 installation attempts failed while the cached pairing had no connected tunnel. Once wired, installation succeeded using its hardware UDID; app launch succeeded. Candidate 1.5.6 (35) is installed. Physical flow and purchase remain pending.

## App Store Connect configuration

Created the three approved Consumable products. Metadata and price setup are draft, not submitted for review.

| Product | Apple ID | US base | Israel comparable tier |
|---|---|---|---|
| resumely.exports.1 | 6826492925 | $3.99 | ₪12.90 |
| resumely.exports.5 | 6826493719 | $12.99 | ₪39.90 |
| resumely.exports.10 | 6826493979 | $19.99 | ₪59.90 |

Availability: all countries/regions selected. EN/HE names/descriptions added. Apple limits descriptions to 55 characters, so the approved copy was shortened without changing what the pack grants. Review screenshots must come from the real candidate after StoreKit loads products; fixture screenshots were not uploaded as real purchase evidence.

Production and Sandbox notification URLs are both saved as `https://www.resumelybuilderai.com/api/v1/iap/notifications`.

[Purchase catalog](https://appstoreconnect.apple.com/apps/6776752349/distribution/iaps).

## Remaining sequence

1. Finish current-head review and accept #207 plus this follow-up.
2. Backend configuration and founder test-account allowlist are deployed. Keep EXPORT_CREDITS_ENABLED off; review-demo allowlist is still a later submission step.
3. Signed candidate is installed and launched on the founder-selected iPhone 13. The selected real test account already has zero credits, so no balance update is necessary.
4. Confirm all three StoreKit products load with actual localized prices.
5. Cancel/dismiss once; buy the five-export pack in Apple Sandbox; verify automatic export, same-optimization free re-download, a new export spending one credit, and HE layout.
6. Read only: confirm exactly one apple_iap grant, Sandbox environment, product resumely.exports.5, delta five, correct balance/unlock rows and analytics. Save transaction identifiers privately, not in this public report.
7. Capture real review screenshots, attach the products to the decided release and follow the existing submission/activation gates. No real-money sale before October 31.
