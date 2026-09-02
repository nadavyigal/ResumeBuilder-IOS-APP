# Career Evidence Pilot — Product Brief

**Date:** 2026-08-10  
**Author:** Codex, derived from IDEATION-2026-08-09-RESUMELY-01  
**Status:** Draft — founder approval required before implementation

## Objective

We are building a bounded, evidence-first improvement so that an active job seeker can see which important role requirements are supported, clarify up to three high-value unknowns, and produce a stronger truthful application without rebuilding their career history for every job.

## Why this plan exists

The Resumely IDEATION pilot reached a **CONDITIONAL GO**, not authorization for the full Career Evidence & Job Match Engine. It authorized only the smallest prototype that can test:

1. whether users possess useful evidence beyond the active résumé;
2. whether a few targeted questions recover that evidence efficiently;
3. whether recovered evidence improves a reviewed application without inventing facts; and
4. whether confirmed evidence is useful again on a later application.

The plan is downstream of IDEATION. It does not change the pilot decision or convert its hypotheses into current product facts.

## Current-state reconciliation

Fresh sources override the August 9 ideation snapshot:

- `tasks/progress.md` on 2026-08-10 records Resumely iOS 1.4.8 live and the iOS half of the WP-64 bullet/score repair shipped.
- Agentic OS `PROJECT-STATUS.md` records that the web half of WP-64 still needs to land and an authenticated physical-device walk against 1.4.8 remains owed.
- The current iOS review flow already has deterministic verbatim recommendation evidence, `RecommendationSafetyPolicy`, evidence inputs in Expert workflows, and application persistence. The pilot must extend these seams rather than build a parallel experience.
- The existing upload step remains the highest-evidence activation opportunity (`n=27` in the current operating record). This pilot must not silently displace that work.

## Problem

Resumely can explain and rewrite the uploaded résumé, but the document remains the main source of candidate truth. When the résumé lacks proof for an important requirement, the system cannot reliably distinguish:

- the candidate does not have the capability;
- the candidate has it but omitted the evidence;
- the available evidence is partial; or
- the system simply does not know.

That ambiguity weakens recommendations and encourages document-level rewriting when the higher-value action may be recovering truthful career evidence.

## Solution

Add an optional **Evidence Map** to the existing authenticated optimization-review flow. It will show a bounded set of important requirements and their evidence coverage, invite no more than three questions for `unknown` items, let the user confirm new evidence, regenerate only affected recommendations, and make confirmed evidence available for one later application.

The experience is a thin extension of `OptimizationReviewView` and the approved recommendation-evidence contract. It is not a new graph, tab, career database, onboarding flow, or platform.

## User story

As an active job seeker reviewing a tailored résumé, I want to see which important job requirements are supported and clarify only the most valuable unknowns so that the final application is truthful, specific, and easier to reuse for a later job.

## Scope (in)

- Additive requirement/evidence contract with explicit provenance.
- Four coverage states: `supported`, `partial`, `unknown`, and user-confirmed `missing`.
- `unknown` by default when the system lacks proof; never infer that the user lacks a capability.
- Optional Evidence Map entry from the existing optimization-review journey.
- At most three high-value questions per application.
- User confirmation before new factual evidence can influence generated content.
- Targeted regeneration of affected recommendation groups.
- Existing Accept/Skip safety policy remains authoritative.
- Persist confirmed evidence for reuse in one subsequent application.
- PII-safe analytics using IDs, counts, states, and booleans only.
- iPhone 17 and compact-device UI verification in English and Hebrew/RTL.

## Scope (out)

- Full Career Evidence platform or master-profile migration.
- Graph database or graph UI.
- Resume creation from scratch.
- Historical résumé, LinkedIn, email, browser, job-board, or ATS integrations.
- Universal ATS prediction, hiring-probability claims, or opaque fit scoring.
- Mass auto-apply.
- More than three enrichment questions in the pilot.
- Automatic acceptance of generated factual claims.
- Monetization, pricing, or Gate A changes.
- Replacing WP-62 upload work or the current WP-64 repair sequence.

## Success metrics

These are **planning thresholds for a bounded validation**, not evidence-derived market benchmarks.

### Integrity gates

- 100% of newly generated factual claims in the pilot fixture set trace to verbatim résumé evidence or user-confirmed evidence.
- Zero `missing` states inferred without explicit user confirmation.
- Zero evidence text, résumé text, job text, or answers emitted to analytics.
- Existing review/apply/export remains functional when the evidence payload is absent, empty, invalid, or an unknown version.

### Product-learning gates

- At least 10 eligible completed Evidence Map sessions before a product verdict.
- At least 30% of completed maps recover one confirmed evidence item not present in the active résumé.
- At least 70% of submitted evidence answers produce a reviewable affected recommendation or an explicit honest “no change” result.
- At least 20% of eligible second-job sessions reuse one previously confirmed evidence item.
- A manual downstream study confirms that users understand `unknown` versus `missing`; IDEATION itself does not perform this test.

### Kill criteria

- Any unsupported factual claim reaches a reviewable or exported résumé.
- Users must answer questions to finish the existing optimization/export flow.
- The backend cannot preserve provenance through regeneration.
- The map materially duplicates current review evidence without recovering new evidence.
- Fewer than 10 eligible sessions can be observed within the agreed validation window; report insufficient evidence rather than success or failure.

## Preconditions before Story 1

1. Founder approves this brief, spec, and story sequence.
2. The web half of WP-64 is deployed and the 1.4.8 authenticated physical-device walk is recorded.
3. Founder confirms whether this pilot follows, runs alongside, or waits behind WP-62; no priority change is implied by this document.
4. The additive backend contract and data-retention policy are approved before production evidence persistence.

## Open questions

1. Should confirmed evidence persist server-side immediately, or remain device-local until the first value test? Cross-device and cross-application reuse favor server persistence; privacy and scope favor a smaller first pass.
2. Which existing endpoint owns the map: optimization review, optimization detail, or a new narrowly scoped evidence endpoint?
3. Does targeted regeneration create a new review run or version the existing one?
4. What deletion/export behavior is required for confirmed career evidence?
5. Is the first eligible validation cohort internal dogfood, TestFlight, or public traffic?

## Risks

- Extra questions can worsen an already fragile activation funnel.
- Requirement priority may be inferred incorrectly from an incomplete job post.
- Coverage states may communicate false precision.
- Sensitive career evidence may create new privacy and retention obligations.
- Cross-application reuse can be wrong when roles differ materially.
- The current low-traffic environment may not produce enough eligible sessions for a timely verdict.

## Source artifacts

- Resumely IDEATION Step 1–8 reports: `/Users/nadavyigal/Documents/Codex/2026-08-09/referenced-chatgpt-conversation-this-is-an/outputs/`
- Vault run registry: `02-Products/ResumeBuilder/Strategy/Resumely IDEATION Pilot.md`
- iOS current state: `tasks/progress.md`, read 2026-08-10
- Agentic OS current state: `PROJECT-STATUS.md`, read 2026-08-10
- Existing evidence contract: `docs/specs/drafts/recommendation-evidence-backend-contract.md`
