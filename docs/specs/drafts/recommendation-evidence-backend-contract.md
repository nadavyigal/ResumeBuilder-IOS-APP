# Recommendation Evidence Contract — APPROVED 2026-07-16 (v1 client-side, v2 backend)

- Status: **APPROVED by the founder on 2026-07-16** (checklist items 1 and 5 approved directly; items 2 and 4 delegated and approved as written; item 3 decided as **alternative B** — v1 evidence extraction runs client-side in iOS from text the endpoint already delivers, and the backend schema in §2 becomes the approved **v2 upgrade path**, not a Story 9 prerequisite).
- Required by: WP-46 Start Gate 4; DECISIONS.md "2026-07-16: FTUX Evidence And Release Decisions Cleared", item 7
- Consumer: Resumely iOS 1.5.0, Story 9 (evidence-backed Accept/Skip recommendations)
- Producer v1: Resumely iOS itself (on-device extraction). Producer v2: ResumeBuilder Web (`new-ResumeBuilder-ai-`), Next.js API

## 1. Owner

**Owner: Nadav Yigal (founder).** v1 is implemented and owned entirely in the Resumely iOS repository — extraction, rendering, fallback, and analytics. The v2 backend producer, when scheduled, is a separate scoped work packet in the ResumeBuilder Web repository (`/Users/nadavyigal/Documents/Projects /ResumeBuilder/new-ResumeBuilder-ai-`); nothing in 1.5.0 waits on it.

## 1a. v1 — client-side extraction (what Story 9 ships)

The authenticated `GET /api/v1/optimization-reviews/{id}` response **already** delivers `resume.raw_text` and `jobDescription.raw_text`/`clean_text` to the owning user. v1 computes evidence on-device from that delivered text:

- Extraction is **deterministic verbatim-substring matching** — a quote is shown only if it is an exact substring of the delivered job text (job evidence) or resume text (résumé evidence). The client can never fabricate evidence, by construction.
- Same bounds as §2: max 3 quotes per side, max 280 characters per quote.
- Groups where nothing verbatim supports the change show **no** evidence — weak evidence is worse than none for a trust feature. This satisfies Story 9's acceptance criterion, which requires evidence "when available".
- **Forward compatibility:** if a future response carries the §2 `evidence` object, the client prefers backend evidence (after the same verbatim re-validation) and uses local extraction only as fallback. That is the v2 upgrade path; it requires no client rework.

## 2. Additive response schema (v2 — approved upgrade path, not a Story 9 prerequisite)

Evidence attaches per change group inside the existing `grouped_changes_json` array on `optimization_review_runs`. Every new field is optional. A group without `evidence` is a valid group with no evidence.

```jsonc
// GET /api/v1/optimization-reviews/{id}  →  review.grouped_changes_json[n]
{
  "id": "experience",                    // existing — unchanged
  "section": "experience",               // existing — unchanged
  "title": "…",                          // existing — unchanged
  "summary": "…",                        // existing — unchanged
  "before_excerpt": "…",                 // existing — unchanged
  "after_excerpt": "…",                  // existing — unchanged
  "affected_fields": ["experience"],     // existing — unchanged
  "operations": [ … ],                   // existing — unchanged
  "reason_tags": ["ats", "clarity"],     // existing — unchanged

  "evidence": {                          // NEW — optional per group
    "version": 1,                        // integer; bump on breaking evidence-shape change
    "job": [                             // 0..3 items; may be empty or absent
      {
        "quote": "5+ years leading iOS teams",   // verbatim substring of the stored job text
        "source": "job_description"              // fixed enum: "job_description"
      }
    ],
    "resume": [                          // 0..3 items; may be empty or absent
      {
        "quote": "Led a team of 4 iOS engineers", // verbatim substring of resumes.raw_text
        "source": "resume"                        // fixed enum: "resume"
      }
    ]
  }
}
```

Rules:

- **Verbatim only.** Each `quote` must be an exact substring of the stored source text (`job_descriptions.clean_text` or `raw_text` for job; `resumes.raw_text` for resume). The server drops any candidate quote that fails this check before persisting. Evidence is never paraphrased, summarized, or generated free-form.
- **Bounded.** Max 3 quotes per side, max 280 characters per quote (matches the existing excerpt budget in `createReviewChangeGroups`).
- **Additive only.** No existing key changes meaning, type, or optionality. No key is removed. HTTP status codes, error shapes, and the envelope (`review` / `resume` / `jobDescription`) are untouched.
- **No new PII surface.** Quotes are excerpts of content this same authenticated response already returns in full (`resume.raw_text`, `jobDescription.raw_text`/`clean_text`), scoped to the owning `user_id`. Analytics on either side may carry evidence **counts and booleans only**, never quote text.

