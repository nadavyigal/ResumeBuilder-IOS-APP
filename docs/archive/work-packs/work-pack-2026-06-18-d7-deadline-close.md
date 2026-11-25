# Work Pack: D7 Gate A Deadline Close — 2026-06-18

> **CRITICAL: D7 Gate A analytics deadline is 2026-06-21 (3 days). Build 4 with PostHog events must be live before then.**
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to execute task-by-task.

**Repo:** `/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`

**Goal:** Sync the repo, ship build 4 to App Store, verify PostHog Gate A events fire, and clear the stranded work backlog before the 2026-06-21 D7 deadline.

**Context:**
- Resumely iOS is live on the App Store (approved 2026-06-14).
- Build 4 was submitted for App Store review on ~2026-06-11 with PR #60 PostHog events.
- main is 7 commits behind origin — pull first or everything else may conflict.
- 6 modified files and ~33 untracked files are sitting uncommitted (see Task 2).
- 3 local-only branches (claude/relaxed-northcutt-cb6240, feat/localization-updates, monitization) plus 6 agent worktrees need clearing.

---

## Task 1: Sync main with origin (5 min)

main is 7 commits behind origin. Do this before any other work.

- [ ] Confirm you are on main and there are no conflicts:
  ```bash
  cd "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP"
  git status --short --branch
  ```
  Expected: `## main...origin/main [behind 7]` with 6 modified files listed. If unrelated changes are staged, stash first.

- [ ] Pull:
  ```bash
  git pull origin main
  ```
  Expected: fast-forward, 7 commits applied, no merge conflicts (the 6 modified files are not touched by remote commits).

- [ ] Confirm clean merge:
  ```bash
  git status --short --branch
  ```
  Expected: `## main...origin/main` (no behind/ahead). Modified files still show as `M`.

---

## Task 2: Commit analytics + QA changes (10 min)

Six modified tracked files represent completed analytics work. Commit them now.

- [ ] Review the diff:
  ```bash
  git diff HEAD -- "ResumeBuilder IOS APP/App/AppState.swift" \
    "ResumeBuilder IOS APP/Core/Analytics/AnalyticsService.swift" \
    "ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift" \
    docs/qa/ios-qa-checklist.md \
    docs/qa/smoke-test-2026-06-01.md \
    tasks/work-pack-p2-completion.md
  ```

- [ ] Stage and commit:
  ```bash
  git add "ResumeBuilder IOS APP/App/AppState.swift" \
    "ResumeBuilder IOS APP/Core/Analytics/AnalyticsService.swift" \
    "ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift" \
    docs/qa/ios-qa-checklist.md \
    docs/qa/smoke-test-2026-06-01.md \
    tasks/work-pack-p2-completion.md
  git commit -m "chore: commit analytics hardening, QA updates, and work-pack progress"
  ```

---

## Task 3: Triage and commit untracked files (10 min)

~33 untracked files. Some are valuable; some are Finder-created duplicates (filenames ending in ` 2.png`, ` 2.md`, ` 2.toml`) that should be discarded.

- [ ] List all untracked:
  ```bash
  git ls-files --others --exclude-standard
  ```

- [ ] Discard Finder duplicates (files with ` 2` suffix — these are accidental copies):
  ```bash
  # Preview what would be removed
  git ls-files --others --exclude-standard | grep " 2\." | head -20
  ```
  Then for each line printed, `rm` the file. Or in bulk:
  ```bash
  git ls-files --others --exclude-standard | grep " 2\." | while read f; do rm "$f"; done
  ```

- [ ] Stage and commit the genuine untracked content (audit screenshots, PostHog audit doc, plan docs):
  ```bash
  git add audit/ \
    docs/qa/posthog-analytics-audit-2026-06-16.md \
    "docs/superpowers/plans/2026-06-11-code-review-implementation-prompt.md" \
    "docs/superpowers/plans/2026-06-11-code-review-remediation-plan 2.md" \
    "docs/superpowers/plans/2026-06-11-smoke-test-ats-submit-and-screenshot-plan 2.md"
  git add tasks/work-pack-p2-analytics-library*.md 2>/dev/null || true
  git add tasks/work-pack-build-3-submission*.md 2>/dev/null || true
  git add "dist/app-store-screenshots/"
  git status --short
  ```

- [ ] Confirm only intentional files are staged, then commit:
  ```bash
  git commit -m "docs: add audit screenshots, PostHog audit, plan docs, and screenshot assets"
  ```

- [ ] Handle `Config/Info 2.plist` separately — check if it's a duplicate of `Config/Info.plist`:
  ```bash
  diff "Config/Info 2.plist" Config/Info.plist 2>/dev/null && echo "IDENTICAL — safe to delete" || echo "DIFFERENT — review before deleting"
  ```
  If identical: `rm "Config/Info 2.plist"`

