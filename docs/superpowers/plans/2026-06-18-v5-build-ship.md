# v5 Build & Ship Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increment the iOS build number to 5, archive and upload to App Store Connect via Xcode Organizer, smoke-test on a physical device against PostHog Live Events, and submit build 5 for App Store review before the 2026-06-19 morning deadline.

**Architecture:** Single code change (build number in `project.pbxproj`), then manual Xcode GUI steps for archive/upload, then a 5-min device smoke, then App Store Connect submission. No new Swift files. No backend changes.

**Tech Stack:** Xcode Organizer, App Store Connect, PostHog project 270848 (Live Events tab)

---

## File Map

| File | Change |
|------|--------|
| `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` | Lines 404 and 437: `CURRENT_PROJECT_VERSION = 4` → `5` |

Everything else is manual (Xcode GUI, browser, physical device).

---

### Task 1: Bump build number to 5

**Files:**
- Modify: `ResumeBuilder IOS APP.xcodeproj/project.pbxproj:404` (Debug config)
- Modify: `ResumeBuilder IOS APP.xcodeproj/project.pbxproj:437` (Release config)

- [ ] **Step 1: Confirm you are on main and the branch is clean**

```bash
cd "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP"
git checkout main
git pull origin main
git status --short --branch
```

Expected: `## main...origin/main` with no modified files listed.

- [ ] **Step 2: Edit the Debug build number (line 404)**

Open `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` in any editor. Find line 404:

```
				CURRENT_PROJECT_VERSION = 4;
```

Change it to:

```
				CURRENT_PROJECT_VERSION = 5;
```

- [ ] **Step 3: Edit the Release build number (line 437)**

Same file, line 437:

```
				CURRENT_PROJECT_VERSION = 4;
```

Change it to:

```
				CURRENT_PROJECT_VERSION = 5;
```

- [ ] **Step 4: Verify exactly two lines changed**

```bash
git diff "ResumeBuilder IOS APP.xcodeproj/project.pbxproj" | grep "^[+-]" | grep -v "^---\|^+++"
```

Expected output (exactly these 4 lines, nothing else):

```
-				CURRENT_PROJECT_VERSION = 4;
+				CURRENT_PROJECT_VERSION = 5;
-				CURRENT_PROJECT_VERSION = 4;
+				CURRENT_PROJECT_VERSION = 5;
```

If anything else changed, revert it before continuing.

- [ ] **Step 5: Commit and push**

```bash
git add "ResumeBuilder IOS APP.xcodeproj/project.pbxproj"
git commit -m "chore: bump build number to 5 for v5 App Store submission"
git push origin main
```

Expected: push succeeds, remote shows the new commit.

---

### Task 2: Archive and upload via Xcode Organizer

This task is manual — no CLI commands.

- [ ] **Step 1: Open the project in Xcode**

```bash
open "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP/ResumeBuilder IOS APP.xcodeproj"
```

- [ ] **Step 2: Set the scheme and destination**

In the Xcode toolbar:
- Scheme selector: **ResumeBuilder IOS APP**
- Destination selector: **Any iOS Device (arm64)**

Do NOT select a simulator. The archive step requires a physical device destination.

- [ ] **Step 3: Confirm the build number shows 5**

In Xcode: select the project in the navigator, then select the **ResumeBuilder IOS APP** target, then open **Build Settings** and search for `CURRENT_PROJECT_VERSION`. Confirm both Debug and Release show `5`.

- [ ] **Step 4: Create the archive**

Menu: **Product > Archive**

Wait for the build to complete. The Organizer window opens automatically when done. The new archive appears at the top of the list as **ResumeBuilder IOS APP — 1.0 (5)**.

- [ ] **Step 5: Upload to App Store Connect**

In Organizer:
1. Select the **1.0 (5)** archive
2. Click **Distribute App**
3. Choose **App Store Connect**, click **Next**
4. Choose **Upload**, click **Next**
5. Accept all defaults (App Thinning: None, Strip Swift symbols: checked, Upload symbols: checked)
6. Click **Upload**

Wait for Xcode to report "Upload Successful" (~5-15 min depending on connection speed).

- [ ] **Step 6: Confirm processing in App Store Connect**

