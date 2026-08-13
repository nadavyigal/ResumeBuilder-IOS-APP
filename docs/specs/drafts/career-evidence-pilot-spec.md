# Career Evidence Pilot — Feature Specification

**Date:** 2026-08-10  
**Status:** Draft — not approved for implementation  
**Depends on:** `career-evidence-pilot-brief.md`

## Traceability to IDEATION

| Pilot mechanism | Problems | Root causes | Plan implementation |
|---|---|---|---|
| M01 Requirement structuring | P02, P04 | RC1, RC4 | Bounded high-priority requirement list with explicit/inferred provenance |
| M02 Explicit requirement-evidence mapping | P03, P04 | RC4 | Evidence Map and typed links |
| M03 Coverage states | P01, P04 | RC4, RC5 | Supported / partial / unknown / confirmed missing |
| M04 Progressive evidence discovery | P03 | RC2, RC3, RC8 | Maximum three high-value questions |
| M05 Provenance and truth gate | P03, P07 | RC5 | Resume/user-confirmed sources; no-source/no-claim rule |
| M06 Persistent reuse | P05 | RC6, RC7 | Reuse confirmed evidence on one later application |
| M07 Explainable recommendation | P04, P05 | RC4, RC8 | Show requirement, evidence, change, and reason together |

## Goals

- Test the smallest coherent evidence-first loop inside the existing iOS review journey.
- Recover truthful evidence omitted from the uploaded résumé without fabricating achievements.
- Make uncertainty legible by separating `unknown` from user-confirmed `missing`.
- Reuse confirmed evidence on a later application.
- Preserve current review/apply/export behavior when the new contract is absent.

## Non-goals

- Building the full product direction described in IDEATION Step 6.
- Replacing Fit, Optimize, Expert, History, or application tracking.
- Creating a graph architecture, new global tab, new onboarding gate, or new dependency.
- Producing employer probability, universal ATS, or hiring-outcome predictions.
- Automatically inserting unconfirmed facts.

## Experience placement

The pilot enters from the authenticated optimization-review surface after the first recommendation set exists. It is **optional** and cannot block Accept/Skip, apply, preview, or export.

This placement is deliberate:

- It leverages `OptimizationReviewView`, `RecommendationEvidence`, and `RecommendationSafetyPolicy` already in production.
- It avoids inserting another gate before activation.
- It gives the system concrete gaps and recommendations from which to choose high-value questions.

## End-to-end journey

1. User uploads a résumé, adds a job, and completes the existing optimization path.
2. Optimization review loads normally.
3. If a valid evidence-map payload exists, the review shows an optional “Strengthen with your evidence” entry with counts only.
4. Evidence Map shows at most five high-priority requirements and one coverage state per requirement.
5. Each state explains its meaning and provenance:
   - **Supported:** strong verbatim résumé evidence or confirmed evidence exists.
   - **Partial:** some relevant evidence exists, but it does not fully support the requirement.
   - **Unknown:** the system has no adequate evidence and does not know whether the candidate has it.
   - **Missing:** the candidate explicitly confirmed they do not have this capability/evidence.
6. User may answer up to three questions selected for decision value, not curiosity.
7. Each answer is previewed as a candidate evidence item. The user must confirm or discard it.
8. Confirmed evidence carries source, timestamp, job/application context, and user-confirmation provenance.
9. Server regenerates only affected recommendation groups. The user sees which requirement and evidence caused each change.
10. Existing review safety policy applies; factual changes never auto-select.
11. On a later application, a relevant confirmed evidence item may be proposed for reuse. User confirms relevance before it affects output.

## Domain objects

All new Swift value types are `Codable`, `Equatable`, and `Sendable`. UI state lives in an `@Observable @MainActor` ViewModel.

### EvidenceMap

- `version: Int`
- `optimizationID: String`
- `applicationID: String?`
- `requirements: [RoleRequirement]` (max five rendered in pilot)
- `questions: [EvidenceQuestion]` (max three)
- `updatedAt: Date`

### RoleRequirement

- `id: String`
- `text: String`
- `importance: high | medium | low`
- `origin: explicit | inferred`
- `confidence: Double?`
- `coverage: EvidenceCoverageState`
- `links: [EvidenceLink]`

### EvidenceCoverageState

- `supported`
- `partial`
- `unknown`
- `missingConfirmed`

There is no inferred `missing` state.

### CareerEvidenceItem

- `id: String`
- `text: String`
- `capabilities: [String]`
- `source: resume | userConfirmed`
- `sourceReference: String?`
- `confirmedAt: Date?`
- `createdFromApplicationID: String?`

### EvidenceLink

- `id: String`
- `requirementID: String`
- `evidenceID: String`
- `strength: strong | partial`
- `reason: String`
- `confidence: Double?`

### EvidenceQuestion

- `id: String`
- `requirementID: String`
- `prompt: String`
- `whyItMatters: String`
- `answer: String?`
- `status: unanswered | drafted | confirmed | discarded`

## API contract

Story 1 must approve an additive, versioned backend contract before feature code proceeds. Candidate shape:

- `GET /api/v1/optimization-reviews/{id}` gains optional `evidence_map`.
- A narrow authenticated write submits a question answer and explicit confirmation.
- A narrow authenticated action requests regeneration of affected groups.
- A later review response carries the regenerated groups and provenance links.

Contract requirements:

- Old clients ignore new fields; new clients treat absent/unknown-version payloads as no feature.
- Ownership is enforced server-side by authenticated user and optimization/application IDs.
- Verbatim résumé evidence is revalidated against delivered source text.
- User-confirmed evidence is never treated as résumé-verbatim evidence.
- Analytics receive counts, states, and IDs only—never text.
- Data retention, deletion, and export behavior are documented before production persistence.
- No database/graph technology is prescribed by this iOS plan.

## iOS architecture

### New files

- `Features/V2/Evidence/EvidenceMapView.swift`
- `Features/V2/Evidence/EvidenceMapViewModel.swift`
- `Features/V2/Evidence/EvidenceQuestionView.swift`
- `Features/V2/Evidence/EvidenceModels.swift`
- `Core/API/CareerEvidenceService.swift`

### Existing files expected to change

- `Core/API/Models/DomainModels.swift` — additive DTO decoding.
- `Core/API/Endpoints.swift` — only after contract approval.
- `Features/V2/History/OptimizationReviewView.swift` — optional entry and regenerated-group refresh.
- `Features/V2/History/RecommendationEvidence.swift` — reuse validation helpers where appropriate; do not weaken verbatim rules.
- `Features/V2/History/RecommendationSafetyPolicy.swift` — expected to remain behaviorally unchanged; add regression coverage.
- `Core/Analytics/AnalyticsService.swift` — bounded PII-safe events.
- `Services/MockResumeServices.swift` or feature-local fixtures — supported/partial/unknown/missing states.
- `App/AppState.swift` only if a small non-sensitive feature flag or last-view marker is required; do not store raw evidence in UserDefaults.

### Persistence

Server persistence is preferred for confirmed evidence because cross-application reuse is a core hypothesis. If the first prototype is local-only, use a dedicated SwiftData model and record that cross-device reuse is untested. Never put raw career evidence in analytics or ordinary UserDefaults.

## AI behavior and trust rules

- AI can structure requirements, identify gaps, propose questions, and improve wording.
- AI cannot convert `unknown` to `missing`.
- AI cannot create or strengthen a factual claim without résumé-verbatim or user-confirmed evidence.
- A user answer remains a draft until explicit confirmation.
- Requirement importance inferred from a job description must be labeled inferred and confidence-bounded.
- When evidence is insufficient, return “no supported change” rather than inventing content.
- Reused evidence requires explicit relevance confirmation for the new role.

## Analytics

Candidate events:

- `evidence_map_available`
- `evidence_map_viewed`
- `evidence_question_viewed`
- `evidence_question_answered`
- `evidence_item_confirmed`
- `evidence_item_discarded`
- `evidence_regeneration_started`
- `evidence_regeneration_completed`
- `evidence_regeneration_no_change`
- `evidence_item_reuse_offered`
- `evidence_item_reused`
- `evidence_map_dismissed`

Allowed properties: optimization/application IDs, requirement ID, question ID, coverage state, counts, source enum, duration bucket, success/failure reason, app/build version, and internal-tester identity contract. No user-entered or source text.

## Accessibility, localization, and UX

- Dark-mode tokens only; use the existing design system.
- Dynamic Type through accessibility sizes without clipping.
- VoiceOver announces requirement, state, source, and action in that order.
- Hebrew/RTL must preserve semantic order and arrow direction.
- “Unknown” copy must say the system lacks evidence, not that the user lacks skill.
- Compact-device layout must not hide the existing review/apply/export actions.

## Failure and edge cases

- Missing/empty/unknown-version map: do not render the entry; existing review works.
- Network failure while answering: preserve local draft and show retry; do not mark confirmed.
- Late regeneration response after optimization/session change: discard using the existing stale-result pattern.
- Duplicate evidence: offer merge/reuse, never silently duplicate.
- Contradictory dates or metrics: block confirmation and ask the user to resolve.
- User deletes evidence: remove it from future reuse without rewriting historical exported artifacts.
- No supported output change: show an honest result and keep the confirmed evidence for later reuse only if the user agrees.

## Test strategy

- DTO compatibility: absent field, empty field, version 1, unknown version, malformed item.
- Coverage-state rule: only explicit confirmation creates `missingConfirmed`.
- Provenance: résumé quote must be verbatim; user answer remains distinct.
- Safety: evidence never auto-selects factual changes.
- State races: stale regeneration results cannot overwrite a newer optimization/session.
- Analytics: no text properties and correct person-level internal-tester contract.
- UI: supported/partial/unknown/missing, zero questions, three questions, long text, error/retry, RTL, Dynamic Type.
- End-to-end fixture: answer → confirm → targeted regeneration → review → export → second-job reuse.

## Acceptance criteria

1. Feature is additive and optional; existing review/apply/export passes unchanged without the new payload.
2. Map renders at most five requirements and three questions.
3. The client never infers `missingConfirmed`.
4. Every new factual recommendation cites résumé-verbatim or user-confirmed evidence.
5. User confirmation is required before an answer can influence generation.
6. Regeneration is scoped to affected recommendation groups.
7. Existing `RecommendationSafetyPolicy` remains authoritative.
8. Confirmed evidence can be proposed on a second application with explicit relevance confirmation.
9. Analytics contain no résumé, job, question, answer, or evidence text.
10. Focused tests, full suite, simulator UI smoke, and authenticated physical-device smoke pass before release consideration.

## Approval decisions required

1. Placement in the review flow.
2. Server versus local-first persistence.
3. Endpoint ownership and regeneration versioning.
4. Retention/deletion/export policy.
5. Priority relative to WP-62 and remaining WP-64 work.
6. Validation cohort and window.
