# Work Pack: P2 Completion — PostHog Verify + Branch Cleanup

> Open this in the Resumely iOS repo.
> PR #60 is already merged. This covers what's still undone.

**Repo:** `/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`
**Status as of 2026-06-16:**
- [x] PostHog 8 funnel events wired — PR #60 merged (branch: `claude/heuristic-grothendieck-87d926`)
- [ ] PostHog Live Events verified on simulator/device
- [ ] Branch cleanup (6 stale local branches)
- [ ] Resume Library enable — blocked on backend (see `work-pack-resume-library-backend.md` in web repo)

---

## Task 1: Verify PostHog events fire (15 min)

PR #60 is merged. Make sure the events actually appear in PostHog before Day 7 (2026-06-21).

- [ ] Pull latest main
  ```bash
  git checkout main
  git pull origin main
  ```

- [ ] Open PostHog → your Resumely project → **Activity** → **Live Events** in your browser. Keep this tab visible.

- [ ] Build and run on iPhone 17 simulator:
  ```bash
  xcodebuild -scheme "ResumeBuilder IOS APP" \
    -destination "platform=iOS Simulator,name=iPhone 17" \
    -configuration Debug build
  ```
  Then open the built app in the simulator.

- [ ] Go through the minimum flow to trigger events:
  1. Launch app → `app_launched` should appear
  2. Go to Home tab → tap Tailor → upload a PDF → `resume_uploaded`
  3. Add a job description → tap Optimize → `optimization_started` then `optimization_completed`
  4. Diagnosis screen should appear → `diagnosis_viewed`

- [ ] Confirm each event appears in PostHog Live Events within ~5 seconds of each action.

- [ ] If events do NOT appear:
  - Check `BackendConfig.swift` — confirm `POSTHOG_API_KEY` key exists and is non-empty
  - Check `Info.plist` — confirm `POSTHOG_API_KEY` is populated (should come from a build setting or xcconfig)
  - Check `AnalyticsService.swift` — confirm it reads the key and passes it to PostHog SDK init

- [ ] Screenshot the PostHog Live Events screen showing events — save to `docs/qa/posthog-live-events-2026-06-16.png`

---

## Task 2: Branch cleanup (15 min)

Current branch state (as of 2026-06-16):

| Branch | Status | Action |
|--------|--------|--------|
| `claude/gracious-curie-fcd112` | [ahead 2, behind 1] — session docs for build 4 submission | Push docs, then delete |
| `claude/heuristic-grothendieck-87d926` | [ahead 2] — PostHog analytics session docs | Push docs, then delete |
| `claude/sweet-agnesi-7d2c70` | [ahead 1, behind 1] — QA smoke test docs | Push docs, then delete |
| `codex/fix-submit-package-missing-company` | local only — "add live ats insight panel" | Delete (superseded by merged PRs) |
| `codex/fix-submit-package-save-package` | local only — build 4 prep | Delete (work done, app live) |
| `codex/resume-aha-moments` | [gone] = remote merged/deleted | Delete local |
| `feat/localization-updates` | [ahead 1] — work pack doc | Push |
| `fix/code-review-remediation` | [gone] = remote merged/deleted | Delete local |
| `feature/plan-3-storekit-paywall` | local only — future StoreKit work | Keep (Gate A gated) |
| `feature/plan-4-ambassador-flow` / `monitization` | local only — future ambassador work | Keep (Gate B gated) |

### Step 1: Push the 3 session-doc branches (preserve the docs)

```bash
git push origin claude/gracious-curie-fcd112
git push origin claude/heuristic-grothendieck-87d926
git push origin claude/sweet-agnesi-7d2c70
git push origin feat/localization-updates
```

### Step 2: Delete stale local branches

```bash
# Remote-gone branches (already merged):
git branch -d codex/resume-aha-moments
git branch -d fix/code-review-remediation

# Superseded local-only branches (work is live in merged PRs):
git branch -d codex/fix-submit-package-missing-company
git branch -d codex/fix-submit-package-save-package
```

If `-d` refuses because the branch isn't fully merged (it will for local-only branches):
```bash
git branch -D codex/fix-submit-package-missing-company
git branch -D codex/fix-submit-package-save-package
```
These are safe to force-delete — the actual code changes are already in `main` via merged PRs.

### Step 3: Delete the pushed session-doc branches from remote (optional, keeps remote clean)

After pushing them (so docs are preserved in git history), delete the remote tracking branches:
```bash
git push origin --delete claude/gracious-curie-fcd112
git push origin --delete claude/heuristic-grothendieck-87d926
git push origin --delete claude/sweet-agnesi-7d2c70
git push origin --delete feat/localization-updates
```

Then prune local tracking references:
```bash
git remote prune origin
git branch -d claude/gracious-curie-fcd112
git branch -d claude/heuristic-grothendieck-87d926
git branch -d claude/sweet-agnesi-7d2c70
git branch -d feat/localization-updates
```

### Step 4: Verify clean state

```bash
git branch -v
```
Expected remaining branches:
- `* main`
- `feature/plan-3-storekit-paywall` (keep — future)
- `feature/plan-4-ambassador-flow` (keep — future)
- `monitization` (keep — future)

---

## Task 3: Enable Resume Library (after web backend is live)

This is blocked on `work-pack-resume-library-backend.md` in the web repo. Once that route is deployed:

- [ ] Open `ResumeBuilder IOS APP/Core/API/RuntimeFeatures.swift`
- [ ] Change `isResumeLibraryEnabled = false` → `isResumeLibraryEnabled = true`
- [ ] Build + run on simulator, confirm Me tab Resume Library shows (empty list is correct for new accounts)
- [ ] Commit and push to main

---

## Completion checklist

- [ ] PostHog Live Events verified — screenshot saved to `docs/qa/`
- [ ] 6 stale branches deleted (4 code + 2 gone-remote)
- [ ] 3 session-doc branches pushed to remote before deletion
- [ ] `feature/plan-3-storekit-paywall`, `feature/plan-4-ambassador-flow`, `monitization` still present (intentional)
- [ ] Resume Library enabled in iOS after backend route deployed
- [ ] `tasks/progress.md` updated and pushed
- [ ] `./agentic-os refresh` run

---

**Manual steps still required (founder only):**

1. **P0 Phase 2**: Open `https://resumebuilder-ai.com/ats-checker` in browser, click the App Store button, confirm it resolves to `https://apps.apple.com/app/resume-ai-cv-builder/id6776752349`.
2. **P0 Phase 3**: Log into App Store Connect → paste keywords, subtitle, promotional text, description from `launch-assets/aso/`.
