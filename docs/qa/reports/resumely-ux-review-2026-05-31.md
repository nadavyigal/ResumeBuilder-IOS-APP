# ResumeBuilder iOS UX Review — First-Time Clarity & Activation

Date: 2026-05-31
Reviewer: Codex
Repo: `/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`

## Executive Summary

- Resumely's strongest first-time pattern is the Tailor tab's clear 3-step structure: upload resume, add job, run ATS/optimize.
- The highest launch-readiness issue is auth state clarity: the app launches unauthenticated users into the main app, while Me displays "Signed in" and "Active account" even when no email/session is visible.
- There is no dedicated first-screen state machine that explains the full path to first successful export; the user starts in task execution, not in guided activation.
- Design and Expert are accessible before they can be useful; Optimized and Expert have better empty states than Design.
- Export is functional in source but too hidden for the activation goal; it lives behind an ellipsis in Optimized and a share icon inside Preview.
- The app has several competing AI surfaces: Tailor optimize, Refine Resume, Expert modes, ATS score, and design customization. These need a clearer hierarchy for first-time users.
- Local docs and QA checklists are stale in important places, still describing Score/Track/ProfileV2 while the current app uses Tailor/Optimized/Design/Expert/Me.
- Build and tests passed after clearing extended attributes from generated DerivedData; simulator validation covered unauthenticated first launch and empty tab states, but not live authenticated optimize/export.

## Evidence Reviewed

Local memory and task files:

- `tasks/MEMORY.md` - live endpoint history, app store/distribution notes, PostHog partial work.
- `tasks/ERRORS.md` - no recorded failed approaches yet.
- `tasks/lessons.md` - key rules: V2 only, live-only runtime, no mocks, upload preflight, preview/export lessons.
- `tasks/todo.md` - current App Store screenshot task complete; backend resume library still pending.
- `tasks/session-log.md` - latest session notes, including PostHog work still needing build verification.
- `tasks/progress.md` - pre-release/TestFlight phase, active tabs, backend blockers.

Product, architecture, and QA docs:

- `docs/product/current-product-state.md` - stale sections still describe Score/Track/ProfileV2.
- `docs/architecture/current-ios-architecture.md` - stale layer map still references Score/Track/ProfileV2, but confirms API/client architecture.
- `docs/qa/ios-qa-checklist.md` - stale QA checklist still includes Score and Track sections.

Source files:

- Launch/auth: `ResumeBuilder IOS APP/ResumeBuilder_IOS_APPApp.swift`, `ContentView.swift`, `App/RootView.swift`, `App/AppState.swift`, `Features/Onboarding/OnboardingView.swift`.
- Main IA: `App/MainTabViewV2.swift`, `Core/DesignSystem/Components/ResumlyTabBar.swift`.
- Tailor/activation: `Features/Tailor/TailorView.swift`, `Features/Tailor/TailorViewModel.swift`, `Features/Score/ScoreResultView.swift`.
- Optimized/export: `Features/V2/Improve/OptimizedResumeTabView.swift`, `Features/V2/Improve/OptimizedResumeView.swift`, `ViewModels/OptimizedResumeViewModel.swift`.
- Design/preview: `Features/V2/Design/RedesignResumeView.swift`, `Features/V2/Preview/ResumePreviewWebView.swift`.
- Expert: `Features/V2/Expert/ExpertTabView.swift`, `Features/V2/Expert/ExpertModesView.swift`, `Features/V2/Expert/ExpertModesViewModel.swift`.
- Me/applications: `Features/Profile/ProfileView.swift`, `Features/Track/ApplicationDetailView.swift`.
- Runtime flags: `Core/API/RuntimeServices.swift`, `Core/API/BackendConfig.swift`.

Simulator evidence:

