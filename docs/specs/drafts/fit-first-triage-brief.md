# Product Brief — Fit-First Triage

**Date:** 2026-06-22
**Author:** Claude (PM role) / Nadav
**Status:** Draft

---

## Problem
Job seekers waste effort optimizing and applying to roles they were never a realistic fit for. The 2026 market is drowning in volume-apply spam, and the proven lever is the opposite: apply to fewer, better-fit roles (tailored applications convert at ~3–4% vs ~0.4% untailored). Today the app only tells a user how they match **after** they commit to a full optimization — there is no fast "is this even worth my time?" answer up front. The first moment of value is gated behind the heaviest action.

Who has it: every active job seeker using the app, especially the high-intent ones evaluating several postings a week. How big: it's the entry point to the whole funnel — it shapes activation, optimization volume, and the app's positioning.

## Solution
Insert a fast, low-friction **Fit verdict** before optimization: paste a job description, get a **Strong / Stretch / Skip** verdict plus the 3 concrete gaps that decide it, then choose to optimize or move on. **We do not build a new endpoint — we evolve the existing free ATS check (`/api/public/ats-check`) into the Fit check on web and mirror it to iOS.** That endpoint is already anonymous, rate-limited (5 checks / 7 days per IP), and already computes the score, subscores, suggestions, quick wins, and extracted job requirements (`must_have`) we need; the verdict band + decisive gaps are a derivation on top of outputs it already produces. iOS already calls this endpoint.

## User Story
As a job seeker evaluating a posting, I want an instant fit verdict and the few things standing between me and this job, so that I only invest effort in roles I can realistically win.

## Scope (In)
- Paste a job description → fast Fit verdict (Strong / Stretch / Skip) against the user's active resume.
- Show the 3 decisive gaps + top missing keywords driving the verdict.
- Clear next actions: **Optimize for this job** (existing flow) or **Skip / save for later**.
- Verdict is cheap and does not consume an optimization credit (top-of-funnel hook).
- Reuse `ResumeDiagnosis` types (`matchScore`, `topGaps`, `missingKeywords`).

## Scope (Out)
- Share-extension "forward a job posting" inbox (fast-follow, separate story).
- Job discovery / job board / pulling postings automatically.
- Outcome tracking (that is Wedge 3, a separate spec).
- Multi-resume "which resume fits best" comparison (future).

## Success Metrics
- **Activation:** % of new users who reach a Fit verdict in session 1 (target: higher than current % who reach a first optimization).
- **Funnel quality:** optimize → export conversion rate increases (users optimize fewer but better-fit roles).
- **Engagement:** fit-checks per active user per week (new habit metric).
- **For the user:** "I know in 10 seconds whether to bother with this job, and exactly what's missing."

## Decisions (resolved)
- **Endpoint (was Open Question 1):** Do **not** add a new endpoint. **Replace the existing free ATS check (`/api/public/ats-check`) with the Fit check on web, then mirror it to iOS.** It already provides the free + anonymous + rate-limited scoring path. Verdict band + decisive gaps are derived from its existing `scoreResume` / `extractJob` outputs (`must_have` requirements not matched in the resume → gaps/missing keywords).
- **Anonymous (was Open Question 3):** Yes — the endpoint is already anonymous via `x-session-id`, and `convert-session` already upgrades an anonymous result to an account. This is the activation hook; keep it.
- **Verdict thresholds (was Open Question 1, founder-confirmed):** ≥75 strong / 50–74 stretch / <50 skip. Owned server-side in `formatResponse`, tunable post-ship without an app release.
- **Resume input contract (was Open Question 2, founder-confirmed):** iOS passes the stored `resume_id` (resume already on file in-app) instead of re-uploading a PDF. Story 0 adds server support for an authenticated `resume_id` input alongside the existing anonymous PDF-upload path (unchanged for web).

## Open Questions
1. **[Non-blocking — can proceed in parallel]** The web check enforces **JD ≥ 100 words**; confirm the same minimum for the iOS paste flow (recommendation: yes, keep parity).

## Risks
- **Cross-repo change:** this now spans two repos — web (`new-ResumeBuilder-ai-`: evolve `/api/public/ats-check` to return the verdict + gaps) and iOS (mirror the new fields). The web change must land first; the iOS UI can be built against a mock in the meantime.
- **Don't break the existing free check:** the web endpoint is live and consumed by both web and the iOS public ATS path. Added fields must be **additive** (new keys), leaving `score` / `preview` / `quickWins` / `checksRemaining` intact.
- **Claim safety:** verdict must stay process-descriptive ("estimated fit vs this job"), never an outcome guarantee — consistent with the Resumely Match Score decision (PR #70).
- **Cannibalization:** a free verdict could reduce paid optimizations. Mitigation: the verdict creates *demand* for optimization on Strong/Stretch roles; monetize the optimize/pack step, not the check.
