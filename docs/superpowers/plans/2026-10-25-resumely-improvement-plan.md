# Approval, 2026-10-28

**Approved: Release 1 only.** Releases 2 and 3 are parked. They will not start
until Release 1 has shipped and a read of non-internal users shows a specific
unmet need. Arrivals are 2 to 5 a week (PostHog via Portfolio HQ, 2026-10-28),
so traffic, not scoring depth, is the current bottleneck.

Drafted in Cursor on 2026-10-25. The draft was written in the stale
`~/Documents` clone, 86 commits behind `origin/main`, and moved here
unchanged below this block. The 2026-10-28 corrections are in the tracker.

Founder decision, 2026-10-28: merge #215 (a job's score floor stays on that
job), then show "previous best" as a separate, labelled number instead of
flooring the headline (decision 2 below).

## Release 1 tracker

Release 1 is mostly already in flight. Finish these before writing new stories.

| # | Story | Workstream | Where | State, 2026-10-28 |
|---|---|---|---|---|
| 1 | Score floor stays on its job | WS4a | iOS #215 | Merged 2026-10-28 (a0764a5) |
| 2 | Server consent record | WS1 | web #203 | P1 fixed (rerunnable migration); migration needs a separate named yes to apply |
| 3 | Consent record on iOS, identity-safe queue | WS1 | iOS #217 | P1 + Sonnet P2 fixed; needs #203 merged and applied first |
| 4 | Styled PDF when the preview has not loaded | WS5 | iOS #214 | P1 fixed (lost session stops export); three CodeRabbit P2 follow-ups |
| 5 | Reject a PDF without the résumé name | WS5 | iOS #219 | Draft; name/fallback finding open |
| 6 | Account deletion removes uploaded files | WS8 | iOS #218 | Draft; deep-storage cleanup finding open |
| 7 | Show "previous best" as its own label | WS4a | not started | Next after #215; headline shows the current measured score |
| 8 | Remove ATS claims from copy and App Store screenshots | Guardrails | not started | Screenshots 7 and 8 still claim ATS; 1, 2 and 10 say "ATS score" (decision board, 2026-10-14) |