- XcodeBuildMCP build/run on iPhone 17 Pro Max simulator, iOS 26.5.
- First build failed at generated app CodeSign due extended attributes in `.derivedData-validation`; clearing generated DerivedData xattrs fixed it.
- `build_run_sim` succeeded on retry.
- `test_sim` initially failed at generated `.xctest` CodeSign for the same extended-attribute reason; clearing generated DerivedData xattrs fixed it.
- `test_sim` passed 55/55.
- UI snapshot after launch showed Tailor tab, not onboarding: "Tailor Resume", "Upload Resume", "Add Job", disabled "Run Free ATS Check".
- UI snapshot for Optimized empty state showed "No optimized resume yet" and "Go to Tailor".
- UI snapshot for Design empty state showed categories, style controls, "Optimize a resume to preview", and disabled "Apply Design".
- UI snapshot for Expert empty state showed "No expert analysis yet" and "Go to Tailor".
- UI snapshot for Me showed "Signed in", "Active account", "No optimized resume yet", "Tailor a resume to start tracking applications", and "Sign Out".

Git status captured before report creation:

```text
## codex/rb-aso-002-app-store-screenshots...origin/codex/rb-aso-002-app-store-screenshots [gone]
 M "ResumeBuilder IOS APP/Resources/Localizable.xcstrings"
 M tasks/MEMORY.md
 M tasks/session-log.md
?? .agent-os/distribution/
?? .agents/
?? .cursor/
?? CURSOR.md
?? tasks/ERRORS.md
```

Facts vs assumptions:

- Fact: The simulator used an unauthenticated/guest-like launch path into Tailor.
- Fact: Source shows `RootView` routes to `MainTabViewV2` after bootstrap, without checking `appState.isAuthenticated`.
- Assumption: The intended v1 launch strategy is free-first ATS activation rather than mandatory onboarding; this needs founder confirmation.
- Assumption: Live authenticated upload/optimization/export was not run because no credentials or known-good test account were provided in this review pass.

## Current UX Map

Launch:

- App launches through `ResumeBuilder_IOS_APPApp`, injects `AppState`, forces dark mode, and calls `bootstrapAndRefreshSession()`.
- `RootView` shows a spinner until `hasBootstrappedSession` is true, then always shows `MainTabViewV2`.
- `OnboardingView` exists but is not the root unauthenticated launch screen in the current source.

Onboarding / sign in:

- `OnboardingView` presents Resumely branding, "Tailor your resume to any job in 60 seconds.", Sign in with Apple, email/password fields, and sign-in/sign-up toggle.
- In current Tailor flow, onboarding appears as a sheet after a free ATS result when the user taps "Sign in to Optimize".

Resume import:

- Tailor step 1 is a PDF file importer with text-layer preflight in `TailorViewModel.cachePickedFile`.
- Saved resume reuse is disabled by runtime flag until `/api/v1/resumes` exists.

Job input:

- Tailor step 2 allows either a LinkedIn/job URL or pasted job description.
- Timeout guidance recommends pasted text when job scraping is slow or blocked.

ATS / optimization:

- If unauthenticated, Tailor runs a public ATS check and shows `ScoreResultView`.
- If authenticated, Tailor uploads resume/job, may route to review, or sets `latestOptimizationId` and switches to Optimized.

AI edits:

- Optimized has "Refine Resume" for section-level instruction.
- Expert offers multiple workflows after an optimization exists: full rewrite, quantified bullets, ATS keyword analysis, summary lab, cover letters, and screening answers.

Template/design:

- Design tab has category picker, preview area, spacing slider, accent colors, font style, apply, and undo.
- Without an optimization id, Design still shows controls but cannot preview/apply meaningful output.

Export/share PDF:

- Optimized exposes "Download PDF" inside a toolbar ellipsis menu.
- `ResumePreviewWebView` exposes a share icon that also downloads/shares PDF.
- Export requires an optimization id and an authenticated token.

After first successful export:

- No explicit post-export celebration, next-step route, recent export card, or application tracking prompt is visible in the reviewed source.
- Me shows Latest Resume and My Applications; applications can attach optimized resumes and share links once data exists.

Profile/settings/account:

- Me combines latest resume, application tracking, optional monetization sections, and account sign-out.
- In simulator, Me displayed "Signed in" and "Active account" even though no email was visible.

## Major Findings

### P0 - Auth and guest state are misleading on first launch

Problem:

Unauthenticated users appear to enter the main app as if signed in. Me shows "Signed in", "Active account", and "Sign Out" even in the simulator state where Tailor exposes the unauthenticated "Run Free ATS Check" path.

Evidence:

- `RootView` routes to `MainTabViewV2()` whenever `hasBootstrappedSession` is true, without checking `appState.isAuthenticated` (`App/RootView.swift:8-9`).
- `AppState.isAuthenticated` is simply `session != nil` (`App/AppState.swift:30-32`), but `RootView` does not use it for routing.
- `ProfileView.email` falls back to "Signed in" when `appState.session?.email` is nil (`Features/Profile/ProfileView.swift:25`), and the hero always displays "Active account" (`Features/Profile/ProfileView.swift:145-150`).
- Simulator snapshot: first launch showed Tailor with disabled "Run Free ATS Check"; Me showed "Signed in", "Active account", and "Sign Out".

User impact:

This undermines trust before the user uploads a sensitive resume. It also makes account state, privacy expectations, and App Store readiness feel unfinished.

Recommended change:

Choose one explicit launch model and make every screen agree:

- If free-first is intended, label it as guest mode, show "Guest mode" in Me, replace Sign Out with Sign In, and keep optimization/export gated.
- If account-first is intended, route unauthenticated users to onboarding before MainTabView.
- Do not display "Signed in" or "Active account" unless a real session/email exists.

Priority: P0

### P1 - First screen starts execution before explaining the full path to first export

Problem:

Tailor's 3-step layout is clear, but it begins with a file upload request and job input before showing the outcome path: score, AI edits, preview, design, export.

Evidence:

- `MainTabViewV2` defaults to `.tailor` (`App/MainTabViewV2.swift:5`).
- Tailor header says "AI rewrites your resume to beat ATS filters for any job" and immediately shows Upload Resume/Add Job/Optimize cards (`Features/Tailor/TailorView.swift:248-277`, `Features/Tailor/TailorView.swift:49-79`).
- Simulator snapshot: the first viewport showed Tailor, Upload Resume, Add Job, and disabled Run Free ATS Check; no export outcome or privacy reassurance was visible.

User impact:

First-time users may not understand what they get at the end, whether upload is safe, or why both resume and job are required. This can reduce activation before the first upload.

Recommended change:

Create Home v2 as the first screen/state machine with one primary CTA and a visible progress path: Resume -> Job -> Analysis -> Edits -> Preview -> Export.

Priority: P1

### P1 - Design exposes advanced controls before the user has a resume to design

Problem:

The Design tab is reachable before an optimization exists. It shows template categories, spacing, accent color, font style, and a disabled Apply button even though the only useful message is "Optimize a resume to preview."

Evidence:

- `RedesignResumeView` always renders category picker, preview card, style controls, and Apply CTA (`Features/V2/Design/RedesignResumeView.swift:24-48`).
- No optimization id branch only changes the preview area, not the rest of the screen (`Features/V2/Design/RedesignResumeView.swift:120-164`).
- Simulator snapshot: Design empty state showed active categories and style controls, plus disabled Apply Design.

User impact:

Users can spend attention on styling before the core resume/job/analysis work is done. It also makes the app feel more complex than necessary on first launch.

Recommended change:

For no optimization id, collapse Design into a single empty state: "Optimize a resume first", one "Go to Tailor" CTA, and optionally a tiny non-interactive template preview. Hide style controls until a resume exists.

Priority: P1

### P1 - Export is too hidden for the activation goal

Problem:

The app's activation target is first successful PDF export, but export is not a first-class CTA on Optimized. It is inside the toolbar ellipsis menu, while Preview has a separate share icon path.

Evidence:

- Optimized toolbar menu contains "Download PDF" under an ellipsis (`Features/V2/Improve/OptimizedResumeView.swift:87-131`).
- Bottom bar prioritizes Refine Resume, Send to Expert, and Open Design, not export (`Features/V2/Improve/OptimizedResumeView.swift:233-273`).
- Preview has its own share button and `downloadAndShare()` path (`Features/V2/Preview/ResumePreviewWebView.swift:67-88`, `Features/V2/Preview/ResumePreviewWebView.swift:163-186`).

User impact:

Users who reach an optimized resume may keep refining/designing instead of completing the core value moment. Hidden export lowers first-export conversion.

Recommended change:

Make "Preview & Export PDF" the primary action once analysis/optimization is complete. Keep Refine/Expert/Design as secondary actions. After export, show a success state with share, save to application, and start next job.

