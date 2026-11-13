# Work Pack: Resumely P2 — PostHog Analytics + Resume Library

> Open this in the Resumely iOS repo.
> Task 1 (PostHog) runs here. Task 2 (Resume Library backend) runs in the web repo.
> **Deadline: before Day 7 (2026-06-21) — Gate A (paywall) requires D7 data.**

**Repos:**
- iOS: `/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`
- Web: `/Users/nadavyigal/Documents/Projects /ResumeBuilder/new-ResumeBuilder-ai-`

**Context:** App is live as of 2026-06-14. Zero analytics are firing — the iOS app has no PostHog SDK and no events. Without D7 activation data, Gate A (Plan 3 paywall) cannot open on schedule (2026-06-21). The Resume Library remains disabled due to a backend 404 on `/api/v1/resumes`.

---

## Task 1: PostHog iOS SDK Integration (iOS repo — 1-2 days)

### Step 1: Add PostHog SDK

- [ ] Check if PostHog is already in the project
  ```bash
  grep -r "PostHog\|posthog" "ResumeBuilder IOS APP/ResumeBuilder_IOS_APP.xcodeproj/project.pbxproj" | head -5
  grep -r "PostHog\|posthog" "ResumeBuilder IOS APP/" --include="*.swift" -l | head -5
  ```

- [ ] If not present, add via Swift Package Manager in Xcode:
  - Package URL: `https://github.com/PostHog/posthog-ios`
  - Version: Up to Next Major from `3.0.0`
  - Target: `ResumeBuilder IOS APP`
  - Ask before running — confirm with founder before adding the dependency.

### Step 2: Initialize PostHog at app launch

- [ ] Read `ResumeBuilder IOS APP/ResumeBuilderApp.swift` (or equivalent `@main` entry point)
- [ ] Add PostHog initialization with the project API key from environment/config:

```swift
import PostHog

// In App.init() or application(_:didFinishLaunchingWithOptions:)
let config = PostHogConfig(apiKey: "<POSTHOG_API_KEY>", host: "https://eu.i.posthog.com")
config.captureApplicationLifecycleEvents = true
PostHogSDK.shared.setup(config)
```

> The PostHog API key must come from a config file or build setting, NOT hardcoded. Check if `Config.swift` or `BackendConfig.swift` exists and add `posthogApiKey` there. If no config mechanism exists, ask founder before creating one.

### Step 3: Identify the user on sign-in

- [ ] Find where auth state changes (look for `supabase.auth.onAuthStateChange` or `AuthManager`)
- [ ] Add user identification after successful sign-in:

```swift
// After successful sign-in, where you have the user ID
if let userId = session.user.id.uuidString {
    PostHogSDK.shared.identify(userId, userProperties: [
        "email": session.user.email ?? "",
        "created_at": session.user.createdAt.ISO8601Format()
    ])
}

// On sign-out
PostHogSDK.shared.reset()
```

### Step 4: Instrument core events

Track these 8 events minimum — they cover the main funnel and give D7 activation signal:

| Event | Where to add | Properties |
|-------|-------------|------------|
| `app_launched` | App init / `applicationDidBecomeActive` | none |
| `resume_uploaded` | After successful `/api/upload-resume` response | `file_type: "pdf"\|"docx"` |
| `optimize_started` | Before calling optimize endpoint | `has_job_description: bool` |
| `optimize_completed` | On successful optimization response | `optimization_id: String, match_score: Int` |
| `diagnosis_viewed` | When DiagnosisView appears | `match_score: Int` |
| `ats_improve_tapped` | ATS Improve button tap | `current_score: Int` |
| `export_pdf_tapped` | Export PDF button tap | `optimization_id: String` |
| `submit_package_saved` | After Save Package to Me completes | `has_cover_letter: bool` |

For each event:
```swift
PostHogSDK.shared.capture("<event_name>", properties: ["key": value])
```

- [ ] Find `TailorViewModel.swift` — add `optimize_started` and `optimize_completed`
- [ ] Find `DiagnosisView.swift` or equivalent — add `diagnosis_viewed`
- [ ] Find the export PDF action — add `export_pdf_tapped`
- [ ] Find `SubmitPackageViewModel.swift` or equivalent — add `submit_package_saved`
- [ ] Find `AppDelegate` or `SceneDelegate` — add `app_launched`

