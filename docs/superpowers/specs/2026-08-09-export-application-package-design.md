# Export delivers the application package — design

**Date:** 2026-08-09
**Origin:** WP-69 device walk, `docs/qa/reports/wp69-device-walk-2026-08-09.md` (PR #146)
**Status:** approved by the founder 2026-08-09, ready to plan

## Problem

The founder ran the expert cover-letter mode on the 1.4.7 App Store build, tapped
Export, and received the résumé PDF alone. Three surfaces produce overlapping
artifacts and the one a user naturally taps produces the least:

| Surface | Produces | Persists |
|---|---|---|
| Export (`OptimizedResumeView.swift:611`) | résumé PDF only, shared as `items: [url]` | export-complete flag |
| Submit Package (`OptimizedResumeView.swift:623`) | résumé + cover letter + screening answers | only when the user taps Save Package to Me |
| Expert tab (`ExpertTabView.swift:37`) | the expert runs themselves | in-memory, in its own view model instance |

Two structural facts constrain any fix:

1. Attaching more files is trivial. `ShareSheet` already takes `[Any]`
   (`ResumePreviewExportView.swift:242`).
2. **"Whatever artifacts already exist" does not currently exist anywhere Export can
   read.** There is no endpoint that lists expert runs for an optimization — only run
   POST, GET by run id, and apply (`Endpoints.swift:42-44`). The Expert tab's run lives
   in memory in a different `ExpertModesViewModel`. `AppState.submitPackageRecord(for:)`
   persists `coverLetterText` + `screeningAnswers` per optimization
   (`AppState.swift:262`) but is written only from the Save-to-Me path.

So the real work is making expert output durable per optimization. The export change
rides on top of it.

Separately, `SubmitApplicationViewModel.submit()` re-runs `.coverLetterArchitect` and
`.screeningAnswerStudio` (`SubmitApplicationViewModel.swift:118-129`) instead of reusing
output the user already generated: the work is paid for twice and the two surfaces can
disagree.

## Product decisions (founder, 2026-08-09)

1. **Export is the package.** One primary action delivers the résumé plus the cover
   letter and screening answers whenever those artifacts exist. Submit Package stops
   being a peer button and becomes the tracking step; it no longer generates anything
   the user did not ask for.
2. **Missing artifacts never delay the export.** If no cover letter has been generated,
   the share sheet still opens immediately with the résumé, and the export-success state
   says plainly what is missing with a one-tap route to the Expert cover-letter mode. No
   inline generation, no premium run the user did not request. Rationale: 1.4.7 has zero
   non-internal `export_success` events; a 40-second wall on the most fragile step in the
   funnel is the wrong trade.
3. **File formats match how each artifact is used.** The cover letter is attached to
   applications, so it is a PDF. Screening answers are pasted into ATS text boxes, so
   they are plain text.

```
Jane Doe - Resume - Acme.pdf
Jane Doe - Cover Letter - Acme.pdf
Screening Answers - Acme.txt
```

## Architecture: one durable artifact record per optimization

`AppState` already owns a per-optimization record — `SubmitPackageCacheRecord`
(`AppState.swift:29`). It is extended rather than duplicated:

```swift
struct SubmitPackageCacheRecord: Codable, Sendable, Equatable {
    let optimizationId: String
    let sourceURLString: String?
    let coverLetterText: String?
    let screeningAnswers: [SubmitPackageCachedScreeningAnswer]
    let savedAt: Date
    // added:
    let coverLetterRunId: String?
    let coverLetterSelectionIndex: Int?
    let screeningRunId: String?
}
```

The three new fields are optional, so records already persisted under
`submit_package_records` continue to decode (synthesized `Codable` uses
`decodeIfPresent` for optionals).

`AppState` gains a merge-not-clobber writer so a partial write from one surface cannot
erase another surface's fields:

```swift
func rememberExpertArtifacts(
    for optimizationId: String,
    coverLetterText: String?,
    coverLetterRunId: String?,
    coverLetterSelectionIndex: Int?,
    screeningAnswers: [SubmitPackageCachedScreeningAnswer]?,
    screeningRunId: String?
)
```

`nil` means "leave whatever is stored"; a non-nil value replaces. `sourceURLString` is
never touched by this method. `rememberSubmitPackage` keeps its current signature and
behaviour and additionally records the run ids.

With that, the three surfaces line up: **Expert writes the record, Export reads it,
Submit reuses it.**

## Story 1 — Expert output becomes durable

`ExpertModesViewModel.run()` (`ExpertModesViewModel.swift:126`) persists to the record
the moment a `.coverLetterArchitect` or `.screeningAnswerStudio` run reaches `.ready`,
and `setSelectedVariantIndex` updates the stored cover-letter text when the user picks a
different variant.

**Persist on run, not on apply.** The walk ran the cover-letter mode and expected the
letter in the export. Apply is a separate tap that, for these two workflow types, mainly
records a server-side variant choice (`select_cover_letter_variant` /
`select_screening_answers`, `ExpertWorkflowService.swift:176-187`). Gating persistence on
apply would reproduce the exact surprise this work exists to fix.

Which text is stored: the variant at the selected index, falling back to the recommended
index, matching the resolution `SubmitApplicationViewModel` already performs
(`SubmitApplicationViewModel.swift:135-139`). Empty or whitespace-only output is not
stored — an empty record must be indistinguishable from no record.

`ExpertModesViewModel` has no `AppState` today. It takes one as an injected dependency
so the persistence is testable without a view.

**Files:** `App/AppState.swift`, `Features/V2/Expert/ExpertModesViewModel.swift`,
`Features/V2/Expert/ExpertTabView.swift` and `Features/Track/ApplicationDetailView.swift`
(construction sites), tests.

**Tests:** a ready cover-letter run writes text + run id + selection index; a ready
screening run writes answers + run id; switching variant rewrites the text; empty output
writes nothing; a screening write does not erase a stored cover letter, and the reverse;
`sourceURLString` survives an artifact write.

## Story 2 — Export delivers the package

New `Core/Export/ApplicationPackageBuilder.swift` turns the résumé PDF plus the record
into the file set:

```swift
struct ApplicationPackageInputs: Sendable {
    let optimizationId: String
    let resumePDFURL: URL
    let candidateName: String?
    let jobTitle: String?
    let company: String?
    let coverLetterText: String?
    let screeningAnswers: [SubmitPackageCachedScreeningAnswer]
}

struct ApplicationPackage: Sendable {
    let fileURLs: [URL]          // résumé first, always non-empty
    let includedCoverLetter: Bool
    let includedScreeningAnswers: Bool
    let coverLetterFailed: Bool  // artifact existed but could not be rendered
}
```

Naming is `<Name> - Resume - <Company>.pdf`, with the name and company components
dropped when unknown rather than replaced with placeholders (`Resume.pdf` is honest;
`Unknown - Resume - Unknown.pdf` is not). Filename components are sanitized with the
existing allow-list approach in `ExportFileStore.safeFilenameComponent`, and the résumé
is copied to its display name so the three files read as one set.

`ExportFileStore` (`HTMLPDFExporter.swift:97`) gains `write(_ data: Data, filename:
String)` and `writeText(_ string: String, filename: String)`; `writePDFData` keeps its
current signature and delegates.

`ResumeExportAction.Result` gains `packageFileURLs: [URL]` and the three flags above.
`fileURL` stays the résumé PDF so existing call sites and the export-completion path are
unchanged.

**Degradation rule:** a cover-letter render failure never fails the export. The résumé
ships, `coverLetterFailed` is true, and the success state says the letter could not be
attached. The same holds for an absent artifact — that is `includedCoverLetter == false`
and a route to Expert, not an error.

`OptimizedResumeView` changes: share sheet takes `result.packageFileURLs`; the primary
button reads "Export application package"; `exportSuccessActions` lists what was included
and what was not, with "Write one in Expert" calling `onSwitchTab(.expert)`; the Submit
Package button becomes the secondary "Save this application to Me" (sheet internals
unchanged, retitled so it stops implying something is sent).

Analytics: `export_success` gains `has_cover_letter` and `has_screening`. Without them
there is no way to tell whether anyone ever exports a full package, which is the whole
point of the change.

**Files:** new `Core/Export/ApplicationPackageBuilder.swift`,
`Core/Export/HTMLPDFExporter.swift`, `Core/Export/ResumeExportAction.swift`,
`Features/V2/Improve/OptimizedResumeView.swift`, `Core/Analytics/AnalyticsService.swift`,
tests.

**Tests:** file set with no artifacts (résumé only), with a cover letter, with both;
filename composition and sanitization including missing name/company; screening-answers
text formatting; a render failure yields résumé-only with `coverLetterFailed` true; empty
cover-letter text produces no file.

## Story 3 — Submit stops regenerating

`SubmitApplicationViewModel.submit()` consults the stored record first and calls
`expertService.run` only for what is genuinely missing — cover letter and screening are
decided independently.

`savePackageToMe` still works because the record carries `coverLetterRunId` and
`screeningRunId`. A legacy record holding text but no run id supplies the text and skips
that artifact's `expertService.apply` + `saveExpertReport` calls rather than failing.

The record is injected when the sheet is constructed in `openSubmitPackage()`, so the
view model needs no `AppState` reference and stays testable.

**Files:** `Features/V2/Improve/SubmitApplicationViewModel.swift`,
`Features/V2/Improve/OptimizedResumeView.swift`, tests.

**Tests:** with a full stored record the spy expert service fails the test if `run` is
called, and the package still carries the cover letter and answers; with a
cover-letter-only record, screening runs and the cover letter does not; with no record,
behaviour is exactly as today; a record with text but no run id still produces a package
and skips that apply call.

## Verification

Per story: Xcode build, the story's focused tests, and `tasks/progress.md` updated. After
story 2, a simulator smoke of the export path capturing the share sheet contents.

New test files need their four `project.pbxproj` entries (PBXBuildFile,
PBXFileReference, PBXGroup child, Sources build phase) or they silently never compile and
the build still reports success — `tasks/lessons.md:93`. "Executed 0 tests" is a failed
verification, never a pass. Pin `-testLanguage en -testRegion US`
(`tasks/lessons.md:659`) and run on the iOS 26.5 runtime, not 26.3.1
(`tasks/lessons.md:88`).

## Scope

Eight files across three stories, `OptimizedResumeView.swift` touched twice. This is past
the >3-unexpected-files gate and is stated up front rather than discovered mid-build: it
is inherent to a change spanning three surfaces. Stories land one at a time, each
independently verifiable.

## Explicitly out of scope

- Merging the cover letter into the résumé PDF. ATS parsers treat the résumé file as one
  document; appending pages corrupts it.
- Generating expert artifacts from the Export path.
- Any change to the expert workflows themselves or their prompts.
- The two latent `ReviewPromptGate` defects from `wp69-review-prompt-audit-2026-08-05.md`.
  The device walk showed the prompt does fire; they stay on record and out of this work.