Priority: P1

### P1 - AI surfaces compete with each other after optimization

Problem:

The app has several AI concepts: ATS check, Optimize Resume, Refine Resume, Expert Analysis, and multiple Expert modes. The hierarchy between "Refine" and "Expert" is unclear.

Evidence:

- Tailor CTA changes between "Run Free ATS Check" and "Optimize Resume" based on auth (`Features/Tailor/TailorView.swift:506-553`).
- Optimized bottom bar has "Refine Resume", "Send to Expert", and "Open Design" (`Features/V2/Improve/OptimizedResumeView.swift:233-273`).
- Expert renders every workflow mode in one vertical list (`Features/V2/Expert/ExpertModesView.swift:51-79`).
- Expert mode tiles include "Add Expert Input", "Run", "Run Again", and "Apply" style outputs (`Features/V2/Expert/ExpertModesView.swift:181-237`).

User impact:

New users may not know whether to refine, run Expert, design, or export next. The result is action overload right after the app delivers value.

Recommended change:

Introduce a post-analysis action hierarchy:

1. Review recommended changes.
2. Export PDF.
3. Optional: improve further with Expert, Refine, or Design.

Expert should be positioned as advanced help for specific jobs/assets, not a required step before export.

Priority: P1

### P1 - Resume Library is visible in logic but disabled by backend gap

Problem:

Saved resume reuse is designed into the flow but disabled because `/api/v1/resumes` is unavailable. After upload, the save prompt is silently cleared if the runtime flag is false.

Evidence:

- `RuntimeFeatures.isResumeLibraryEnabled = false` with comment that `/api/v1/resumes` is unavailable (`Core/API/RuntimeServices.swift:3-7`).
- Tailor only shows saved resume reuse to authenticated users and disables it when the flag is false (`Features/Tailor/TailorView.swift:62-66`, `Features/Tailor/TailorView.swift:199-245`).
- Upload save prompt clears `pendingSaveResumeId` when library is disabled (`Features/Tailor/TailorView.swift:161-167`).
- `tasks/progress.md` lists `/api/v1/resumes` production 404 HTML as a blocker.

User impact:

The first-time user cannot build confidence that their uploaded resume is reusable. Returning users may have to re-upload, which slows repeat activation.

Recommended change:

Before launch, either ship the backend route and enable the library or remove/hide all saved-resume affordances and defer the feature to 1.0.1.

Priority: P1

### P1 - Accessibility labels on inactive tab buttons are weak

Problem:

Inactive icon-only tab buttons expose SF Symbol labels rather than product labels in simulator snapshots.

Evidence:

- `ResumlyTabBar` only renders text for the active tab (`Core/DesignSystem/Components/ResumlyTabBar.swift:67-77`).
- Buttons do not set explicit accessibility labels (`Core/DesignSystem/Components/ResumlyTabBar.swift:51-94`).
- Simulator snapshots showed inactive labels like `doc.richtext.fill` and `rectangle.stack.badge.person.crop`; Design appeared as "Format", Me as "Account".

User impact:

VoiceOver and accessibility review will not clearly communicate the navigation structure. This is a launch-quality issue even if the visual UI looks polished.

Recommended change:

Add explicit accessibility labels and selected-state values to every tab button: Tailor, Optimized, Design, Expert, Me.

Priority: P1

### P2 - Local docs and QA checklist are stale against the actual app

Problem:

Important Agent OS docs still describe Score, Track, and ProfileV2 even though the current source and progress notes use Tailor, Optimized, Design, Expert, and Me.

Evidence:

- `tasks/progress.md` current tab structure lists Tailor, Optimized, Design, Expert, Me.
- `docs/product/current-product-state.md` still lists Score Tab, Track Tab, and ProfileViewV2.
- `docs/architecture/current-ios-architecture.md` still maps Score and Track into `MainTabViewV2`.
- `docs/qa/ios-qa-checklist.md` still has Score Tab and Track Tab sections.

User impact:

QA and launch-readiness reviews may test the wrong screens or miss the actual activation path.

Recommended change:

Update product state, architecture map, and QA checklist after this UX review is accepted. Keep the UX review report as source evidence, then run a docs cleanup story separately.

Priority: P2

