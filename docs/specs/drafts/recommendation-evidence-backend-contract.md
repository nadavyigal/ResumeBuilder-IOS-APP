# Recommendation Evidence Backend Contract — PROPOSED, awaiting founder approval

- Status: **PROPOSED 2026-07-16 — not approved. Story 9 code must not start until the founder approves this document.**
- Required by: WP-46 Start Gate 4; DECISIONS.md "2026-07-16: FTUX Evidence And Release Decisions Cleared", item 7
- Consumer: Resumely iOS 1.5.0, Story 9 (evidence-backed Accept/Skip recommendations)
- Producer: ResumeBuilder Web (`new-ResumeBuilder-ai-`), Next.js API

## 1. Owner

**Proposed owner: Nadav Yigal (founder), implementing in the ResumeBuilder Web repository** (`/Users/nadavyigal/Documents/Projects /ResumeBuilder/new-ResumeBuilder-ai-`), delivered as a separate scoped web work packet. The iOS repository owns only the consuming decoder and fallback behavior. No other backend exists for this endpoint, so ownership cannot sit anywhere else; what needs founder approval is committing web-repo capacity for the producing work packet.

## 2. Additive response schema

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

1. **Generation** — extend the review-creation path in the web repo: `createReviewChangeGroups` (`src/lib/optimization-review/index.ts:173`) stays deterministic; a new post-processing step in `createOptimizationReviewRun` (`src/lib/optimization-review/service.ts:96`), which already holds the resume raw text and job description row, attaches `evidence` per group by verbatim-substring extraction (v1 is deterministic matching — no new AI call, no new dependency). Groups where nothing verbatim supports the change get **no** evidence object, by design.
2. **Persistence** — stored inside the existing `grouped_changes_json` JSONB column. **No database migration.**
3. **Serving** — `GET /api/v1/optimization-reviews/{id}` (`src/app/api/v1/optimization-reviews/[id]/route.ts`) already returns the row as stored; no route change.
4. **Rollout order** — web work packet ships first (additive, safe for all existing clients); iOS Story 9 ships against it and treats pre-contract reviews (created before the web deploy) as no-evidence.
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

## Approval checklist (founder)

- [ ] Owner confirmed: web repo work packet, founder-owned
- [ ] Schema approved as specified (additive `evidence` object, verbatim-substring rule, bounds)
- [ ] Delivery plan approved (deterministic v1 extraction, no migration, web-first rollout)
- [ ] Compatibility behavior approved
- [ ] No-evidence fallback approved (Story 5 policy authoritative, evidence never auto-approves)

Once every box is checked, Story 9 implementation may begin per WP-46. Until then, Story 9 and everything behind it (Stories 10-13) stay blocked.
