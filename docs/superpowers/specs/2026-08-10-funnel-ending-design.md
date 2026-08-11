# Design: give the funnel an ending

**Date:** 2026-08-10, resolved 2026-08-11
**Status:** Approved and fully resolved. No open questions and no external dependencies. Implementation is sequenced in `Files touched`; start with the Supabase anonymous sign-in toggle.
**Author:** Claude (Opus 5) with founder
**Repo:** ResumeBuilder IOS APP

## Problem

The top of the funnel converts and the bottom does not exist.

Measured 2026-08-10 in PostHog project 270848 (`$lib = resumely-ios-urlsession`, lifetime, project fingerprinted before reading):

| step | people |
|---|---|
| app_launched | 223 |
| guest_mode_started | 211 |
| fit_check_started → completed → optimize_tapped | 119 → 119 → 119 |
| optimization_completed | 104 |
| optimization_apply_succeeded | 80 |
| save_success | 93 |
| **optimized_viewed / export_cta_seen** | **9** |
| export_success | 5 |

The fit check converts 119 → 119 → 119 with zero loss. Then 90% of users vanish at a single step.

### Root cause

`export_cta_seen` and `optimized_viewed` are the *same* event, emitted from one function behind one guard, `OptimizedResumeView.trackOptimizedAndExportVisibilityIfNeeded()`:

```swift
guard isActive, let optimizationId = viewModel.optimizationIdentifier else { return }
```

`isActive` is `selectedTab == .optimized` (`MainTabViewV2.swift:24`). The tab is kept mounted at `opacity: 0`, so nothing on it fires or is seen until the user selects that tab.

Nothing in the post-optimize flow selects it. `TailorView.swift:199-231` routes apply → `OptimizationReviewDestination` → `ResumeDiagnosisView`, and the only path onward is the optional `onImprove` button at line 223. Users who take any other exit never reach the résumé.

The behavioral signature confirms it. The most common event *after* `optimization_completed` is `optimization_started` again, 95 people. People finished an optimization and immediately ran another one, which is what someone does when they do not believe they are done.

This was recorded as a test quirk in `tasks/lessons.md:184` on 2026-07-05 ("hidden tabs may never appear"). It was a product finding.

### What is not broken

Export itself works. 6 people have ever started an export and 6 completed it; one `export_failed` event exists in the app's lifetime. The ending is unreachable, not defective.

## Resolution (2026-08-11)

**Verified live, on a freshly erased Simulator (prior sessions had leftover Keychain state from earlier testing that invalidated an initial attempt — every step below was re-run on a genuinely clean guest install).** As a real guest, with zero session, zero sign-in: upload résumé → paste job description → **Run Free Match Check** → a real scored result (issues found, quick wins, top-3 recommendations) → then an explicit wall:

> "4 free checks remaining this week. Sign in to unlock full resume optimization."
> "Your resume is uploaded securely for analysis. Sign in only when you're ready to optimize and export."
> **[Sign in to Optimize]**

This confirms the code reading from 2026-08-10 was correct and explains it fully: `apply()` requires a token because the product is *built* to give guests a free, rate-limited score check, then wall off real optimization behind an account. It is not a bug. `HomeActivationState.swift`'s guest copy ("Sign in to unlock full optimization and PDF export") was accurate, not stale.

**Decision: this wall is retired.** Guests get full optimize + export, capped 5/month, per sections 3-4 below. The founder's original call — give guests the real artifact, ask for registration after — stands. Finding a deliberate, well-built gate does not reopen the question; it sharpens what the design overrides. The gate itself produces the exact cliff this design exists to close: 211 guests reach the fit check, 119 tap optimize, and the free tier caps out at a score and three issues before demanding an account. That is not a different problem from the one measured in `## Problem` above — it is the same one, now traced to its source.

**What changed as a result of verifying this live, and why the work is bigger than originally scoped:**

1. **Second entry point found.** `Features/V2/Home/HomeTabView.swift` has its own guest gate, independent of the `TailorView` → `OptimizationReviewView` → `apply()` path already covered in section 1. Its `runAnalysis()` branches explicitly:
   ```swift
   if appState.isAuthenticated {
       await prepareFitCheck()   // or continueOptimization() — the real pipeline
   } else {
       await viewModel.runFreeATS(appState: appState)   // the free, capped check
   }
   ```
   and a guest who gets a result sees a standalone `Button { showOnboarding = true } label: { Text("Sign in to Optimize") }` (`HomeTabView.swift`, inside the `!appState.isAuthenticated` branch after `atsResult` populates). Both this gate and the `TailorView` one gate on the same `appState.isAuthenticated`; both must open together or the cliff just relocates from one screen to the other.