- [ ] Push:
  ```bash
  git push origin main
  ```

---

## Task 4: Build 4 — Archive, upload, and submit in App Store Connect (30-60 min, requires Xcode + physical device)

Build 4 was prepared with PR #60 PostHog events. This task archives and uploads it.

- [ ] Open Xcode:
  ```
  open "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP/ResumeBuilder IOS APP.xcodeproj"
  ```

- [ ] Set the scheme to **ResumeBuilder IOS APP** and destination to **Any iOS Device (arm64)**.

- [ ] Confirm the current version: Product > Scheme > Edit Scheme, or check Info.plist. Expected: version 1.0, build 4. If build number is not 4, increment it in the project settings: Targets > ResumeBuilder IOS APP > Build Settings > Current Project Version = 4.

- [ ] Archive: **Product > Archive**. Wait for the Organizer to open.

- [ ] In Organizer, select the new archive and click **Distribute App > App Store Connect > Upload**.

- [ ] Walk through the distribution wizard (default settings). When upload completes, App Store Connect will begin processing (~10-20 min).

- [ ] In App Store Connect, once build 4 appears in the "Builds" section for version 1.0, select it and submit for review.

- [ ] Update progress:
  ```bash
  # Add a line to tasks/progress.md
  echo "" >> tasks/progress.md
  echo "## 2026-06-18 — Build 4 submitted for App Store review" >> tasks/progress.md
  git add tasks/progress.md
  git commit -m "docs: record build 4 App Store submission 2026-06-18"
  git push origin main
  ```

---

## Task 5: Verify PostHog Gate A events fire (15 min)

Gate A requires D7 data. Verify the analytics pipeline is live before the deadline.

- [ ] Open PostHog → your Resumely iOS project → **Activity** tab → **Live Events**.

- [ ] Build and run on iPhone 17 simulator (does not require Apple auth):
  ```bash
  xcodebuild -scheme "ResumeBuilder IOS APP" \
    -destination "platform=iOS Simulator,name=iPhone 17" \
    -configuration Debug build 2>&1 | tail -5
  ```

- [ ] Launch the built app in the simulator and go through the minimum activation flow:
  1. App launch → `app_launched` should appear in PostHog Live Events
  2. Tailor tab → upload a PDF → `resume_uploaded`
  3. Add job description → tap Optimize → `optimization_started` then `optimization_completed`
  4. Diagnosis screen appears → `diagnosis_viewed`

- [ ] Screenshot the PostHog Live Events panel showing at least 3 distinct event types.

- [ ] Save the screenshot to `docs/qa/posthog-gate-a-baseline-2026-06-18.png`.

- [ ] Commit:
  ```bash
  git add docs/qa/posthog-gate-a-baseline-2026-06-18.png
  git commit -m "qa: PostHog Gate A baseline screenshot 2026-06-18"
  git push origin main
  ```

---

## Task 6: Clean up local-only branches (10 min)

Three branches exist only locally (remote deleted). Evaluate each and discard or push.

- [ ] Inspect each branch:
  ```bash
  git log --oneline claude/relaxed-northcutt-cb6240 ^main | head -10
  git log --oneline feat/localization-updates ^main | head -10
  git log --oneline monitization ^main | head -10
  ```

- [ ] For each branch: if the commits are already merged or contain only docs/session notes, delete it:
  ```bash
  git branch -D claude/relaxed-northcutt-cb6240
  git branch -D feat/localization-updates
  git branch -D monitization
  ```
  If a branch has unmerged feature code, open a PR first:
  ```bash
  git push origin <branch-name>
  gh pr create --base main --head <branch-name> --title "..." --body "..."
  ```

- [ ] Delete the merged local branch (1 from the cleanup list):
  ```bash
  git branch --merged main | grep -v '\* main' | xargs git branch -d
  ```

---

## Task 7: Remove agent worktrees (10 min)

Six agent worktrees clutter the repo. Use the Agentic OS janitor for a safe, backup-first sweep.

- [ ] Preview what would be removed:
  ```bash
  cd "/Users/nadavyigal/Documents/Projects /Agentic OS"
  ./agentic-os clean
  ```
  Review the list. It will target claude/*, codex/* worktrees only — never founder branches.

- [ ] Apply the cleanup:
  ```bash
  ./agentic-os clean --apply
  ```

- [ ] Confirm the Resumely iOS worktrees are gone:
  ```bash
  git -C "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP" worktree list
  ```
  Expected: only the main worktree remains.

---

## Done criteria
- [ ] main is in sync with origin (no behind/ahead)
- [ ] Zero uncommitted tracked files in primary working tree
- [ ] No Finder-duplicate untracked files
- [ ] Build 4 is submitted in App Store Connect
- [ ] PostHog Gate A baseline screenshot committed
- [ ] 3 local-only branches resolved (pushed or deleted)
- [ ] 6 agent worktrees removed
