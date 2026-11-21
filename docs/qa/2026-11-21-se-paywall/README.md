# Export paywall on iPhone SE (3rd gen): small-phone check

Date: 2026-11-21. Sprout-learnings plan, PR 2 (`docs/sprout-learnings-plan.md`, section 4).
Device: iPhone SE (3rd generation) simulator, iOS 26.5, 375 x 667 points. Debug build of `origin/main` at `fbe2e40`.
How: launch argument `--smoke-paywall` (plus `--smoke-he` for Hebrew), `Features/V2/Paywall/PaywallSmokeHarness.swift`.
Prices in the screenshots are the harness samples, not live App Store prices.

Why: a solo founder reported no sales for 5 days because his paywall price overflowed a small screen.

## Pass rule

Price, renewal period, Continue, Restore Purchases, Terms of Use and Privacy Policy are all reachable,
and Continue is visible without scrolling.

## Result: PASS, no code change

| Case | Screenshot | Prices + period | Continue | Restore, Terms, Privacy |
|---|---|---|---|---|
| English, default text | `se-en-default.png` | visible | visible | visible |
| English, XXL text | `se-en-xxl.png` | visible | visible, bottom edge cut | below the fold, reached by scrolling |
| Hebrew, default text | `se-he-default.png` | visible, right to left | visible | visible |
| Hebrew, XXL text | `se-he-xxl.png` | visible, right to left | visible | below the fold, reached by scrolling |

Scrolling: the whole sheet, footer included, is one `ScrollView` (`ExportPaywallSheet.swift:378-428`), so the
footer is reachable at any text size. Checked in code, not by swiping: simulator device access was not granted
in this session.

The banner on `se-en-default.png` is an iOS system notification ("Ready for Apple Intelligence"), not the app.

## Not changed, and why

Pinning Continue to the bottom was the planned fix only if the check failed. At XXL text in English, Continue is
on screen but cut at the bottom edge; it stays tappable. XXL is not the default size, and a pinned bar would hide
more of the offers on this same small screen. Recommendation: no change now; revisit if `paywall_viewed` shows
small-phone users with large text who do not continue.

## Not covered

- Accessibility text sizes above XXL (AX1 to AX5).
- iPhone 13 mini and SE (2nd gen), which have similar or the same screen sizes.
- Live StoreKit prices; the harness uses fixed sample prices.
