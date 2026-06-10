# App Store Submission — WP3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get Resumely iOS v1.0 submitted to App Store review — covering pre-archive audit, device smoke, Release Archive, ASC listing, and submission.

**Architecture:** WP1 (PostHog analytics fix) and WP2 (post-optimization upgrade) are complete and merged to `main`. The Debug device binary is built and signed at `/var/tmp/resumebuilder-device-derived/`. This plan completes the physical smoke, then produces the Release Archive required for App Store Connect upload. All upload and listing steps go through the Xcode Organizer manual path (no Fastlane, no .p8 ASC key).

**Tech Stack:** Xcode 15+, Swift 5.9, SwiftUI, Supabase auth, PostHog analytics, App Store Connect (manual portal), `Secrets.xcconfig` for sensitive keys.

---

## Pre-conditions (verify before starting)

- `Secrets.xcconfig` exists at repo root with a real `POSTHOG_API_KEY = phc_...` value (not the template placeholder)
- Apple Distribution certificate is in your Mac keychain (used during WP1 device build — confirmed present)
- iPhone 13 (UDID `00008110-00192DDA2143801E`) is charged and unlocked
- You have an authenticated Resumely test account (onboarded, active plan, at least one completed optimization)

---

## Task 1: Pre-archive production audit

**Goal:** Confirm no debug/mock state can reach the Release build before archiving.

**Files to read:**
- `ResumeBuilder IOS APP/Core/API/RuntimeServices.swift`
- `ResumeBuilder IOS APP/Core/API/BackendConfig.swift`
- `Secrets.xcconfig`

- [ ] **Step 1: Verify RuntimeFeatures flags are production-safe**

Run in the repo root:
```bash
grep -n "isResumeLibraryEnabled\|isMonetizationEnabled" \
  "ResumeBuilder IOS APP/Core/API/RuntimeServices.swift" \
  "ResumeBuilder IOS APP/Core/API/BackendConfig.swift"
```
Expected output:
```
RuntimeServices.swift:    static let isResumeLibraryEnabled = false
BackendConfig.swift:    static let isMonetizationEnabled = false
```
Both `false` is correct for v1.0 — Resume Library backend not live, monetization not wired. No change needed.

- [ ] **Step 2: Confirm no mock service injection reaches the Release app entry point**

```bash
grep -rn "useMockServices\|useMockLibraryService\|useMockDesignService\|MockResume" \
  "ResumeBuilder IOS APP/App/" \
  "ResumeBuilder IOS APP/Features/"
```
Expected: zero results. Mock types are test/preview-only. If any result appears outside `#if DEBUG` or a test file, stop and fix before archiving.

- [ ] **Step 3: Verify Secrets.xcconfig has a real PostHog key**

```bash
grep "POSTHOG_API_KEY" Secrets.xcconfig
```
Expected: `POSTHOG_API_KEY = phc_` followed by a real key (not `phc_your_key_here`). If it shows the placeholder, open `Secrets.xcconfig` and paste the real key from PostHog → Project Settings → Project API Key.

- [ ] **Step 4: Confirm the Run Script build phase will fire for Release**

In Xcode: select the `ResumeBuilder IOS APP` target → Build Phases. Confirm the `Inject PostHog Keys` Run Script phase is present and **not** checked as "Run script only when installing". It must run for Archive builds too.

- [ ] **Step 5: Spot-check the 20 print() calls for sensitive data**

```bash
grep -rn "print(" "ResumeBuilder IOS APP/" \
  --include="*.swift" \
  | grep -v "/Tests/" \
  | grep -v "// " \
  | head -25
```
Scan the output. Print calls that log optimization IDs, user emails, or auth tokens should be wrapped in `#if DEBUG`. If any appear sensitive and are unconditional, wrap them now:
```swift
// Before
print("user email: \(email)")

// After
#if DEBUG
print("user email: \(email)")
#endif
```
Run `xcodebuild build -scheme "ResumeBuilder IOS APP" -destination "generic/platform=iOS Simulator" -quiet` to confirm the app still builds after any wrapping.

- [ ] **Step 6: Commit the audit result (even if no code changed)**

```bash
git add -A
git commit -m "chore(release): pre-archive production audit — flags verified, mock leak clean"
```
If no files changed, skip the commit. The audit itself is the evidence.

---

## Task 2: Install the WP1 device build and run smoke

**Goal:** Confirm the already-signed Debug device binary works on the physical iPhone 13 before spending time on the Release Archive.