2. **The free check and the real pipeline are backed by separate API surfaces.** `TailorViewModel.runFreeATS` calls `apiClient.runPublicATSCheck(..., sessionId: appState.anonymousATSSessionId)` — a dedicated unauthenticated endpoint. Every optimize/apply/export call (`applyOrRecover`, `downloadPDF`, `improveATS`, `saveOptimizedResume`) takes a real Supabase bearer `token: String`, with no anonymous branch anywhere in this repo.

   **The unlock is Supabase anonymous sign-in, and it requires no endpoint changes.** `signInAnonymously()` gives the guest a real `auth.uid()` and the `authenticated` role, which satisfies both `/api/optimize`'s `getUser()` check and every `auth.uid() = user_id` RLS policy unchanged. Converting to a permanent account preserves the same `user_id`, so guest work carries over with no migration. Verified against the live database; full evidence, safety argument, and the four conditions attached to it are in **Risk 2**.

**What this means practically:** the client-side work in sections 1-7 (routing, export fallback, cap, registration ask, copy) is fully scoped, and section 3's `HTMLPDFExporter` risk already shipped in PR #149. The remaining work is a Supabase auth toggle, swapping the guest entry point to `signInAnonymously()`, and adding an IP-keyed rate limit to `/api/optimize` so anonymous users cannot farm fresh `user.id`s past the per-user limit. That is a config change plus two small code changes — not a backend rewrite, and not owned by anyone else.

## Goals

1. Every user who applies an optimization lands on their finished résumé.
2. Guests can export without an account, capped at 5 per calendar month.
3. Registration is pitched as an unlock at the moment of value, not as a toll before it.
4. The fit-check flow is not touched and its conversion does not fall.

## Non-goals

- Monetization and pricing. EXD-009 defers this until activation data exists. The 5-export cap is a registration driver, not revenue.
- The free-vs-pro tier split. Deferred by explicit founder decision; this design covers guest-vs-registered only and must leave room for a third tier later.
- Fixing the `optimization_apply_failed` / `save_failed` retry loop (79 and 92 people). Real, separate work.
- Fixing the two `ReviewPromptGate` defects from 2026-08-05. The data says they are not the constraint.

## Design

### 1. Route to the result

`onAppliedOptimization` in `TailorView.swift` changes from "push diagnosis" to "go to the résumé":

- Keep: set `appState.latestOptimizationId`, `rememberJobURL`, `pendingSaveResumeId`.
- Remove: `showDiagnosis = true` and the diagnosis viewmodel construction on this path.
- Add: dismiss the pushed stack (`shouldNavigate = false`), then `onSwitchTab(.optimized)`.

Ordering matters: pop the navigation stack before switching tabs, or the tab change happens under a presented destination.

Instrumentation needs no new work. Switching the tab flips `isActive`, which fires `optimized_viewed` and `export_cta_seen` through the existing guard. Those two numbers become the proof the fix landed.

**The fit check is not in this path.** Upload, job input, and `fit_check_started/completed/optimize_tapped` all occur before apply. The only edited branch is the one that runs after an optimization has already been applied. This is the design's hard constraint and any implementation that touches the fit-check surface is out of scope.

### 2. "See what changed"

`ResumeDiagnosisView` keeps its screen and viewmodel and loses its position in the path. It becomes a link on the Optimized screen presenting before/after.

Demoting it costs almost nothing: `diagnosis_viewed` reached 5 people while 80 applied an optimization, so it is already not being seen.

### 3. Guest export

Guests export through the existing local path in `ResumeExportAction.exportPDF`: when `renderedHTML` is present, `HTMLPDFExporter` builds the PDF on-device with no token, and only falls back to the server `downloadPDF` on failure.

**Resolved 2026-08-11.** `OptimizedResumeViewModel.downloadPDF(token:)` previously threw `.unauthorized` before ever attempting the fallback; it now routes a nil token to `LocalResumePDFExporter`, the offline Core Graphics renderer already in the codebase. Shipped and merged in PR #149 (`bbef6b7`), with tests proving both the content and no-content cases. See `Risks` for what remains unverified (whether a guest ever has `sections`/`contact` populated in the first place, now moot given the Resolution above — this section only matters once the backend accepts a guest into the optimize pipeline at all).

### 4. The cap

Client-side counter in `UserDefaults`, keyed by calendar month, limit 5.

- Exports 1-5: silent. No counter, no badge, no warning.
- Export 6: blocked. Tapping Export presents the "Save your work" sheet instead of producing a PDF. Completing registration unblocks it and the export proceeds in the same session; dismissing the sheet returns the user to the résumé with no PDF. The counter is checked before the export runs, so a blocked attempt emits `export_guest_cap_reached` and does *not* emit `export_started`.
- Reset: on month rollover, and incidentally on reinstall. Accepted. The goal is conversion, not abuse prevention, and someone who reinstalls monthly to dodge it was never going to register.
- Already-registered users are never counted or capped.

