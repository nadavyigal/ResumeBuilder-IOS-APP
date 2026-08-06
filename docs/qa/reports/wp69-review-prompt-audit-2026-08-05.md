# WP-69 Story 2 — Review prompt: code audit, 2026-08-05

**Status: the code path is intact, and it still has two defects that each produce exactly the
symptom we have.** Visual confirmation needs hardware and is recorded separately in
`docs/qa/wp69-1.4.7-device-walk.md`. This document is the part that could be established
without a device.

The packet cites `Features/V2/Improve/OptimizedResumeView.swift:1198`. The call now sits at
**line 1070**; the line number moved, the code did not.

## The path, end to end

```
Export tapped
  → ResumeExportAction.exportPDF                       (Core/Export/ResumeExportAction.swift:10)
      → appState.markExportComplete(for:)              (:38)   — sets isExportComplete
      → analytics.track(.exportSuccess)                (:39)
  → pendingReviewOptimizationId = result.optimizationId (OptimizedResumeView.swift:1043)
  → showPDFShare = true                                (:1044)
  → user dismisses the share sheet
  → .sheet(onDismiss: handlePDFShareDismissed)         (:275)
      → guard pendingReviewOptimizationId != nil       (:1060)
      → guard appState.isExportComplete(for:)          (:1061)
      → ReviewPromptGate.claimAfterSuccessfulExport    (Core/Review/ReviewPromptGate.swift:57)
      → analytics.track(.appStoreReviewRequested(source: "export_success"))
      → requestReview()                                (:1070)
```

Every guard on that path was checked and none of them is obviously false for a real App Store
user:

- `isExportComplete` is set by `markExportComplete` **before** `exportPDF` returns, so it is
  true by the time the sheet is dismissed.
- `isInternalTester` is `true` for DEBUG, for the `--internal-tester` argument, for the
  `RESUMELY_INTERNAL_TESTER` environment variable, for TestFlight (`sandboxReceipt`), and for
  configured user ids. An App Store build for an ordinary user is **none** of those, so the
  gate does not exclude them. This is correct behaviour and worth stating, because it was the
  first hypothesis and it is wrong.
- `appVersion` comes from `CFBundleShortVersionString` and is only `"unknown"` if the key is
  missing; it is present.
- The keychain claim uses `KeychainStore.save`, which handles `errSecDuplicateItem` by updating
  and is the same store that persists auth sessions successfully in production.

## Defect 1 — the per-version claim is spent before the prompt is known to have appeared

`claimAfterSuccessfulExport` writes the current version into the keychain and returns `true`;
`requestReview()` is then called and **returns nothing**. StoreKit provides no signal about
whether a prompt was displayed. The claim is therefore permanent regardless of outcome.

iOS declines to display the prompt for reasons entirely outside this code: its own annual cap,
a prior prompt for the same version, the app not being frontmost, or a presentation already in
flight. Any one of those on a user's single export burns their version claim, and that user is
never asked again on that version.

**One suppressed presentation per user is enough to produce zero ratings.**

## Defect 2 — the prompt fires during the share sheet's dismissal transition

`requestReview()` is invoked from `.sheet(onDismiss:)`, which runs as the
`UIActivityViewController` is tearing down. A presentation in flight is one of the documented
conditions under which StoreKit silently declines to present. This is the single worst moment
in the flow to ask, and it is the moment the code picks.

Together the two are multiplicative: the prompt is attempted exactly when iOS is most likely to
refuse, and the refusal costs the user their only attempt.

## The competing explanation, and the one query that separates them

There is a second, entirely sufficient explanation for twelve days at zero ratings: **almost
nobody finishes an export**, so `requestReview()` is rarely reached at all. That is consistent
with the standing finding that real exports are close to zero.

These two explanations are distinguishable with one number, and the app already emits it:

```
app_store_review_requested   (source = "export_success")
```

- **count = 0** on 1.4.7 → the prompt was never attempted; this is a funnel problem, and
  neither defect above has cost a single rating yet.
- **count > 0** with zero ratings → the prompt fired and was not converted, and the defects
  above are the leading cause.

That query is WP-69 story 3 and is blocked on a PostHog personal API key. **Run it before
fixing anything here** — the fix is cheap either way, but the priority it deserves depends
entirely on which side of that number we are on.

## Recommended fix, if the number is greater than zero

Not applied in this packet: WP-69 verifies and cleans, and ships no product change.

1. Present after the dismissal settles, not during it — a short delay after `onDismiss`, with a
   check that the scene phase is `.active`.
2. Do not spend the claim on an attempt that cannot succeed. Claim only when the app is in a
   state where iOS can present, and treat the analytics event as "attempted", not "shown".