> This task is a founder manual action. Claude cannot unlock a device or interact with the running app. Follow each step exactly and check the box when done.

- [ ] **Step 1: Unlock the iPhone 13 and connect via USB**

Plug in the iPhone 13 (UDID `00008110-00192DDA2143801E`) and unlock it. Trust the Mac if prompted.

- [ ] **Step 2: Install the WP1 device build**

Option A — command line:
```bash
xcrun devicectl device install app \
  --device 00008110-00192DDA2143801E \
  "/var/tmp/resumebuilder-device-derived/Build/Products/Debug-iphoneos/ResumeBuilder IOS APP.app"
```
Option B — Xcode: open Xcode, select iPhone 13 as destination, Product → Run. This rebuilds and installs.

Expected: app launches on device, Home screen renders (dark background, Tailor tab active).

- [ ] **Step 3: Open PostHog Live Events in your browser**

Go to https://us.posthog.com → your Resumely project → Activity → Live Events. Keep this tab visible while you smoke the app.

- [ ] **Step 4: Run the core smoke sequence on device**

Execute in order. Check each box only when the step passes with no error state:

- [ ] Sign in with your test account (onboarded, active plan)
- [ ] Upload a real text PDF resume (Tailor tab → tap upload area)
- [ ] Paste a real job description, tap Optimize
- [ ] Wait for optimization to complete — Optimized tab shows sections (not spinner)
- [ ] Verify scanning animation appears and disappears cleanly during optimize wait
- [ ] Open Optimized tab — preview renders (resume HTML visible, not blank)
- [ ] Tap "Edit" on one section — focused section editor sheet opens
- [ ] Make a small edit, tap Save — section body updates, ATS score refreshes
- [ ] Check ATS panel shows a score and any blockers
- [ ] Open Design tab — template grid loads
- [ ] Tap a template and Apply — Optimized preview updates to reflect the applied design
- [ ] Open Expert tab — at least one workflow card visible
- [ ] Run one Expert workflow (e.g. Summary options) — result renders
- [ ] Tap Apply to Resume — sections refresh in Optimized tab
- [ ] Open Me tab — application rows visible (or empty state if no prior applications)
- [ ] Tap Submit Package on an optimization — package hub actions appear
- [ ] Tap Export PDF — PDF renders and share sheet appears
- [ ] Confirm PDF looks correct (styled resume, not blank or garbled)

- [ ] **Step 5: Verify PostHog Live Events**

In the PostHog Live Events tab, confirm you see at minimum:
- `app_launched`
- `optimization_completed`
- `export_success`

Take a screenshot of the Live Events panel showing these events. Save it to your desktop for App Store review evidence.

- [ ] **Step 6: Note any failures**

If any step in Step 4 surfaces an error, note it here before proceeding. Backend errors (e.g. Resume Library 404) are expected and not blocking. UI errors (blank screens, crashes) must be fixed before archiving.

---

## Task 3: Capture App Store screenshots using the built-in screenshot mode

**Goal:** Generate the 5 App Store screenshot slots using the rb-aso-002 launch argument mode baked into the app.

The app has a marketing screenshot mode activated by launch arguments. No Canva/Figma needed for the base captures — overlay copy is added after.

- [ ] **Step 1: Verify screenshot mode is present**

```bash
grep -n "marketing-screenshot\|screenshot-slot" \
  "ResumeBuilder IOS APP/App/RootView.swift" \
  "ResumeBuilder IOS APP/App/AppDelegate.swift" \
  "ResumeBuilder IOS APP/App/ResumeBuilderApp.swift" 2>/dev/null | head -10
```
If no results, search more broadly:
```bash
grep -rn "marketing-screenshot" "ResumeBuilder IOS APP/" --include="*.swift" | head -5
```
Note the file containing the screenshot mode entry point.

- [ ] **Step 2: Launch screenshot mode in the simulator for each slot**

Run for each slot 1–5. Use the iPhone 15 Pro Max simulator (6.7-inch, 1290 x 2796) for App Store compliance:
```bash
# First: find or boot the correct simulator
xcrun simctl list devices | grep "iPhone 15 Pro Max"

# Boot it if needed
xcrun simctl boot "<device-udid>"

# Build and launch with screenshot mode for slot 1
xcodebuild build \
  -scheme "ResumeBuilder IOS APP" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro Max" \
  -configuration Debug \
  DEVELOPMENT_TEAM=<your-team-id> \
  -quiet

xcrun simctl launch <device-udid> \
  com.yourcompany.resumelybuilderai \
  --marketing-screenshot --screenshot-slot 1

# Take the screenshot
xcrun simctl io <device-udid> screenshot ~/Desktop/resumely-screenshot-slot-1.png
```
Repeat for slots 2–5.

