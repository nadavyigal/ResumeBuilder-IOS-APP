# WP-69 Story 1 + 2 — 1.4.7 App Store device walk

**Run 2026-08-09 by the founder on physical hardware, App Store build.** This is the
first completed physical-device walk on 1.4.7; the gate had been outstanding across
five releases.

## Record

| Field | Value |
|---|---|
| Date (UTC) | 2026-08-09 |
| Device | not recorded |
| iOS version | not recorded |
| App version / build | 1.4.7 (17), App Store |
| Install source | App Store (required, confirmed) |
| Account | founder |

## Walk

- [x] **1. Launch.** No crash, no blank state.
- [x] **2. Upload a résumé.** Accepted.
- [x] **3. Add a job.** Accepted.
- [x] **4. Analyze.** Completed.
- [x] **5. Fit check.** Score not recorded.
- [x] **6. Accept / Apply.** Score not recorded.
- [x] **7. Expert pass.** Run, including the cover-letter mode. Score not recorded.
- [x] **8. Export. → App Store rating prompt appeared: YES.**
- [x] **9. Relaunch.** Optimization still present.

## Verdict

**WP-69 story 2 is ANSWERED, and the answer overturns the working hypothesis.**

The review prompt **fires correctly on the App Store build**. The two defects found by
inspection on 2026-08-05 — the keychain claim written before the prompt is confirmed
shown, and the call site inside `.sheet(onDismiss:)` during share-sheet teardown — are
real code smells but **did not prevent the prompt from appearing**. They are not the
explanation for zero ratings and should not be prioritised as if they were.

**The competing explanation is confirmed instead, and the evidence is unambiguous.**
Live PostHog reads on project 270848, 2026-08-09:

| Query | Result |
|---|---|
| `app_store_review_requested`, all time, all versions | **1 event, 1 person** — this walk, 2026-08-09T10:26:50Z, on 1.4.7 |
| `export_success` on 1.4.7 by non-internal persons | **0 events, 0 people** |

In the twelve days 1.4.7 has been live, **no one outside the team has completed a single
export**, so the prompt had never once been reachable. Zero ratings was never a prompt
problem. It is a traffic and funnel problem, and no amount of review-prompt work can
move it.

**Consequence for sequencing:** the review-prompt repair drops in priority. The binding
constraint is arrivals and export completion, which is the question EXD-022 and WP-62
already point at.

## Scores

| Stage | Score |
|---|---|
| After analyze | not recorded |
| After apply | not recorded |
| After expert pass | not recorded |

**Verdict on monotonicity: UNANSWERED.** The founder reported no regression, but the
three scores were not written down, so the "score only climbs" assertion — the thing
step 6 exists to prove — cannot be evidenced from this run. It needs one more pass, or
it stays open. Do not record it as passed.

## Defect found during the walk (not in the script)

**Export delivers the résumé PDF only. The cover letter and screening answers are not
included, even after the expert cover-letter mode has been run.**

Confirmed in code, and it is a product-design gap rather than a bug:

- `ResumeExportAction.exportPDF` (`Core/Export/ResumeExportAction.swift:10-47`) builds
  exactly one file and returns a single `fileURL`. The share sheet receives
  `items: [url]` — a one-element array (`OptimizedResumeView.swift:279`). Nothing in
  this path is aware that a cover letter exists.
- The capability **does** exist, on a different button. `SubmitApplicationViewModel`
  (`Features/V2/Improve/SubmitApplicationViewModel.swift:26-32`) assembles a package of
  `resumePDFURL` + `coverLetterText` + `screeningAnswers`, reached by the **Submit
  Package** button that sits next to Export in the same bottom bar
  (`OptimizedResumeView.swift:623-628`).
- Worse, `SubmitApplicationViewModel.load()` **re-runs** the cover letter and screening
  through `expertService.run(type: .coverLetterArchitect, …)` rather than reusing the
  expert output the user already generated, so the work is done twice and the two
  surfaces can disagree.

So three surfaces produce overlapping artifacts, and **the one a user naturally taps
produces the least**. The founder ran the expert cover-letter mode, exported, and
reasonably expected the cover letter to be in what came out.

**Founder's stated expectation:** exporting should deliver the résumé, the cover letter,
and the screening answers together.

## Follow-ups filed

1. **Export should deliver the full application package** when the artifacts exist, or
   say plainly why it will not. Options: merge Export and Submit Package into one action;
   or have Export attach whatever expert artifacts are already generated; or, minimally,
   have the export-success state offer the cover letter rather than leaving the user to
   discover a second button. Needs a product call before implementation.
2. **Expert output must be reused, not regenerated.** `SubmitApplicationViewModel` should
   consume the existing expert run when one exists for the optimization.
3. **Re-run steps 5-7 recording the three scores**, so the monotonicity assertion is
   evidenced rather than assumed.
4. **Deprioritise the review-prompt repair.** Keep the two defects on record as latent
   correctness issues; they are not what is costing ratings.