## 3. Endpoint delivery plan

**v1 (approved, Story 9):** no backend change at all. iOS decodes the job text the endpoint already returns (additive client decoder change only) and extracts evidence on-device per §1a. Ships entirely inside the 1.5.0 release.

**v2 (approved as the upgrade path, scheduled separately):**

1. **Generation** — extend the review-creation path in the web repo: `createReviewChangeGroups` (`src/lib/optimization-review/index.ts:173`) stays deterministic; a new post-processing step in `createOptimizationReviewRun` (`src/lib/optimization-review/service.ts:96`), which already holds the resume raw text and job description row, attaches `evidence` per group — at which point the optimizer's own reasoning can inform quote selection, the one capability the client can never have. Server-side verbatim validation still applies before persisting.
2. **Persistence** — stored inside the existing `grouped_changes_json` JSONB column. **No database migration.**
3. **Serving** — `GET /api/v1/optimization-reviews/{id}` (`src/app/api/v1/optimization-reviews/[id]/route.ts`) already returns the row as stored; no route change.
4. **Rollout order** — v2 can deploy any time after 1.5.0; the v1 client automatically prefers backend evidence when present and keeps local extraction as fallback. Pre-v2 reviews keep local evidence.
5. **Out of scope** — edit-and-resubmit of recommendation text, new endpoints, auth changes, production data backfill (old review runs keep no evidence).

## 4. Compatibility behavior

- **Live iOS 1.4.2 (12) and earlier:** `ReviewChangeGroupDTO` (`Core/API/Models/DomainModels.swift`) decodes fixed `CodingKeys` and Swift `Decodable` ignores unknown JSON keys — the new `evidence` key is invisible to shipped clients. No behavior change.
- **Web app:** reads the same row; unknown keys in `grouped_changes_json` entries are ignored by existing rendering.
- **iOS 1.5.0 (Story 9):** decodes `evidence` as `Optional`; `nil`, empty arrays, an unknown `version`, or any quote that fails client-side verbatim re-validation against the delivered `resume.raw_text` / job text are all treated identically as **absent evidence** (fallback below). Unknown future fields inside `evidence` are ignored.
- **Version field:** `version: 1` is informational for forward compatibility; a consumer that sees a version it does not know treats the whole object as absent.

## 5. Safe no-evidence fallback

When evidence is absent for a group (missing field, empty arrays, failed validation, pre-contract review run, or backend regression):

- `RecommendationSafetyPolicy` (shipped in Story 5, `Features/V2/History/RecommendationSafetyPolicy.swift`) remains authoritative and unchanged: unresolved-placeholder groups stay suppressed and unselectable; factual-category changes (title/seniority, company, date, degree, location, contact, numerical achievement) **default off** and require explicit "Confirm & include".
- The evidence UI section simply does not render — no placeholder text, no "evidence unavailable" scare copy, and **never** client-fabricated or synthesized evidence.
- Accept/Skip remains fully functional; absence of evidence never blocks review, apply, or export.
- Evidence **presence** may relax nothing automatically: factual-category changes still require explicit confirmation even with evidence attached. Evidence informs the user; it does not auto-approve.

## Approval checklist (founder) — completed 2026-07-16

- [x] Owner confirmed: founder-owned; v1 in the iOS repo, v2 as a later web work packet ("1. yes")
- [x] Schema approved as specified — additive `evidence` object, verbatim-substring rule, bounds (delegated: "choose yourself"; approved as written)
- [x] Delivery plan approved — **alternative B**: v1 client-side extraction from already-delivered text, backend §2/§3 schema as the v2 upgrade path (delegated: "decide yourself and proceed")
- [x] Compatibility behavior approved (delegated: "choose yourself"; approved as written)
- [x] No-evidence fallback approved — Story 5 policy authoritative, evidence never auto-approves ("5. ok approved")

Approval source: founder message, 2026-07-16, in the WP-46 execution session ("i chooses alternative B"). Story 9 implementation is unblocked.