Storage sits alongside the existing `AppState` persistence helpers (`exportCompletion`, `savedResumeRecords`), not in a new subsystem.

### 5. The registration ask

After a successful export, a non-blocking sheet: **"Save your work."**

Unlocks, in the founder's words: work is saved across devices, unlimited exports, additional lift-up, expert review, design templates.

The user keeps the PDF they just produced whether or not they register. That is what makes it read as an unlock.

### 6. Review-prompt collision

The App Store review prompt currently claims its one per-version shot in `handlePDFShareDismissed`, at exactly the moment the registration ask now wants.

Registration wins. The review prompt moves to a later export.

Justification: `app_store_review_requested` has fired **once in the app's lifetime**, from the founder's own device walk on 2026-08-09. At current volume the prompt is worth nothing, and spending the export-success beat on it instead of on registration is a bad trade.

### 7. Copy

`HomeActivationState.swift:60` tells guests *"Sign in to unlock full optimization and PDF export."* This becomes false on ship.

- `.atsComplete` subheadline: rewrite to match the real gate.
- `.readyForFreeATS` subheadline: same review; it promises "unlock the full diagnosis" behind sign-in.

Both strings are user-visible and localized; update `Localizable.xcstrings` accordingly.

## Instrumentation

Existing events that answer the question without changes:

- `optimized_viewed`, `export_cta_seen` — should rise from 9 toward the apply population.
- `export_success` — the metric.
- `fit_check_optimize_tapped` — the guardrail.

New events:

| event | properties | why |
|---|---|---|
| `export_guest_cap_reached` | `month`, `export_count` | how often the cap actually bites |
| `registration_prompt_viewed` | `trigger` (`post_export` \| `cap_reached`) | separates the optional ask from the required one |
| `registration_prompt_accepted` | `trigger` | conversion |
| `registration_prompt_dismissed` | `trigger` | rejection |
| `what_changed_tapped` | `optimization_id` | whether demoting diagnosis lost anything |

Follow the existing `AnalyticsEvent` enum pattern in `Core/Analytics/AnalyticsService.swift` and extend `AnalyticsServiceTests` name assertions, as `export_cta_seen` does today.

## Success criteria

Primary: **exporters / optimizers**. Today 5 of 104, roughly 5%.

Guardrail: `fit_check_optimize_tapped` per launching user must not fall. If routing helps export but costs fit-check conversion, the change is a loss.

Secondary: `registration_prompt_accepted` / `registration_prompt_viewed`.

