# Release B Initiation Prompt — Continuous, Evidence-Backed Journey

Use this prompt to begin the next Resumely iOS release only after Release A's distribution gate is resolved or the release owner explicitly authorizes parallel work.

> **Objective:** Deliver Release B's continuous, evidence-backed first-time journey without weakening the Release A review → Apply → optimized-preview contract.
>
> Start by reading `AGENTS.md`, `tasks/lessons.md`, `tasks/progress.md`, and `tasks/todo.md`; state the objective in one sentence. Then read the Release A/B/C plan in `docs/specs/drafts/first-time-user-journey-upgrade-brief.md`, `docs/specs/drafts/first-time-user-journey-upgrade-spec.md`, `docs/specs/drafts/first-time-user-journey-upgrade-stories.md`, and `docs/audits/first-time-user-journey-audit.md`. Audit the current branch and open PRs before editing anything. Preserve unrelated uncommitted work.
>
> **Release A context:** Release A lives on `codex/first-time-journey-release-a`. It introduced a deterministic Apply-to-preview route, one reconciled optimization state across tabs, shared job-input validation, conservative client-side recommendation safety, and preview-owned save/export/relaunch continuity. Its current ASC readiness gate is documented in `docs/qa/reports/release-a-asc-readiness-2026-07-15.md`; do not imply that an ASC upload or submission occurred.
>
> **Release B scope — implement only Stories 7–10, in order:**
>
> 1. **Guest context through authentication:** preserve the selected résumé, job input, and diagnosis through sign-in; cancelling auth returns to intact context; changed inputs invalidate dependent results; never make users repeat unchanged work or automatically start optimization after authentication.
> 2. **Merge Fit into the primary journey:** do not show a second Check Fit form for unchanged inputs. Let the user inspect/edit the target before optimization and preserve the existing diagnosis if a fit request fails.
> 3. **Evidence-backed review:** obtain and document the backend's additive recommendation-evidence metadata contract before presenting evidence as fact. The current apply contract accepts only `approvedGroupIds`; retain Accept/Skip semantics, default factual changes off, and never expose an edit action that cannot be submitted.
> 4. **Activation and failure measurement:** add only PII-safe, non-content correlation identifiers and tester properties. Fire `optimized_preview_rendered` only after actual rendered content is visible. Document the canonical PostHog funnel/query and its validation.
>
> **Decision gates:**
>
> - Do not begin Story 9 until an owner, schema, delivery plan, and fallback for the backend evidence metadata are recorded and approved.
> - Confirm whether Release B branches from the Release A merge point or is explicitly authorized to proceed in parallel.
> - Confirm the Release B version/build strategy only after Release A's version decision is made.
> - Do not submit TestFlight or App Store Connect builds without explicit current approval.
>
> **Engineering constraints:** extend `Features/V2/`; use `@Observable` and `@MainActor`; satisfy Swift 6 Sendable requirements; use `Endpoint` through `APIClient`; add no packages; keep dark mode; and never send résumé, job, email, URL, or generated-content values to analytics. Do not introduce monetization, paid acquisition, or an unrelated visual redesign.
>
> **Verification for every story:** create focused red-to-green regression coverage, run the relevant tests, build Debug and generic-device Release, smoke iPhone 17 plus the smallest available supported iPhone simulator, and identify any physical-device acceptance that must remain manual. Update `tasks/todo.md` and `tasks/progress.md`; commit, push, and open a PR only for intentional code changes. End with the exact evidence, remaining risks, and the next gated story—do not silently begin the next story.
>
> **Definition of done:** An authenticated user can retain their work through auth, use one coherent fit/diagnosis/review path, make evidence-aware Accept/Skip decisions that map exactly to backend behavior, and reach a visibly rendered optimized résumé. The funnel can prove the journey using privacy-safe events, and each state has a tested failure/retry path.