## Duplication / Confusion Matrix

| Area | Appears where | Should live where | First-time preview allowed? | Remove/move/collapse recommendation |
|---|---|---|---|---|
| Resume input | Tailor Step 1; disabled saved resume button for authenticated users; Me latest resume | Home/Tailor as the first step; Me for reuse/history | Yes, only file name and privacy copy before upload | Keep upload in Home/Tailor. Hide saved resume reuse until backend works. |
| Job description | Tailor Step 2 URL and text area; shared job URL handling in AppState | Home/Tailor job step | Yes, allow paste before auth if free ATS remains | Keep both URL and paste, but recommend paste when URL scraping risk is high. |
| ATS score | Tailor free ATS result; Optimized before/after card; Me Best ATS stat; application rows | Analysis/Optimized as source of truth; Me as summary only | Yes, but explain "free ATS" vs "optimized ATS" | Use one score model label and avoid showing score placeholders as account proof. |
| AI suggestions | Tailor optimize; Optimized Refine; Expert modes; OptimizationReviewView | Analysis results page with optional advanced improvements | Limited preview after analysis only | Make Export primary; move Expert/Refine into secondary "Improve further". |
| Template/design | Design tab; Open Design from Optimized; preview uses template/customization | Design after optimization, plus compact option inside export flow | Yes, non-interactive sample only before optimization | Collapse Design empty state; hide controls until optimization id exists. |
| Export | Optimized ellipsis; Preview share icon; application attachment/share link | Optimized and post-preview success state | No export until optimized resume exists | Promote to primary CTA: "Preview & Export PDF"; remove duplicate hidden paths or make them consistent. |
| Profile/settings | Me account, latest resume, applications, optional credits | Me for true account/settings/history only | Guest mode can preview sign-in benefits | Do not show "Signed in"/"Active account" without session; use Guest state. |

## Proposed First-Time User Flow

1. Launch into Home v2.
2. Show current state: "Create your first tailored resume PDF" with one primary CTA.
3. Step 1: Upload text-based PDF, with privacy note and scanned-PDF guidance.
4. Step 2: Paste job description or add job URL, with paste recommended for reliability.
5. Step 3: Run free ATS check if guest; show score and blocked/recommended improvements.
6. Step 4: Ask user to sign in to apply AI optimization and export.
7. Step 5: Run optimization; show loading state that names the current step.
8. Step 6: Show analysis result and optimized preview.
9. Step 7: Primary CTA is "Preview & Export PDF"; secondary CTAs are Refine, Expert, Design.
10. Step 8: After export, show success with Share PDF, Save to application, and Tailor another job.

## Proposed Information Architecture

Recommended main navigation for v1:

- Home: state-based activation surface and current resume/job progress.
- Resume: uploaded resume, latest optimized resume, preview, export, and history.
- Jobs: job descriptions and applications. This can be a Me subsection if launch scope is tight.
- Improve: Expert and refine workflows, unlocked after optimization.
- Me: real account/profile/settings, sign in/out, support/privacy, and launch-free pricing state.

If keeping the current five tabs for launch:

- Tailor: first-time workflow only.
- Optimized: preview, analysis, export, and "improve further" actions.
- Design: locked/collapsed until optimization exists.
- Expert: locked/collapsed until optimization exists, positioned as advanced.
- Me: guest/auth-correct account state, latest resume, applications.

## Proposed First Screen / Home v2

No resume:

- Title: "Create your first tailored resume PDF"
- Primary CTA: "Upload resume"
- Secondary: "See how it works"
- Visible steps: Resume, Job, Analysis, Export
- Trust copy: text-based PDFs only, private resume handling, free at launch if confirmed.

Resume uploaded but no job:

- Show uploaded file name and "Resume ready"
- Primary CTA: "Add job description"
- Secondary: "Replace resume"
- Show paste field first; URL as secondary.

Job added but no analysis:

- Show resume and job as complete
- Primary CTA: guest: "Run free ATS check"; signed-in: "Optimize resume"
- Explain what will happen next: score, AI edits, PDF preview.

Analysis complete:

- Show ATS score and top 3 issues
- Primary CTA: "Apply recommended edits"
- Secondary: "Preview original/resume"

Optimized resume ready to export:

- Show resume preview and score improvement
- Primary CTA: "Preview & Export PDF"
- Secondary: Design, Refine, Expert
- After export: success state with Share, Save to application, Tailor another job.

## Proposed Core Workflow v2

1. `Home/Tailor` owns resume upload and job input.
2. Upload preflight validates readable PDF before network call.
3. Job input allows paste or URL, but the UI recommends paste for LinkedIn reliability.
4. Guest path runs ATS only and then asks for sign-in to optimize/export.
5. Signed-in path uploads/stores resume/job, runs optimizer, and sets `AppState.latestOptimizationId`.
6. Analysis result shows score, key changes, and optimized preview.
7. User can accept/apply edits or proceed with the optimized version.
8. Export is primary and visible; design/refine/expert are secondary.
9. Export success writes recent export state and offers application tracking.
10. Me reflects real account state and stores latest resume/applications only after data exists.

## Implementation Stories

### Story 1 - Fix auth and guest-state presentation

Goal:
Make first launch and Me truthful for unauthenticated users.

User-facing change:
Guests see either onboarding or a clearly labeled Guest mode. Me no longer says "Signed in" without a session.

Files likely involved:
`App/RootView.swift`, `Features/Profile/ProfileView.swift`, `Features/Onboarding/OnboardingView.swift`.

Acceptance criteria:
- With no session, app either shows onboarding or Tailor/Home with Guest state.
- Me shows "Guest mode" and "Sign in" instead of "Signed in", "Active account", and "Sign Out".
- With a real session, Me shows email/account details and Sign Out.

QA notes:
Cold launch simulator with cleared session; sign in/out smoke; VoiceOver label check for account state.

### Story 2 - Add Home v2 activation state machine

Goal:
Guide users from install to first export with one obvious next action.

User-facing change:
First screen shows current progress and the next CTA for no resume, resume-only, job-only, analysis complete, and export-ready states.

Files likely involved:
`App/MainTabViewV2.swift`, new/updated `Features/V2/Home/HomeView.swift`, `Features/Tailor/TailorView.swift`.

Acceptance criteria:
- No resume state has one primary Upload Resume CTA.
- Each state clearly shows completed and next steps.
- Tailor remains available but no longer has to carry all first-screen education.

QA notes:
Snapshot all five first-screen states with mock/injected local state or launch arguments.

### Story 3 - Collapse locked Design and Expert states

Goal:
Remove premature controls before optimization exists.

User-facing change:
Design and Expert show concise locked empty states with "Go to Tailor" until an optimization id exists.

Files likely involved:
`Features/V2/Design/RedesignResumeView.swift`, `Features/V2/Expert/ExpertTabView.swift`.

Acceptance criteria:
- Design without optimization hides category picker, sliders, colors, font picker, Apply, and Undo.
- Expert without optimization keeps current empty state.
- Both screens route back to Tailor/Home.

QA notes:
Simulator snapshots before and after optimization; small-screen check.

### Story 4 - Promote export to the primary completion CTA

Goal:
Increase first successful export.

User-facing change:
Optimized resume screen shows "Preview & Export PDF" as the primary action once preview is available.

Files likely involved:
`Features/V2/Improve/OptimizedResumeView.swift`, `Features/V2/Preview/ResumePreviewWebView.swift`, `ViewModels/OptimizedResumeViewModel.swift`.

Acceptance criteria:
- Export is visible without opening an ellipsis menu.
- Duplicate download/share paths use the same behavior and error handling.
- Export success shows Share PDF and a next-step action.

QA notes:
Run live/test optimization where possible; verify share sheet opens and exported PDF is nonblank.

### Story 5 - Clean first-time AI hierarchy

Goal:
Reduce action overload after optimization.

User-facing change:
Optimized screen groups Refine, Expert, and Design under "Improve further" while keeping export primary.

Files likely involved:
`Features/V2/Improve/OptimizedResumeView.swift`, `Features/V2/Expert/ExpertModesView.swift`.

Acceptance criteria:
- The first visible post-optimization action is export/preview.
- Refine, Expert, and Design remain reachable but visually secondary.
- Expert modes explain which ones change the resume vs create application assets.

QA notes:
Review with a completed optimization; compare first viewport before/after.