**WS0 is mostly answered.** All 21 server `export_success` events in 120 days
used the plain jsPDF renderer (iOS #214 evidence). Two checks remain:
production `PDF_SERVICE_URL`, and the four-template export check.

**Order:** 1 → 2 → 3, with 4, 5 and 6 independent of it. Then 7. Story 8 can
run at any time, and it is the one item here that helps App Store traffic.

**Not in Release 1 yet, needs its own story:** WS8 scheduled expiry
(guest checks 7 days, raw job text 30 days) and the retention matrix; WS5
idempotent debit under failure/retry.

---

# Resumely Improvement Plan: Trust, Reliable Export and Guided Applications

## Status and evidence

Revised draft for approval, 2026-10-25. This amendment changes planning only;
no product code, deployment, App Store metadata or production data has changed.

The original plan reports a read-only audit of `ResumeBuilder-IOS-APP` and
`new-ResumeBuilder-ai-` at `origin/main`, compared with:

- A: `srbhr/Resume-Matcher` (Apache-2.0).
- B: `ai-job-search-dev/ai-job-search` (MIT).

The follow-up review also inspected newer local iOS checkouts, including
main at `6dd7c32` (2026-10-22) and the payments recovery checkout at
`71f6f9f` (2026-10-24). It found existing AI consent infrastructure, an
intentional automatic-apply flow, score display floors and an existing Submit
Package flow. The original iOS checkout and some project documents are stale.
These observations establish source behavior, not proof of what is deployed.
Production renderer configuration and fresh remote heads remain unverified.

Before implementation, record fresh remote SHAs, relevant open/merged PRs,
deployed backend revision and the installed/release iOS build. Reconcile
existing work before creating replacement implementations. Reference-project
ports and license details must be checked against pinned upstream revisions.

## Goal

Help a user turn a Hebrew, English or mixed-language CV and job description
into a truthful tailored CV and a usable, verified export. Make every shown
score explainable and reproducible before investing in a broader agent flow.

## Decisions and scope

1. Preserve the calibrated Match Score weights initially. Date consistency
   starts as diagnostic feedback, with no new composite weight. Changes to
   extraction, synonyms or score semantics still require versioning and
   regression evaluation even when weights stay the same.
2. Show the current measured score. A previous best may be shown separately,
   clearly labelled; never silently substitute it for the current result.
3. Extend the existing consent sheet, identity-scoped store and API gate.
   Audit gaps rather than rebuilding consent from scratch.
4. Preserve low-friction tailoring: safe rephrasing may apply automatically
   with undo; new factual claims require evidence and explicit confirmation.
   Detailed change review is available without becoming mandatory for every
   cosmetic edit.
5. LLM work stays in the existing Vercel backend. Background jobs and APNs are
   conditional on measured latency and recovery needs, not an MVP prerequisite.
6. The template issue is a renderer-fallback hypothesis until WS0 establishes
   the production facts. A confirmed export defect moves straight into WS5.
7. Defer three tailoring levels, a hiring-manager critic and a second numeric
   fit rating. Reuse existing application-package capabilities before adding
   new endpoints or screens.

## Guardrails

- Label the Match Score an estimate. No guaranteed hiring outcomes or
  unsupported ATS claims. Extend `CopyClaimsTests.swift` for changed claims
  and verify English and Hebrew copy together. Product prices, where needed,
  use the established StoreKit flow.
- Use Hebrew, English and mixed-language fixtures wherever language affects
  behavior. Include factual provenance, retry and failure cases.
- Job text and uploaded CV content are untrusted data, never instructions.
  Text cleanup and prompt wording are supporting defenses, not a complete
  security boundary. Validate generated output and restrict tools separately.
- Any code ported from A or B carries the required license/attribution in both
  repositories and the app's Licenses surface when distributed. Preserve
  applicable notices and mark modified Apache-licensed files. Copy no fonts
  or template assets without separately verifying their licenses.
- Slice work into independently reviewable stories and draft PRs per affected
  repository. A workstream can have several PRs; do not require a single large
  PR for a multi-day workstream. Agents do not merge them.
- Branch from freshly fetched `origin/main`; preserve existing local work.
  Use additive API contracts and plan compatibility with installed clients,
  migration ordering, feature flags and rollback before enabling changes.
- Keep raw CV/job content, guard excerpts and claim evidence out of analytics
  and ordinary logs. Apply access controls and retention to derived data too.

## Releases and sequence

Workstream IDs are retained for traceability; their numerical order is not
the implementation order.

| Release | Workstreams | Deliverable and gate |
|---|---|---|
| 1: Trust and export | Baseline reconciliation; WS0; WS1; WS8; WS5; WS4a | Existing consent gaps closed; retention enforced; renderer defects fixed; paid export recovery verified; headline shows current measurement |
| 2: Truthful tailoring and scoring | WS2; WS3; WS4b; WS6 evidence summary | Evidence-backed edits; Hebrew guard coverage; versioned extraction; reproducible comparisons |
| 3: Guided applications | WS7 | Reuse working package flow; explicit applied status; optional reminders; expand only after core-flow evidence |

If WS0 confirms a production export defect, begin WS5 immediately alongside
consent/privacy work. Release 1 does not wait for the job-text guard, an LLM
critic or new application integrations. WS4a ships without an LLM extraction
rewrite. Release 2's evidence summary reuses WS4b requirements.

The original roughly 35 developer-day estimate is withdrawn as a commitment.
Re-estimate remaining stories after reconciliation and WS0, separating existing
functionality, new development, physical-device QA and release work. Approve
Release 1 first; Releases 2 and 3 are staged scope, not one implementation batch.

---

## WS0: Reconcile baseline and confirm the renderer issue

**Hypothesis.** `PDF_SERVICE_URL` may fall back to `localhost:3002`, and local
Puppeteer may lack a usable production Chromium. Designed exports may then
silently use React-PDF. Existing fallback code supports this possibility but
does not establish production configuration or actual rendered output.

**Steps.**
1. Record repository/deployment/build identities and inventory existing consent,
   tailoring confirmation, score display, export credit and Submit Package work.
2. Check production PDF service and Chromium configuration without exposing
   secret values. Confirm service reachability and authentication.
3. Export a controlled fixture with `minimal-ssr`, `card-ssr`, `sidebar-ssr`
   and `timeline-ssr`; inspect `X-Resume-Pdf-Renderer` and the actual design.
4. Trace iOS preview, backend download, on-device HTML export and local
   fallback separately. A backend header does not establish the iOS path.
5. Check relevant production logs for renderer failures using content-free
   diagnostics. Record whether the failure is reproducible and its impact.

**Exit.** A short evidence table attached to WS5: template, export path,
expected/observed renderer, visual result, revision/build and open defect.
Document which existing implementations each later story will extend.

---

## WS1: Complete AI consent and privacy coverage

**Observed source.** Newer iOS main already contains `AIConsentSheet.swift`,
`AIConsentStore.swift`, `AIConsentGate.swift`, and API/streaming integration.
The store is identity-scoped and versioned. The inspected older privacy
manifest has an empty collected-data list. Reconcile both against the actual
release source and SDK manifests before changing declarations.

**Changes.**
- Audit every AI-producing route and client path, including embeddings,
  rescans, chat, refine, expert workflows and review apply. Extend the existing
  gate rather than limiting coverage to upload/check/optimize.
- Disclose the actual provider, data sent, purpose, retention and deletion.
  Keep viewing and non-AI functionality usable when consent is declined.
- Add or complete server consent records with consent version, identity,
  timestamp and withdrawal state. Enforce consent consistently for account
  and guest sessions; a per-request boolean alone is not a durable consent
  record. Preserve the existing guest-to-account identity behavior.
- Add an accessible withdrawal action. Recheck consent before queued AI work
  starts; withdrawal prevents future processing. Explain separately how to
  delete existing data and what cannot be recalled after transmission.
- Reconcile app/SDK manifests, policy and App Store privacy labels against a
  data-flow inventory, including actual collection purposes and linkage.
  Do not mechanically declare every possible category.
- Define a compatible server/client rollout so existing installed clients
  receive an actionable consent/update response instead of unexplained failure.

**Tests.** Cover decline/dismissal, account switching, guest conversion,
withdrawal while a sheet or job is pending, repeat taps, restored sessions,
streaming and direct backend calls. Smoke-test Hebrew and English.

**Acceptance.** Covered AI processing cannot start without current consent;
decline and withdrawal stop subsequent AI calls; records and disclosures match
the implemented data flow. Backend enforcement covers the full route inventory.

Reference: Apple App Review Guidelines 5.1.1 and 5.1.2(i):
https://developer.apple.com/app-store/review/guidelines/#privacy

---

## WS8: Retention, deletion, licenses and store disclosures — Release 1

- Verify the policy and implement scheduled expiry for guest checks (the
  original audit reports 7 days) and raw job text (proposed 30 days).
  Document how saved application materials are retained intentionally and
  how users delete them; do not silently break their saved packages.
- Inventory raw files, parsed CVs, extracted requirements/source excerpts,
  claim evidence, embeddings, caches, job results, analytics and backups.
  Assign purpose, owner/scope, TTL and deletion behavior to each. Requirements
  and embeddings are not automatically anonymous or safe to retain forever.
- Enforce ownership and deletion/expiry for persistent caches before WS4b
  enables them. A text hash is a cache key, not anonymization or authorization.
- Test scheduled expiry and account deletion across active stores and
  document backup expiry and any explicitly justified retained records.
- Ship required attribution with the first release containing a port; add
  `THIRD_PARTY_LICENSES.md` and Settings → Licenses as needed.
- Complete privacy labels and policy updates with WS1, rather than waiting
  until after the agent flow.

**Acceptance.** A retention matrix and deletion tests cover the actual stores;
expired/deleted content cannot be retrieved through caches or job results;
disclosures match runtime behavior before release.

---

## WS5: PDF verification, renderer repair and paid-export recovery

**Observed source.** `PDFDownloadValidator.swift` checks the PDF header,
positive page count and non-empty extracted text. That does not establish
layout fidelity or completeness. The app also has on-device export/fallback
paths and a recent export-credit flow that must be included in validation.

**Changes.**
- Choose the renderer fix from WS0 evidence: repair/configure the existing PDF
  service, use a supported serverless Chromium deployment, or extend the
  existing on-device HTML exporter. Assess dependencies and hosting limits
  before adding infrastructure; follow repository dependency approval rules.
- Validate output against the approved resume revision: expected contact
  fields, titles, dates, skills and content survive with a usable text layer.
  Handle absent optional fields and supported date formats. Do not reject
  legitimate en-dash ranges merely because of punctuation.
- Use bidi-aware comparison without treating token presence alone as proof
  of correct Hebrew reading order. Add rendered-page inspection for clipping,
  overlap, overflow, fonts, page breaks and mixed-direction contact details.
- Test all four templates with Hebrew, English and mixed fixtures, including
  long CVs, through backend and actual iPhone export paths. Intended designed
  exports must preserve their selected design. Any emergency fallback must
  be explicit to the user, usable and independently verified.
- On verification failure, offer a recoverable retry and preserve the user's
  approved content/template. Do not share a known-broken file.
- Define idempotent export/unlock behavior: a failed attempt must not cause
  another credit debit on retry. Previously unlocked exports stay downloadable.
  Cover timeout after debit, rendering/validation failure, repeated taps,
  app relaunch and retry after network loss.

**Acceptance.** All template/language fixtures pass text and visual checks;
physical-iPhone QA covers the actual export/fallback paths; no duplicate debit
occurs during failure/retry cases; existing unlocked exports remain accessible.
Attach evidence to the Hebrew PDF checklist instead of merely ticking rows.

---

## WS4: Match Score truthfulness and reliability

### WS4a — Release 1: Correct presentation and comparison identity

**Observed source.** `FitJourney.displayedScore` floors later scores to earlier
values. `FitBaselineStore` retains the highest score under a resume/journey
key, including a comment preserving the floor across different jobs. This
can make the headline differ from the current measurement even if backend
scoring is reproducible.

- Show the authoritative measured score for the current saved resume and job.
  Remove silent historical floors from headline/current-score calculations.
- If retained, label prior best/history separately. Explain genuine decreases
  and unavailable results rather than masking them as improvement.
- Scope results/comparisons to resume content revision, guarded job identity,
  requirements snapshot and scoring version. Prevent stale responses from
  replacing a newer job, resume or account's result.
- Label review projections separately from saved-result measurements. After
  edits, invalidate or recompute the score for the resulting resume revision.

**Tests/acceptance.** A lower measured score remains visible as lower; changing
jobs cannot inherit the prior job's floor; different score versions are not
shown as a like-for-like gain; delayed responses cannot overwrite newer work.

### WS4b — Release 2: Versioned requirements and reproducible computation

**Original audit finding to reconfirm.** Requirements extraction is largely
English-oriented, and failed semantic analysis can redistribute its roughly
18% weight. That permits a different number under degraded conditions.

1. **LLM extracts, code scores.** Validate a strict requirements schema with
   required/preferred skills, years, seniority, title and language requirements.
   Each extracted requirement references supporting source text; absent facts
   remain unknown. Choose a supported model after task-specific evaluation.
2. **Persist an immutable requirements snapshot.** Record guarded-text hash,
   normalization/guard version, extraction schema, prompt/model identifiers,
   extractor version and provenance. Resume comparisons reuse the same
   snapshot. Temperature 0 and warm-cache reuse alone are not guarantees.
3. **Define cold-cache and concurrency behavior.** Atomically publish one
   validated snapshot per extraction identity; concurrent callers reuse the
   winner. A new extraction/model/version creates a new identity, not a silent
   replacement of the requirements behind a historical score.
4. **Make failures explicit.** If required extraction or embeddings fail, return
   a retryable unavailable state and retain any previous result as dated/stale.
   Do not silently swap in an extractor or redistribute weights. If a limited
   fallback is later offered, give it a distinct regime and prevent comparison
   with full scores.
5. **Cache with provenance and controls.** Include embedding model/version and
   normalized input identity, plus ownership, expiry and deletion from WS8.
6. **Hebrew synonyms.** Add reviewed contextual mappings such as צד שרת ↔
   backend and למידת מכונה ↔ machine learning. Evaluate ambiguity rather than
   assuming every translation pair is universally interchangeable.
7. **Date diagnostics.** Recognize Hebrew month names and numeric formats;
   distinguish inconsistent presentation from actual chronology errors.
   Keep feedback outside the composite pending separate calibration evidence.
8. **Version and explain.** Bump `SCORE_VERSION` for changed semantics; expose
   component evidence and tips without promising hiring outcomes.

**Tests.** Cover Hebrew prefixes, `Java` versus `JavaScript`, `ו-AWS`, synonym
ambiguity, missing titles, sparse ads, cold/warm caches, concurrent extraction,
restarts, model/version changes and forced extraction/embedding failures.
Before/after comparisons use identical requirements and scoring versions.

**Acceptance.** Identical resume revision, requirements snapshot, embedding
artifacts and scoring version yield identical scores across repeated runs.
Separately evaluate extraction accuracy on a human-annotated Hebrew/English/
mixed corpus, including cold runs. Report precision/recall and must-have versus
preferred errors; set and record the release threshold before implementation.
Never require a minimum number of invented requirements from a sparse ad.

---

## WS2: Job-text guard

**Baseline to reconfirm.** The original audit found limited pasted-text cleanup
and URL-focused bidi stripping. Inventory all consumers before implementation.

- Add one shared, versioned normalization/guard module before storage,
  extraction and scoring. Reuse it across public checks, upload, optimize,
  score/rescan and scraper output; verify the complete route inventory.
- Adapt B's `posting_guard.py` only where useful, with attribution. Remove
  hidden HTML before reducing scraped pages to plain text. Handle zero-width,
  BOM, Unicode tags and bidi controls without corrupting legitimate content.
- Hebrew rules: ordinary RLM/LRM and balanced isolates are not suspicious;
  detect overrides, unbalanced isolates and invisible characters inside words.
  Hebrew/Latin forms such as `בReact` are normal. Evaluate suspicious mixed
  Latin/Cyrillic/Greek words in context.
- Treat guard warnings as advisory. Return `job_guard: {verdict, counts,
  excerpts}` with bounded excerpts for the current UI; persist only counts
  unless a separately documented need and retention policy justify more.
- Keep job text in data fields, validate outputs and never execute embedded
  commands or fetch embedded links. An explicitly supplied job URL uses the
  established restricted fetcher, with redirect/private-network protections;
  instructions inside its content cannot authorize further browsing.

**Tests.** Include ordinary Hebrew marks, invisible/override payloads, hidden
HTML instructions, Unicode-tag payloads, legitimate flag emoji, mixed-script
lookalikes and normal technical ads such as SSH administrator roles.

**Acceptance.** Use a labelled corpus of benign Israeli ads and adversarial
fixtures. Report false positives and detection misses separately. An initial
50-ad smoke corpus is not evidence of a population false-alarm rate below 2%;
expand the held-out sample and report counts and uncertainty before making
that claim. Benign technical terminology alone should not trigger warnings.

---

## WS3: Evidence-backed tailoring

**Existing capabilities to reconcile.** The original audit reports no-fabrication,
named-tool and seniority guards, metric stripping and grouped review APIs.
Newer iOS source also has `PhraseConfirmationFlow`, `OptimizationAutoApplyService`
and `AppliedChangesSection`. Mandatory review was deliberately removed from
the happy path; do not accidentally reverse that decision.

**Changes.**
1. Return path-based changes with `{path, action, before, after, reason,
   evidence_refs, claim_type}`. Validate allowed paths, original values and
   resume revision on the server. Preserve protected identity, employer,
   title, dates, degree and institution fields from automatic changes.
2. Link factual additions to original CV evidence or explicit, persisted user
   attestations. A job requirement is never evidence that the user meets it.
3. A generic “I know AWS” confirmation permits a skills-list addition. It
   cannot create employment/project bullets, years of use, achievements or
   seniority. Those require role/project-specific evidence and confirmation
   of the exact proposed claim. There is no “skills plus two bullets” allowance.
4. Extend existing checks for Hebrew seniority words and transliterated tools;
   evaluate quantities, scope, responsibilities and outcomes as well as names.
5. Automatically apply only validated meaning-preserving edits, retain the
   original revision and offer undo. Hold new factual claims until confirmed;
   reject unsupported or protected-field changes. Detailed before/after review
   remains available. Persist which claims were actually accepted so the
   changes screen can show the applied result accurately.
6. Treat generic AI phrasing and punctuation as optional style feedback.
   “Spearheaded” or an em dash is not proof of fabrication. Do not spend a
   repair pass or block a valid result solely on a phrase blacklist hit.
7. Defer the light/keywords/full selector and hiring-manager critic until
   evidence demonstrates a user need and measured benefit.

**Tests.** Reject protected/stale paths and unsupported facts; prove a confirmed
skill cannot become invented role experience; scope attestations to user and
resume revision; preserve evidence on save/retry; test accepted/declined claims,
undo and Hebrew/mixed examples. Add at least 10 Hebrew evaluation fixtures.

**Acceptance.** Zero unsupported factual additions on the held-out evaluation
set, with human review of representative output. Every factual addition has
traceable evidence and required confirmation; every applied change is
inspectable and safe rephrasing is reversible. Ship behind a flag first.

---

## WS6: Explain requirements and unknowns; defer the second rating

Replace the proposed numeric technical/behavioral/career-direction fit model
with an evidence summary from WS4b's requirements snapshot:

- Requirement met: cite CV evidence or a scoped attestation.
- Gap or explicit mismatch: cite the requirement and explain the missing or
  contradictory evidence without overstating what the CV proves.
- Unknown: ask only for information needed to resolve the requirement.

Language proficiency, location/relocation and clearance remain unknown unless
supported. A Hebrew-language CV does not prove native proficiency. Keep
advice explainable next to the existing Match Score; avoid another percentage,
behavioral-fit score or definitive “do not apply” recommendation.

**Acceptance.** Sparse ads and missing profile facts produce honest unknowns;
every classification has supporting evidence; Hebrew native-language wording
is extracted correctly without assuming the candidate satisfies it.

A separate “Should I apply” model and career profile onboarding are deferred
until there is a clear user need and a defined evaluation method.

---

## WS7: Guided application flow — conditional Release 3

First map and reuse existing Submit Package, cover-letter, application storage,
share-sheet and “Add only if true” capabilities. Build the missing connections
instead of duplicating them.

**Flow.** Paste job text or a supported URL → guarded requirements and current
Match Score → evidence-backed tailoring with confirmation only where needed →
verified PDF and optional reviewed supporting drafts → share sheet → explicit
user action marking the application submitted → optional follow-up reminder.

**Slices, each independently reviewable.**
1. Connect the existing flow and preserve the exact approved/submitted material
   revision. Share-sheet dismissal or an apply-link click is not proof of submission.
2. Implement real applied status and timestamp, distinguishing draft, shared/
   clicked and user-confirmed applied. Permit corrections and stopping reminders.
3. Add optional local reminders, initially at day 10, at most two and inactive
   after day 60. Ask notification permission in context. Denial must not block
   the core flow. Follow-up drafts use submitted materials, remain reviewable
   and are never sent automatically.
4. Add Greenhouse/Comeet ingestion only after verifying supported public formats
   and access requirements; keep pasted text as a fallback.
5. Add durable background jobs only if measured duration/interruption failures
   justify them. Define idempotency, bounded retries, cancellation, job ownership,
   status recovery/polling and cost limits first. APNs may notify availability;
   delivery or notification permission must not be required to recover results.

**Entry gate.** Releases 1 and 2 have passed their quality gates. A documented
read of non-internal users shows reliable core completion and a specific unmet
need for the proposed slice. Record cohort, baseline and expansion decision;
small samples remain inconclusive rather than being treated as validation.

Out of scope: auto-apply, automatic messaging, proactive job search, company
research, email sync, expanded LinkedIn scraping and the deferred critic/rating.

---

## Cost, latency and operational budget

The original $0.08–0.15 expanded-flow estimate included now-deferred critic and
fit-label calls and is not the budget for this revised scope. Recalculate using
verified current pricing and observed token usage before enabling new calls.

Record per-stage calls/tokens, retries, cache hits, median/p95 latency and
cost per completed verified export, plus rendering/storage/job costs. Set
per-job retry/time/token limits. Report measurements without raw user content.
Choose model identifiers from supported current options after evaluation;
do not lock the plan to a historical model solely because it was in a reference.

## Success metrics and release evidence

### Technical and trust gates

- Headline score equals the current authoritative measurement; no silent floor.
- Identical scoring artifacts/version yield identical scores: 100% on fixtures.
- Extraction quality meets a predeclared annotated-corpus threshold; report
  results separately by Hebrew, English and mixed-language cohorts.
- Unsupported factual additions in held-out tailoring eval: 0.
- Intended designed exports preserve the selected template across tested paths.
- PDF key-field survival and text/visual QA pass for all language fixtures.
- Export failure/retry tests cause no duplicate debit and preserve unlocked access.
- AI processing without current consent: 0 in the audited route/test matrix.
- Retention/deletion and cache ownership tests pass before persistent caching.
- Guard reports include observed false positives/misses and sample size;
  do not claim a sub-2% population rate from 50 ads.

### Product outcomes

- Primary: proportion of eligible real-user journeys reaching a verified export
  within a predeclared window after the first successful resume/job input.
- Supporting: time to first verified export, export failure/retry recovery,
  abandonment at consent/claim confirmation, useful-change acceptance/undo,
  and return to tailor for another job within a defined follow-up window.
- Separate existing unlock redownloads from new exports; exclude founder, QA,
  bots, emulator and sideload test activity under the established measurement
  contract. Segment by language, app build and export path where samples allow.
- Instrument meaningful boundaries: accepted input, current score available,
  claims resolved, export validation passed, share initiated and user-confirmed
  applied. A share event is not a submitted application.

Capture the baseline, event definitions, observation window and target before
rollout; report denominators and uncertainty. Do not infer a product lift from
technical test passes or internal Sandbox purchases.

## Open decisions before the affected story starts

- WS0 evidence and the corresponding renderer/dependency choice.
- Remaining consent/server enforcement gaps and compatible rollout sequence.
- Retention for saved packages, derived data and backups, reconciled with policy.
- Extraction evaluation threshold and corpus ownership; cache/version identity.
- Per-story estimates after existing work is reconciled; release owner and QA scope.
- Cleanup of audit candidates (`src/lib/ats/lift 2.ts`,
  `src/lib/ats/extraction-quality 2.ts`, constants routes and unsupported
  “ATS score: 98” copy) after checking references. Fix live misleading claims
  in the foundation release; keep unrelated dead-code cleanup separate.

Approval of this amended document is not approval to implement all three
releases, merge PRs, add dependencies, deploy or change store metadata. Present
Release 1 as small concrete stories first, following repository instructions.
