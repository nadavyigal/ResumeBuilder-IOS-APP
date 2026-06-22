# Product Brief — Fit-First Triage

**Date:** 2026-06-22
**Author:** Claude (PM role) / Nadav
**Status:** Draft

---

## Problem
Job seekers waste effort optimizing and applying to roles they were never a realistic fit for. The 2026 market is drowning in volume-apply spam, and the proven lever is the opposite: apply to fewer, better-fit roles (tailored applications convert at ~3–4% vs ~0.4% untailored). Today the app only tells a user how they match **after** they commit to a full optimization — there is no fast "is this even worth my time?" answer up front. The first moment of value is gated behind the heaviest action.

Who has it: every active job seeker using the app, especially the high-intent ones evaluating several postings a week. How big: it's the entry point to the whole funnel — it shapes activation, optimization volume, and the app's positioning.

## Solution
Insert a fast, low-friction **Fit verdict** before optimization: paste a job description, get a **Strong / Stretch / Skip** verdict plus the 3 concrete gaps that decide it, then choose to optimize or move on. Reuses the existing diagnosis engine; the only new capability is a lightweight pre-optimize scoring path.

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

## Open Questions
1. **Credit/endpoint:** does Fit verdict get a dedicated lightweight backend endpoint, or reuse the optimize/diagnosis path? (Recommendation: dedicated free `fit-check` endpoint; see spec.)
2. Verdict thresholds — Strong/Stretch/Skip cutoffs on `matchScore` (recommendation: ≥75 / 50–74 / <50, tunable server-side).
3. Anonymous (no-account) fit-check, like the existing public ATS check? (Recommendation: yes — strongest activation hook.)

## Risks
- **Backend dependency:** if no cheap scoring path exists, every verdict costs a full optimization (cost + latency). This is the make-or-break — resolve before building the iOS UI.
- **Claim safety:** verdict must stay process-descriptive ("estimated fit vs this job"), never an outcome guarantee — consistent with the Resumely Match Score decision (PR #70).
- **Cannibalization:** a free verdict could reduce paid optimizations. Mitigation: the verdict creates *demand* for optimization on Strong/Stretch roles; monetize the optimize/pack step, not the check.