### Step 5: Build and verify events fire

- [ ] Build on iPhone 17 simulator:
  ```
  xcodebuild -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 17" build
  ```
- [ ] Open PostHog → Live Events view (in browser)
- [ ] Run app in simulator, go through the optimize flow
- [ ] Confirm events appear in Live Events within ~5 seconds

### Step 6: PR + merge

- [ ] Run full test suite
  ```bash
  xcodebuild test -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 17" | tail -20
  ```
  Expected: 83+ tests pass, 0 failures.

- [ ] Create PR to merge analytics into main
  ```bash
  git push origin <branch-name>
  gh pr create --title "feat(analytics): PostHog SDK integration — 8 core funnel events" \
    --body "$(cat <<'EOF'
  ## Summary
  - PostHog iOS SDK added via SPM
  - User identity set on sign-in, reset on sign-out
  - 8 core funnel events: app_launched, resume_uploaded, optimize_started, optimize_completed, diagnosis_viewed, ats_improve_tapped, export_pdf_tapped, submit_package_saved
  - Verified in PostHog Live Events

  ## Evidence
  [Attach PostHog Live Events screenshot]
  EOF
  )"
  ```

- [ ] Merge to main after review
- [ ] Update `tasks/progress.md` — add PostHog integration as last completed story

---

## Task 2: Fix `/api/v1/resumes` Backend Route (web repo — separate session)

> Open a Claude Code session in the web repo for this task.
> **Repo:** `/Users/nadavyigal/Documents/Projects /ResumeBuilder/new-ResumeBuilder-ai-`

The iOS app calls `GET /api/v1/resumes` to load the user's Resume Library but the endpoint returns a 404. The iOS app gracefully shows "Resume Library unavailable" (`RuntimeFeatures.isResumeLibraryEnabled = false`). Once the backend route is live, set `isResumeLibraryEnabled = true` in iOS.

- [ ] **In the web repo:** Find if the route exists
  ```bash
  find src/app/api/v1/resumes -name "*.ts" 2>/dev/null
  ls src/app/api/v1/ 2>/dev/null
  ```

- [ ] **If missing:** Create `src/app/api/v1/resumes/route.ts` that returns the user's saved resumes from Supabase. Schema reference: check `supabase/migrations/` for a `resumes` or `optimizations` table that stores completed optimization results per user.

- [ ] **Verify the route returns the expected shape** that the iOS `ResumeLibraryService` expects. Check:
  ```bash
  grep -r "ResumeLibraryService\|api/v1/resumes" "ResumeBuilder IOS APP/" --include="*.swift" | head -10
  ```

- [ ] **Once route is deployed:** In iOS, set:
  ```swift
  // RuntimeFeatures.swift
  static let isResumeLibraryEnabled = true
  ```

- [ ] Deploy + smoke test from iOS — confirm the Me tab Resume Library section shows saved resumes

---

## Cleanup: Stranded work in iOS repo (15 min)

Before or after the above tasks, clean up the stranded state flagged by Agentic OS:

- [ ] List open worktrees
  ```bash
  git worktree list
  ```

- [ ] For each worktree on branches that are merged or superseded:
  ```bash
  git worktree remove .claude/worktrees/<name>
  ```
  Branches with unpushed commits to evaluate: `claude/gracious-curie-fcd112` (2 commits), `claude/sweet-agnesi-7d2c70` (1 commit).

- [ ] Check uncommitted files in primary tree
  ```bash
  git status --short
  ```
  Commit or discard the 4 uncommitted files.

- [ ] Delete merged local branches
  ```bash
  git branch --merged main | grep -v "^\* main" | xargs git branch -d
  ```

---

**Done when:**
- PostHog Live Events shows core funnel events firing from a real device or simulator run
- PR merged to main with analytics wired
- `/api/v1/resumes` returns user data (not 404) — Resume Library re-enabled in iOS
- `tasks/progress.md` updated and pushed in both repos
- Run `./agentic-os refresh` to sync status