### Story 6 - Decide Resume Library launch scope

Goal:
Remove disabled/half-visible saved-resume affordances from v1 or ship the backend blocker.

User-facing change:
Saved resumes either work end to end or are absent from the v1 UI.

Files likely involved:
`Core/API/RuntimeServices.swift`, `Features/Tailor/TailorView.swift`, backend `/api/v1/resumes`.

Acceptance criteria:
- If enabled: list/save/rename/delete/download routes return JSON and iOS reuse works.
- If deferred: no disabled saved-resume UI appears in first-time flow.

QA notes:
Live account smoke with upload, save, reuse on second job.

### Story 7 - Update launch QA docs

Goal:
Make Agent OS checks match the actual app.

User-facing change:
None directly, but QA and launch decisions become reliable.

Files likely involved:
`docs/product/current-product-state.md`, `docs/architecture/current-ios-architecture.md`, `docs/qa/ios-qa-checklist.md`.

Acceptance criteria:
- Docs list Tailor, Optimized, Design, Expert, Me.
- QA checklist covers first export, guest/auth states, and locked tab states.
- Score/Track/ProfileV2 references are removed or marked legacy.

QA notes:
Run doc review after UX roadmap decisions are accepted.

## Risks / Open Questions

- Founder decision needed: Should v1 be guest/free-first or sign-in-first?
- Founder decision needed: Is first successful export the single activation metric, or is free ATS result also an activation milestone?
- Founder decision needed: Should Design and Expert remain main tabs before the user has any optimized resume?
- Backend blocker: `/api/v1/resumes` is unavailable, so Resume Library cannot honestly launch unless backend ships first.
- Live validation gap: authenticated upload/optimization/export was not completed in this review.
- App Store risk: guest/auth mismatch and stale QA docs may cause incomplete launch validation.
- Accessibility risk: inactive tab accessibility labels are not product-readable in simulator snapshots.
- Build environment note: generated DerivedData had extended attributes that broke CodeSign until `xattr -cr .derivedData-validation` was run.

## Recommended Next Step

Run Story 1 first: fix guest/auth presentation and choose the launch model. This is the highest-trust issue and affects onboarding, Me, optimization gating, and App Store readiness.

## Analysis OS Handoff

Facts:

- The app is pre-release/TestFlight prep.
- Current source tabs are Tailor, Optimized, Design, Expert, Me.
- Root launch after bootstrap routes to `MainTabViewV2` regardless of authentication.
- Tailor supports unauthenticated free ATS and authenticated optimization.
- Optimized and Expert have useful empty states pointing back to Tailor.
- Design exposes style controls before an optimization exists.
- Export exists but is hidden under an Optimized toolbar menu and duplicated in Preview.
- Resume Library is disabled because `/api/v1/resumes` is not available.
- Me displayed "Signed in" and "Active account" in simulator without visible email.
- Build/run succeeded and tests passed 55/55 after clearing extended attributes from generated DerivedData.

Assumptions:

- The current first-launch strategy is intended to support free-first ATS, but this is not explicitly documented.
- First successful PDF export is the preferred activation metric.
- No live authenticated account was available for this review, so live optimize/export was source-reviewed and not end-to-end validated.

Opportunities:

- Make Home v2 a state machine that always answers "what do I do next?"
- Make export the primary success CTA after optimization.
- Collapse locked tabs until they are useful.
- Use Guest mode honestly to preserve trust while keeping free ATS.
- Convert Expert and Design into secondary "improve further" actions after export-ready state.
- Clean docs so QA and product state match the real app.

Risks:

- Misleading auth/account state is a trust and launch-readiness issue.
- Too many AI surfaces can delay first export.
- Design controls before resume optimization add avoidable cognitive load.
- Hidden export can reduce activation.
- Backend Resume Library gap may hurt repeat use or create dead UI.
- Stale QA docs may cause missed launch blockers.

Decisions needed:

- Guest-first vs sign-in-first launch model.
- Whether free ATS result counts as activation or only first PDF export does.
- Whether Design and Expert stay as main tabs before optimization.
- Whether Resume Library is v1 launch scope or deferred to 1.0.1.
- Whether Home v2 replaces Tailor as default first tab or wraps Tailor's first-time states.
