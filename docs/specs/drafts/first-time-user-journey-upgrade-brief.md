# Product Brief — Trustworthy First-Time Journey Upgrade

**Date:** 2026-07-13
**Author:** Codex
**Status:** Draft — awaiting founder approval
**Source audit:** `docs/audits/first-time-user-journey-audit.md`

## Problem

Resumely earns attention with a clear guest-first job-match check, but the first session loses continuity and trust before the user receives the promised deliverable. Users repeat Analyze and Check Fit after signup, see recommendations that can be malformed, regressive, or fact-changing, and can reach a blank post-Apply state where the optimized result remains locked despite existing in Account history. This blocks preview/export, undermines activation measurement, and makes monetization unsafe.

## Solution

Build one continuous, recoverable first-session journey:

**Choose résumé → Add job → See guest diagnosis → Create account → Review evidence-backed fixes → Preview optimized résumé → Save/export → Try another job.**

The upgrade will establish a deterministic completion route, one source of truth for optimization state, shared input validation, recommendation safety gates, deliberate user controls, and activation measured when the optimized result is actually rendered.

## User Story

As a first-time job seeker, I want Resumely to preserve my résumé, target job, diagnosis, and approved changes through signup so that I can confidently preview, save, and export a factually accurate tailored résumé without repeating work.

## Scope (In)

- Deterministic Apply → optimized preview navigation with explicit success and failure states.
- Recovery of the latest completed optimization after relaunch or local-state loss.
- Consistent completion state across Home, Optimized, Design, Expert, and Account.
- Shared job-input readiness rules and inline, non-technical validation.
- Client and backend presentation safety for placeholders, factual-field changes, and non-positive score deltas.
- Guest-to-auth continuity without repeated Analyze and Check Fit gates.
- Evidence-backed review cards with Accept, Edit, and Skip controls.
- Explicit save status and a verified preview/export/relaunch recovery path.
- Activation analytics centered on `optimized_preview_rendered`.
- Focused Hebrew, accessibility, and “optimize another job” polish after the core path is stable.

## Scope (Out)

- Enabling StoreKit, credits, paywalls, or pricing experiments.
- A full résumé builder or create-from-scratch experience.
- Paste-text résumé entry in the first release; treat as a separately scoped reach experiment.
- A visual redesign of the full app or a new design system.
- New Swift packages.
- Replacing the current PDF engine unless verification identifies an export-specific defect.
- Changing dark-mode-only behavior.

## Success Metrics

- 100% pass rate for the synthetic golden path: Apply → preview → export/share → relaunch → recover.
- No observed disagreement about completion state across the five tabs and Account.
- At least 90% of `optimization_completed` sessions reach `optimized_preview_rendered` in the clean production cohort once sample size is meaningful.
- Reduce signup-completed → review-viewed action count from three user confirmations to one.
- Zero raw placeholders, unexplained non-positive score deltas, or unconfirmed factual-field changes in QA fixtures.
- Export failure rate below 5% among users who reach an optimized preview, once a meaningful clean cohort exists.
- Improve signup → review-viewed conversion by at least 25% relative to the first stable baseline.

## Open Questions

1. Can the backend attach source evidence, confidence, and factual-field classification to every change group in the optimization-review response?
2. Should saved-resume creation be automatic after a successful preview, or explicit with a persistent inline choice? Recommendation: explicit but non-blocking, shown on the preview.
3. Should Design and Expert remain visible as educational locked tabs before completion, or be hidden from the first-session tab bar? Recommendation: keep visible, but replace stale checklists with truthful progress and recovery actions.
4. What minimum description rule should all surfaces share when a pasted job is used? Recommendation: one backend-owned constant exposed to iOS, with a temporary shared iOS fallback of 100 words.

## Risks

- Backend and iOS may disagree on recommendation safety unless one response contract is authoritative.
- Navigation fixes can appear correct while hidden, mounted tabs retain stale view-model state.
- A local “latest optimization” repair alone could mask backend/history inconsistencies; recovery must be tested after relaunch and account restore.
- WKWebView preview/export must be verified on physical iPhone and with Hebrew/RTL before release claims expand.
- Production funnel interpretation remains sensitive to founder/QA traffic and duplicated legacy upload semantics.
