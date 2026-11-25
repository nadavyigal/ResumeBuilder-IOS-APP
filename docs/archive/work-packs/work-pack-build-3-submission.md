# Work Pack: Resumely iOS Build Submission

> Open this file in the Resumely iOS repo. Run every step in order. Do not skip Phase 2 (device smoke) — it is the gate for archive.

**Repo:** `/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`

**Current state (as of 2026-06-12):**
- Checked out on `codex/fix-submit-package-save-package`
- 2 dirty files: `Localizable.xcstrings` (modified) + 1 untracked plan doc
- Submit Package / PDF flow code was fixed on this branch; device smoke not yet done
- Main is clean and in sync with origin

---

## Phase 1: Commit dirty files and open PR (5 min)

- [ ] Check current state
  ```bash
  git status --short --branch
  ```

- [ ] Review the localization changes
  ```bash
  git diff "ResumeBuilder IOS APP/Resources/Localizable.xcstrings"
  ```
  If the strings changes look correct (Submit Package flow strings), continue.

- [ ] Stage and commit
  ```bash
  git add "ResumeBuilder IOS APP/Resources/Localizable.xcstrings"
  git add docs/
  git commit -m "chore: commit localization updates and plan docs from submit-package session"
  git push origin codex/fix-submit-package-save-package
  ```

- [ ] Open a PR
  ```bash
  gh pr create \
    --title "Fix Submit Package: save-package flow, PDF fallback, canSubmit guard" \
    --body "$(cat <<'EOF'
  ## Summary
  - Submit Package no longer blocks on missing company/role context
  - Save Package to Me completes before marking application applied
  - PDF export falls back to local text-layer PDF when backend download fails
  - canSubmit no longer requires companyName (safe fallback copy used)
  EOF
  )" \
    --base main
  ```

## Phase 2: Device smoke — end-to-end on real iPhone (20 min)

> This is the gate. Do not archive until all 10 steps pass. If any step fails, fix it before continuing.

Install the latest build on a real iPhone (from the codex branch build or TestFlight). Open PostHog dashboard → Live Events before starting.

- [ ] Sign in with Apple (or email)
- [ ] Create a resume — paste or upload a real PDF
- [ ] Tap `Optimize Resume` — wait for results
- [ ] Tap `Improve ATS`
- [ ] Tap `Preview & Export PDF` — verify a real PDF opens (not a blank screen or error)
- [ ] Tap `Submit Package` — verify the form shows company/role or fallback text, tap `Submit`
- [ ] Tap `Save Package to Me` — verify the package appears in the Me tab
- [ ] Open the package in the Me tab → tap `Share PDF`, `Copy Cover Letter`, and `Submit at Job Link`
- [ ] In PostHog Live Events: confirm `app_launched`, `optimization_completed`, and `export_success` appear
- [ ] Screenshot the PostHog Live Events screen — this is your QA evidence

If any step fails: open a Claude Code session in this repo and fix before continuing.

## Phase 3: Merge the PR

- [ ] Merge
  ```bash
  gh pr merge --squash --delete-branch
  git checkout main
  git pull origin main
  ```

## Phase 4: Archive (Xcode — 10 min)

- [ ] Open Xcode
- [ ] Set scheme: Resumely (or ResumeBuilder), destination: `Any iOS Device (arm64)`
- [ ] `Product → Archive`
- [ ] In the Organizer: confirm build number (increment if previous build was already submitted and rejected). Confirm bundle ID matches your registered ID.
- [ ] Attach the PostHog screenshot as a note in the Organizer (or keep it accessible for the reviewer response)

## Phase 5: Upload and submit (App Store Connect — 10 min)

- [ ] In Organizer: `Distribute App → App Store Connect → Upload`
- [ ] Sign with Apple Distribution certificate
- [ ] In App Store Connect: select the new build, attach reviewer notes (Sign in with Apple is hidden via feature flag — explain the flag approach), submit for review

## Phase 6: Update progress

- [ ] Open `tasks/progress.md`
- [ ] Change `Current Phase` to: `Build submitted — Apple review pending (YYYY-MM-DD)`
- [ ] Add PostHog screenshot path as Latest QA Report
- [ ] Update `Last Validation` and `Last Updated`
  ```bash
  git add tasks/progress.md
  git commit -m "docs: update progress after Resumely build submission"
  git push origin main
  ```
- [ ] Run `./agentic-os refresh` in the Agentic OS repo

---

**Done when:** Build appears in App Store Connect as "Waiting for Review" and `tasks/progress.md` is pushed with PostHog evidence noted.