Open [App Store Connect > Apps > Resumely > TestFlight](https://appstoreconnect.apple.com). After ~10-20 min, build 5 will appear under iOS builds with status **Processing**, then **Ready to Test**.

---

### Task 3: Device smoke test (5 min)

Requires: physical iPhone with TestFlight installed, PostHog Live Events tab open in a browser.

- [ ] **Step 1: Install build 5 from TestFlight**

On your iPhone, open TestFlight > Resumely. Wait for build 5 to appear (may take up to 20 min after "Ready to Test" in ASC). Tap **Update** or **Install**.

- [ ] **Step 2: Open PostHog Live Events**

In a browser, go to PostHog project 270848:
[https://us.posthog.com/project/270848/activity/live](https://us.posthog.com/project/270848/activity/live)

Keep this tab visible so you can see events fire in real time.

- [ ] **Step 3: Flow 1 — App launch**

On your iPhone, tap the Resumely icon to launch the app.

In PostHog Live Events, confirm `app_launched` appears within 30 seconds.

- [ ] **Step 4: Flow 2 — Upload PDF and optimize**

In Resumely:
1. Go to the **Tailor** tab
2. Upload a PDF resume (any readable PDF)
3. Add a job description (paste any text or enter a URL)
4. Tap **Optimize**
5. Wait for the optimization to complete and the Diagnosis screen to appear

In PostHog Live Events, confirm these events appear (in order):
- `resume_uploaded`
- `optimization_started`
- `optimization_completed`
- `diagnosis_viewed`

- [ ] **Step 5: Flow 3 — Export PDF**

In Resumely:
1. From the Optimized tab, tap **Export PDF** (or the share/export button)

In PostHog Live Events, confirm `export_pdf_tapped` appears within 30 seconds.

- [ ] **Step 6: Record smoke result**

All 5 events confirmed = **PASS**. Proceed to Task 4.

If any event is missing:
- Check the PostHog Live Events filter — ensure it is not filtering by user/device
- Confirm build 5 is installed (not an older build from before TestFlight processed)
- Check Xcode console for `[Analytics] transport failed` debug output
- Do NOT submit for review until events fire on device

---

### Task 4: Submit for App Store review

- [ ] **Step 1: Open App Store Connect**

Go to [App Store Connect > Apps > Resumely > App Store > iOS App > 1.0 Prepare for Submission](https://appstoreconnect.apple.com).

- [ ] **Step 2: Select build 5**

Under the **Build** section, click **+** and select build 5 (1.0 (5)). If no build is listed, it is still processing — wait until it shows "Ready to Submit".

- [ ] **Step 3: Submit for review**

Click **Submit for Review** (top right of the 1.0 version page).

Answer any compliance questions as appropriate (export compliance: No encryption beyond standard iOS; IDFA: No).

Click **Submit**.

- [ ] **Step 4: Confirm review status**

After submission, the version status changes to **Waiting for Review**. Confirm this in App Store Connect.

- [ ] **Step 5: Update progress.md**

```bash
cd "/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP"
```

Open `tasks/progress.md` and update the top block:

```markdown
**D7 Gate A Build 5 Submission (2026-06-18/19):** Build 5 (version 1.0 build 5) archived, uploaded to TestFlight, and submitted for App Store review. PostHog smoke on physical device confirmed: app_launched, resume_uploaded, optimization_started, optimization_completed, diagnosis_viewed, export_pdf_tapped all fired in Live Events. Review status: Waiting for Review. Apple 48h review window must clear before 2026-06-21.

Status: App Store live; build 5 in review
Current Phase: D7 Gate A complete
Active Story: None
Last Completed Story: v5 build-and-ship
Next Recommended Story: D7 readout on or after 2026-06-24 — pull PostHog 7-day activation funnel via connected plugin and compare against Gate A targets
Blockers: None
Last Validation: Build 5 App Store submission 2026-06-18/19
Last Updated: 2026-06-18
```

Then commit:

```bash
git add tasks/progress.md
git commit -m "docs: record build 5 App Store submission and Gate A completion"
git push origin main
```

---

## Success Criteria

- [ ] `project.pbxproj` shows `CURRENT_PROJECT_VERSION = 5` in both Debug and Release
- [ ] Xcode Organizer upload reports "Upload Successful" for build 1.0 (5)
- [ ] PostHog Live Events shows all 5 smoke-test events firing on physical device
- [ ] App Store Connect shows version 1.0 as "Waiting for Review" with build 5 selected
- [ ] `tasks/progress.md` updated and pushed
