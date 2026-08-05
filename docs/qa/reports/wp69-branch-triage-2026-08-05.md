# WP-69 Story 5 — Branch triage, 2026-08-05

Every branch the morning brief listed as stranded, with a verdict and the evidence behind it.
Nothing here was deleted; deletion is a separate, explicit step.

## Method

The brief's "13 stranded branches" was read as 13 pieces of lost work. It is not. Three
different states were collapsed into one number:

1. **Landed** — the remote branch was deleted because its PR was squash-merged. The local ref
   survives and looks unmerged to `git branch --merged`, because a squash merge produces a new
   commit with a different hash. The content is in `main`.
2. **Superseded** — the branch's content was overtaken by later work on `main`. Nothing to
   recover.
3. **Genuinely unlanded** — content exists nowhere but this branch.

A branch is only in state 3 if `main` does not contain its content. `git log main..branch`
cannot answer that after a squash merge, and `git diff main...branch` answers a different
question (what the branch added since the merge base), so it reports a delta for landed work
too. The test used here is direct: take a distinctive symbol or line the branch introduces and
look for it in `origin/main` with `git grep <symbol> origin/main`.

## Verdicts

| Branch | Last commit | Verdict | Evidence |
|---|---|---|---|
| `claude/wp63-internal-tester-person-property` | 2026-07-29 | **Landed** (#137) | `withPersonScope` (2 files), `personScopedProperties` (1), `testEveryEventSetsTheInternalTesterPersonProperty…` (1) all present in `origin/main` |
| `claude/wp63-person-scope-race` | 2026-07-29 | **Landed** (#138) | `testPersonScopeUsesThePayloadSnapshot…` present in `origin/main` |
| `pr-72-review` | 2026-06-22 | **Landed** | `previewKeywordSuggestion` (2 files) and `keywordSuggestionRow` (1) present in `origin/main` |
| `docs/ftux-audit-rescue` | 2026-07-15 | **Landed** (#96) | `docs/audits/first-time-user-journey-audit.md` exists at `origin/main` |
| `feat/localization-updates` | 2026-06-16 | **Landed** | its only commit adds `tasks/work-pack-p2-analytics-library.md`, which exists at `origin/main`. The branch name does not describe its content |
| `codex/wp46-story-10` | 2026-07-18 | **Landed** | `jobInputValidationShown` (5 files), `analysisCTATapped` (4), `optimizationApplyStarted` (3), `direct_optimize_v2` (3) all in `origin/main` |
| `codex/wp46-story-11` | 2026-07-18 | **Landed** | `UploadFailureView` present in `origin/main` (2 files) |
| `codex/wp46-story-12` | 2026-07-18 | **Landed** | `SecondJobRequest` (3 files), `requestSecondJob` (3), `completeSecondJobRequest` (2) all in `origin/main` |
| `claude/1.4.7-live-launch-check` | 2026-07-29 | **Landed** | its four commits touch only `tasks/progress.md`; a sorted line-diff against `origin/main`'s copy finds **zero** lines present on the branch and absent from `main`. The P0 it recorded (WP-64, optimizer drops all bullets) is at `tasks/progress.md:18` on `main` |
| `claude/activation-audit-corrections` | 2026-07-28 | **Landed** (#134) | `tasks/progress.md` only; superset of `claude/progress-1.4.7-submitted` and merged as #134 |
| `claude/progress-1.4.7-submitted` | 2026-07-28 | **Landed** | strict subset of the branch above (commits `54d5c35`, `164087c`) |
| `chore/release-c-1.4.3-version-bump` | 2026-07-19 | **Superseded** | bumps the project to 1.4.3 (13); the store has served 1.4.7 (17) since 2026-07-28 |
| `claude/wp65-simplify-optimized-screen` | 2026-08-01 | **In flight** — PR #136 | 1 commit (`e385d0d`), pushed. See the overlap note below |

**Nothing on that list is lost work.** Twelve of thirteen are already in `main`; the thirteenth
is a stale version bump.

## Two findings the brief did not contain

**1. PR #143 and PR #136 ship the same product change, and only one of them says so.**
`claude/record-147-live` (PR #143, titled *docs(progress): record that 1.4.7 has been live since
2026-07-28*) contains three commits: two docs, and `e385d0d fix(ui): one score in one place on
the optimized preview (WP-65)` — byte-identical to the single commit on
`claude/wp65-simplify-optimized-screen` (PR #136, *WP-65: one score in one place on the
optimized preview*). Merging #143 lands a UI change under a documentation title, and leaves #136
merged-by-accident. Land #136 first and rebase #143 onto it, or drop `e385d0d` from #143.

**2. Four PRs are already open, so most of this work is not stranded at all.**
#136 (WP-65), #139 (WP-66 S1 upload instrumentation), #141 (test-target auto-enrollment),
#143 (1.4.7 record). Plus #140 and #142 from the test-enrollment work. The brief's stranded
count was measured against `main` alone and counts anything not yet merged as lost.

## Loose files in the primary tree

Eleven uncommitted files, of three kinds:

- **Eight byte-identical Finder duplicates** (` 2`, ` 3` suffixes), verified with `cmp` against
  their committed originals: the FTUX audit and its contact sheet, the ASC readiness report
  (twice), the FTUX upgrade Figma board (twice), and the Release B initiation prompt (twice).
  These carry nothing and should be deleted.
- **Two genuinely unique reports with duplicate-style names** — the 2026-07-18 HogQL funnel
  autopsy and funnel paths. Their un-suffixed originals were never committed, so the ` 2` copy
  *was* the only copy. Rescued in this branch under the correct names.
- **One never-committed report** — `resumely-1.4.1-raw-hogql-funnel-autopsy-2026-07-25.md`, the
  definitive July 25 rerun (0 of 0 eligible picker openers; underpowered; product changes
  deferred). Rescued in this branch.

## Worktrees

Eight, of which three are the ones the brief flagged as leftovers:
`ResumeBuilder IOS APP-story-10`, `-story-11` (checkouts of the two landed `codex/wp46` branches)
and `.claude/worktrees/resumely-ios-1-4-5-prep-07f44c` (detached at `bbb3ce1`). All three are
safe to remove once the branch deletions below are made. `ResumeBuilder-IOS-1.4.7-release`
(detached at `0103705`) is the release checkout and should be kept until 1.4.8 branches.

## Deletion list — requires an explicit yes

Twelve local branches whose content is verified present in `main`, plus the superseded version
bump. Deleting these clears the stranded-work board without losing anything:

```
claude/wp63-internal-tester-person-property   claude/wp63-person-scope-race
pr-72-review                                  docs/ftux-audit-rescue
feat/localization-updates                     codex/wp46-story-10
codex/wp46-story-11                           codex/wp46-story-12
claude/1.4.7-live-launch-check                claude/activation-audit-corrections
claude/progress-1.4.7-submitted               chore/release-c-1.4.3-version-bump
```

`codex/wp46-story-10` and `-story-11` are checked out in worktrees and need
`git worktree remove` first.