> If the launch argument mode does not work or produces an empty screen, fall back to manually navigating to each screen and taking a simulator screenshot via `xcrun simctl io booted screenshot ~/Desktop/slot-N.png`.

- [ ] **Step 3: Review the 5 screenshots**

Open Finder → Desktop. Confirm all 5 screenshots show the intended screens:
- Slot 1: Onboarding / value prop screen
- Slot 2: Tailor tab (PDF upload + optimize)
- Slot 3: Optimized tab (resume sections + score)
- Slot 4: Design tab (template grid)
- Slot 5: Me tab / application package hub

If a screenshot shows the wrong screen, re-run that slot's `simctl launch` and `simctl io screenshot`.

- [ ] **Step 4: Add caption overlays**

The A-variant overlay copy was approved on 2026-05-27 and lives at:
`/Users/nadavyigal/Documents/Projects /IOS RunSmart light /IOS RunSmart app/.agent-os/distribution/screenshot-overlay-copy.md`
(global distribution OS — same copy approved for Resumely)

Open each screenshot in Preview or your image editor and add the approved caption text as a bottom-third overlay. Export as PNG at original resolution.

---

## Task 4: Build the Release Archive

**Goal:** Produce an App Store Distribution `.xcarchive` using the Release configuration and the Apple Distribution certificate already in your keychain.

> This task requires Xcode GUI. It cannot be fully scripted without an ASC API key.