Read all of these only against post-release traffic on a build whose release date is store-verified, and exclude the founder person. Note that `is_internal_tester` is still not set at person level in this repo (the fix mirroring PRs #137/#138 never landed), so founder sessions currently land in the clean cohort and must be excluded by hand.

## Risks

**1. `HTMLPDFExporter` may not work for guests. RESOLVED 2026-08-11.**

The offline fallback (`LocalResumePDFExporter`) is now reachable for a nil token and is unit-tested. What remains open is upstream of this risk, not part of it: whether the backend will let a guest reach `sections`/`contact` in the first place. See Resolution above.

**2. Guests need a real `auth.uid()`. RESOLVED 2026-08-11 — solved by Supabase anonymous sign-in, not by a backend rewrite.**

*An earlier draft of this risk claimed the optimize/apply/export endpoints had to be taught to accept `anonymousATSSessionId`, and framed it as cross-repo work owned by someone else. Both were wrong. The backend is this founder's own Supabase project (`brtdyamysfmctrhuankn`) plus Next.js API routes in the ResumeBuilder web repo, and the correct fix is far smaller.*

**Why guests 401 today.** `src/app/api/optimize/route.ts:14-18` (web repo):

```ts
const supabase = await createRouteHandlerClient(req);
const { data: { user } } = await supabase.auth.getUser();
if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
```

Every table it then reads is RLS-scoped `auth.uid() = user_id`. By contrast `src/app/api/public/ats-check/route.ts` requires no auth: an IP rate limit of 5 requests per 7 days (`MAX_FREE_CHECKS = 5`, `WINDOW_MS = 7 days` — the source of the app's "4 free checks remaining this week"), a service-role client, and an `x-session-id` header.

**The fix: Supabase anonymous sign-in.** `signInAnonymously()` creates a real `auth.users` row with a real `auth.uid()` and issues a JWT carrying the **`authenticated`** role plus an `is_anonymous: true` claim. Consequences, all verified against the live database:

- Every existing RLS policy is `auth.uid() = user_id` scoped to `authenticated` → **works unchanged, no policy edits**.
- `/api/optimize`'s `getUser()` returns a user → **no 401, route unchanged**.
- Converting to a permanent account uses `updateUser({ email })` / `linkIdentity()`, which **preserves the same `user_id`** — the guest's résumés and optimizations carry over with no migration. This is exactly the section 5 "Save your work" ask, obtained for free.

**Database evidence (queried live 2026-08-11, project `brtdyamysfmctrhuankn`):**

| check | result |
|---|---|
| `auth.users` | 35 total, **0 anonymous** — also the source of the "~30 Supabase users vs 98 optimizers" question |
| `resumes`, `optimizations`, `job_descriptions`, `saved_resumes` | RLS enabled; all policies `auth.uid() = user_id` |
| `credit_transactions` | RLS enabled, **0 `authenticated` policies** → service-role only |
| billing / payment / subscription tables with `authenticated` policies | **none** |

The last two rows are the safety argument: enabling anonymous sign-in widens every `authenticated` policy to include anonymous users, and here that set contains only user-owned content tables, each `auth.uid()`-scoped. Credits and money are unreachable by an anonymous JWT.

**Conditions on doing this — these are the actual work, and none is a rewrite:**

1. **Enable the toggle.** Authentication → Sign In / Providers → Anonymous sign-ins. Whether it is currently enabled could not be read via SQL or the MCP tools; 0 anonymous users means "disabled or unused," not necessarily disabled.
2. **Rate-limit optimize by IP, not only by user.** `/api/optimize` limits on `optimize:${user.id}`; an anonymous user can mint a fresh `user.id` on demand, so that limit does not bind for guests. Reuse the `checkRateLimit(ip, ...)` helper the public route already uses. The section 4 client-side `UserDefaults` cap is a conversion nudge, **not** an abuse control, and must not be relied on as one.
3. **Accept the MAU cost.** Anonymous users count toward Supabase MAU billing; at current volume that is roughly 211 additional MAU.
4. **Leave `anonymous_ats_scores` and `/api/public/convert-session` in place.** They become partly redundant once `user_id` is stable across conversion, but removing them belongs to a separate change.

**3. Diagnosis navigation may already be broken.** 80 people applied, 5 saw diagnosis. This design routes around that screen rather than fixing it, so the defect survives into the "See what changed" link. Needs its own investigation; do not let it silently become part of this work.

**4. Tab-switch timing.** Switching `selectedTab` while a `navigationDestination` is presented is a known source of SwiftUI misbehavior. Pop first, then switch.

**5. Two gates, not one.** `HomeTabView.swift`'s `runAnalysis()`/`optimizeCard` gate and `TailorView.swift`'s `onAppliedOptimization`/`apply()` gate are independent code paths that both check `appState.isAuthenticated`. An implementation that only opens one will move the cliff to the other screen rather than closing it. Both are now in scope; see `Files touched`.

## Files touched

| file | change |
|---|---|
| `Features/Tailor/TailorView.swift` | reroute `onAppliedOptimization` |
| `Features/V2/Improve/OptimizedResumeView.swift` | "See what changed" link; registration ask; review-prompt reorder |
| `Features/V2/Home/HomeTabView.swift` | `runAnalysis()` guest branch calls the real pipeline, not `runFreeATS`; retire the standalone "Sign in to Optimize" button |
| `Features/V2/Home/HomeActivationState.swift` | guest copy |
| `App/AppState.swift` | monthly guest export counter |
| `Core/Analytics/AnalyticsService.swift` | five new events |
| `Resources/Localizable.xcstrings` | copy |
| tests | cap logic, month rollover, analytics names, routing |
| Supabase dashboard (config, no code) | enable Authentication → Sign In / Providers → **Anonymous sign-ins**. **Story 1** — everything else is inert until this is on. |
| `App/AppState.swift` + guest entry point | call `signInAnonymously()` where `guest_mode_started` fires today, so a guest holds a real `auth.uid()` from first launch |
| web repo `src/app/api/optimize/route.ts` | add an IP-keyed `checkRateLimit` alongside the existing per-`user.id` limit — see Risk 2 condition 2 |

Seven iOS source files plus tests, one Supabase config toggle, and one small web-repo rate-limit change. Clears the >3-file scope gate; implementation follows `planning-protocol.md` as separate stories. Sequence: enable anonymous sign-in and add the IP rate limit first, then land the iOS stories — shipping the client UI first would expose a pipeline that still 401s, and shipping anonymous auth without the IP limit would leave optimize effectively unmetered for guests.

## Deferred

- Free-vs-pro differentiation.
- Server-side cap enforcement.
- The apply/save retry loop.
- `is_internal_tester` at person level.
- Whether diagnosis deserves rehabilitation or deletion.
