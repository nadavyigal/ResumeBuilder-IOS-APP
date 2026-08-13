# Career Evidence Pilot — Story Plan

**Date:** 2026-08-10  
**Status:** Draft — stop after planning until founder approval  
**Brief:** `career-evidence-pilot-brief.md`  
**Spec:** `career-evidence-pilot-spec.md`

Each story is intended to fit within one focused session and leave a working build. The sequence is dependency-ordered; stories may not skip the contract, safety, or approval gates.

## Gate 0 — Current product work first

Before S1:

- Web WP-64 server repair is deployed.
- Authenticated 1.4.8 physical-device walk is recorded.
- Founder sets priority relative to WP-62.
- Brief/spec/stories are approved.

If any item is open, this plan remains documentation only.

## S1 — Freeze the additive evidence-map contract

**Goal:** Approve a versioned response/write/regeneration contract and retention policy without changing app behavior.

**Work:**

- Reconcile the candidate contract in the spec with the real web API and database.
- Define payload bounds, ownership, version behavior, provenance, deletion/export, and failure shapes.
- Produce fixtures for supported, partial, unknown, confirmed missing, absent, and unknown-version cases.

**Acceptance:**

- Contract is additive and old-client safe.
- `unknown` and user-confirmed `missing` are structurally distinct.
- No endpoint permits unconfirmed evidence to become a factual claim.
- Founder approves persistence and retention.

**Verification:** Schema review in both repositories; decode fixtures; Red Team privacy and unsupported-claim paths.

## S2 — Add models, decoder, and service seam

**Goal:** Decode and fetch the optional map with no visible UI change.

**Files:** `DomainModels.swift`, new `EvidenceModels.swift`, new `CareerEvidenceService.swift`, approved `Endpoints.swift` cases.

**Acceptance:**

- All value types are `Codable`/`Sendable`; ViewModel is `@Observable @MainActor`.
- Absent, empty, malformed, and unknown-version payloads resolve to feature unavailable without breaking review.
- Mock service supports deterministic fixtures.

**Verification:** Red-first decoder/service tests; app build.

## S3 — Render a read-only Evidence Map

**Goal:** Show at most five requirements and coverage states from fixtures/contract.

**Files:** new Evidence feature views/ViewModel; optional entry in `OptimizationReviewView.swift`.

**Acceptance:**

- Entry is optional and never blocks review/apply/export.
- Supported, partial, unknown, and confirmed missing copy is unambiguous.
- Explicit versus inferred requirements and evidence source are visible.
- Existing review evidence remains available and is not duplicated verbatim as a second competing panel.

**Verification:** ViewModel tests; iPhone 17 + compact simulator screenshots; Dynamic Type and VoiceOver snapshot; Hebrew/RTL smoke.

## S4 — Add the three-question progressive discovery flow

**Goal:** Ask only questions whose answer can change an application decision.

**Acceptance:**

- Maximum three questions.
- User can skip/dismiss without losing existing work.
- Answers remain local drafts until explicit confirmation.
- Draft survives a transient request failure but never masquerades as confirmed.

**Verification:** State-machine tests; offline/retry/stale-session tests; simulator interaction smoke.

## S5 — Confirm and persist evidence with provenance

**Goal:** Save a confirmed evidence item and its source chain.

**Acceptance:**

- Confirmation preview shows text, requirement, source, and intended use.
- Server enforces ownership and records `userConfirmed` provenance.
- Duplicate and contradictory evidence receives an explicit resolution path.
- Delete removes future reuse.

**Verification:** API contract tests in web repo; iOS service tests; privacy inspection; no raw text in logs/analytics.

## S6 — Regenerate only affected recommendation groups

**Goal:** Use confirmed evidence to produce one reviewable change without rerunning unrelated work.

**Acceptance:**

- Only linked groups are regenerated/versioned.
- Every factual change traces to résumé-verbatim or confirmed evidence.
- “No supported change” is a valid, visible result.
- Late results cannot overwrite a newer optimization/session.
- `RecommendationSafetyPolicy` still controls defaults and factual confirmation.

**Verification:** Red-first provenance, unsupported-claim, no-change, and stale-result tests; review/apply regression suite.

## S7 — Reuse evidence on one later application

**Goal:** Test the RC7 stateless-tailoring hypothesis without building a master career platform.

**Acceptance:**

- One relevant prior evidence item can be offered on a second application.
- User sees original context and confirms relevance.
- Rejection affects only the current application unless user deletes the evidence.
- No automatic cross-role reuse.

**Verification:** Two-application fixture; relevance-confirmation and deletion tests; authenticated simulator smoke.

## S8 — Instrument the bounded learning loop

**Goal:** Make the product-learning gates measurable without collecting content.

**Acceptance:**

- Events from the spec fire once at the correct visible/action boundaries.
- Properties contain IDs, counts, states, booleans, versions, and reason buckets only.
- No résumé/job/question/answer/evidence text reaches analytics.
- Internal tester is set at person level per the live contract.

**Verification:** Analytics payload tests; manual event-stream check on a test account; duplicate-event audit.

## S9 — Full pilot QA and release/no-release decision

**Goal:** Decide whether the prototype is safe enough for a bounded cohort—not whether the full platform should be built.

**Acceptance:**

- Focused suites and full suite pass on the supported simulator runtime.
- Simulator smoke passes on iPhone 17 and compact device, English and Hebrew/RTL.
- Authenticated physical-device journey passes: map → answer → confirm → regenerate → review → export → second-job reuse.
- Unsupported-claim and missing-confirmation adversarial fixtures fail closed.
- Founder receives a decision packet: release to bounded cohort, revise, or stop.

**Verification:** Build/test logs, screenshots, event-stream evidence, privacy check, and explicit unresolved risks.

## Post-release validation — separate workflow

After an approved bounded release, run the downstream validation contract from the brief. Do not call the full concept validated until the recovery, useful-change, reuse, trust, and comprehension gates have observed evidence. Record insufficient traffic as insufficient evidence.

## Explicit stop

Planning is complete when these three draft documents exist. No Swift, API, schema, analytics, task-progress, or release change is authorized until the founder approves the plan and Gate 0 clears.