- [ ] **Step 1: Clean derived data to avoid stale artifacts**

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/ResumeBuilder*
```

- [ ] **Step 2: Confirm Secrets.xcconfig is present and correct**

```bash
grep "POSTHOG_API_KEY" "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP/Secrets.xcconfig"
```
Must show a real key starting with `phc_`. Do not archive without this.

- [ ] **Step 3: Archive in Xcode**

1. Open Xcode: `open "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP/ResumeBuilder IOS APP.xcodeproj"`
2. Set destination to **Any iOS Device (arm64)** (not a simulator)
3. Menu: **Product → Archive**
4. Wait for the archive to complete. The Organizer window opens automatically when done.
5. Confirm the archive appears in Organizer → Archives tab with today's date and a green checkmark.

- [ ] **Step 4: Validate the archive before uploading**

In Organizer: select the archive → **Distribute App** → **App Store Connect** → **Validate App** (not Upload, just Validate first).

Expected: validation completes with no errors. Common warnings (missing purpose strings, etc.) are shown here — fix any errors before uploading.

If validation surfaces a **missing Info.plist key** error: the Run Script phase may not have fired during Archive. Check the build log in Xcode (Report navigator) for the `Inject PostHog Keys` phase output.

---

## Task 5: Upload to App Store Connect

**Goal:** Upload the validated archive to ASC so a build is available for the listing.

- [ ] **Step 1: Upload via Xcode Organizer**

1. In Organizer: select the archive → **Distribute App**
2. Select **App Store Connect**
3. Select **Upload** (not Export)
4. Leave all checkboxes at defaults (bitcode, symbols, managed signing)
5. Click Next through the signing steps — Xcode will use the Apple Distribution cert already in keychain
6. Click **Upload**
7. Wait for upload to complete. Takes 2–10 minutes depending on build size.

- [ ] **Step 2: Confirm the build appears in ASC**

Go to https://appstoreconnect.apple.com → your Resumely app → TestFlight tab. The new build will appear as "Processing" for 5–15 minutes, then become available. You do not need to wait before continuing to Task 6.

---

## Task 6: Finalize the App Store listing in ASC

**Goal:** Complete every required metadata field in App Store Connect before submitting.

- [ ] **Step 1: Open the Resumely iOS listing in ASC**

https://appstoreconnect.apple.com → My Apps → Resumely iOS → App Store → 1.0 Prepare for Submission

- [ ] **Step 2: Upload screenshots**

For each of the 5 required screenshot slots (6.7-inch display required, others optional):
- Drag the PNG from `~/Desktop/resumely-screenshot-slot-N.png` into the corresponding slot
- Confirm ordering: slot 1 first, slot 5 last

- [ ] **Step 3: Verify text metadata**

Confirm these fields are filled (descriptions were drafted 2026-05-27):

| Field | Source |
|---|---|
| App Name | Resumely |
| Subtitle | AI Resume Optimizer |
| Description | `docs/agent-os/distribution/app-store-program.md` or `distribution-os/` draft |
| Keywords | From `app-store-program.md` keyword list |
| Support URL | https://www.resumelybuilderai.com/support |
| Marketing URL | https://www.resumelybuilderai.com |

- [ ] **Step 4: Set demo account credentials**

In "App Review Information → Demo Account":
- Username: your test account email (onboarded, active plan, ≥1 completed optimization)
- Password: test account password
- Notes to reviewer: "Use the Tailor tab to upload a PDF resume, paste a job description, and tap Optimize. The app requires a real PDF upload to demonstrate core features."

- [ ] **Step 5: Complete the privacy questionnaire**

App Privacy → Data Collection: confirm these answers match the PostHog + Supabase data reality:
- **Contact Info** (email address): Collected, linked to user, used for app functionality — YES (Supabase auth)
- **Identifiers** (user ID): Collected, linked to user — YES (Supabase UUID + PostHog distinct_id)
- **Usage Data** (product interaction): Collected, not linked to user — YES (PostHog events, anonymized after onboarding)
- **Diagnostics**: Not collected — leave unchecked unless Crashlytics/Sentry is wired (it is not)

- [ ] **Step 6: Set age rating**

App Information → Age Rating → complete the questionnaire. Resumely has no violence, adult content, gambling, or mature themes. Expected result: **4+**.

- [ ] **Step 7: Select the build**

In the 1.0 submission page → Build section → click the `+` → select the build uploaded in Task 5. If the build is still processing, wait until it shows "Ready to Submit" status.

---

## Task 7: Submit for Review

- [ ] **Step 1: Final pre-submit check**

Confirm in ASC that all red warning icons are gone from the 1.0 submission page. Every required field must have a green checkmark.

- [ ] **Step 2: Submit**

Click **Submit for Review** at the top right of the 1.0 submission page.

Expected: status changes to "Waiting for Review". Apple typically responds within 24–48 hours for a first submission.

- [ ] **Step 3: Screenshot confirmation**

Take a screenshot of ASC showing "Waiting for Review" status. Save to `~/Desktop/resumely-submitted-2026-06-03.png`.

---

## Task 8: Post-submission memory update

**Goal:** Record the submission in project memory so the next session starts with accurate state.

- [ ] **Step 1: Update tasks/progress.md**

Open `tasks/progress.md` and update these fields:
```
Status: Submitted for Review
Current Phase: App Store Review
Active Story: Monitor Apple review; prepare 1.0.1 scope after outcome
Last Completed Story: WP3 App Store submission — build uploaded and submitted (2026-06-03)
Next Recommended Story: After review outcome — scope 1.0.1 from docs/specs/resumely-ux-redesign-1.0.1.md
Estimated Completion: 95%
Last Validation: App Store submission confirmed in ASC 2026-06-03. Smoke passed on iPhone 13: optimize, design, expert, export, PostHog Live Events verified.
Last Updated: 2026-06-03
```

- [ ] **Step 2: Update tasks/todo.md**

Mark WP3 complete and add the monitoring task:
```markdown
# Current Task

**Objective:** Monitor App Store review and scope 1.0.1 after outcome.
**Status:** Monitoring
**Branch:** main

## Checklist
- [x] WP1: PostHog analytics fix + device build
- [x] WP2: Post-optimization upgrade (strong_faithful mode, ATS panel, package hub)
- [x] WP3: Device smoke + App Store submission
- [ ] FOUNDER MONITOR: Check ASC for review outcome (24–48h)
- [ ] After approval: scope 1.0.1 implementation plan from UX redesign spec
```

- [ ] **Step 3: Update the Agentic OS dashboard**

```bash
cd "/Users/nadavyigal/Documents/Projects /Agentic OS" && ./agentic-os refresh
```

- [ ] **Step 4: Commit the memory updates**

```bash
cd "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP"
git add tasks/progress.md tasks/todo.md
git commit -m "chore(release): record WP3 completion — app submitted to App Store review"
```

---

## What Not to Touch

- `RuntimeFeatures.isResumeLibraryEnabled` — stays `false` until backend ships `/api/v1/resumes`
- `BackendConfig.isMonetizationEnabled` — stays `false` for v1.0
- Any v1.0 release artifacts after submission — keep `main` frozen until review outcome
- `ResumeBuilder AI (Web)` / `fix/pdf-parse-xref-error` — do not touch unless device smoke exposes a live backend blocker
- RunSmart iOS — completely separate project; do not cross-contaminate this session
