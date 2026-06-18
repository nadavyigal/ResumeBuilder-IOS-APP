# v5 Build & Ship — Design Spec

**Date:** 2026-06-18
**Deadline:** Submit for App Store review by 2026-06-19 morning (48h Apple review window before 2026-06-21 D7 Gate A)
**Approach:** Approach B — Bump → Archive → TestFlight smoke → Submit

---

## Scope

This is a build-increment and submission task. No code changes. Everything needed for v5 is already merged into `main`:

- PostHog 8-event analytics funnel (all 16 events wired, 8 are the core Gate A funnel)
- Resume Library enabled (`RuntimeFeatures.isResumeLibraryEnabled = true`)
- Hebrew/RTL localization (PR #63, merged)
- Analytics service hardening (8/8 tests pass, PII guard, fire-and-forget)

---

## Steps

### 1. Build increment

Edit `ResumeBuilder IOS APP.xcodeproj/project.pbxproj`:
- `CURRENT_PROJECT_VERSION` → `5` (both Debug and Release configurations)
- `MARKETING_VERSION` stays `1.0`
- Resulting App Store version string: **1.0 (5)**

Commit the single-line change to `main`.

### 2. Archive

No `ExportOptions.plist` exists in the project (build 4 used the Xcode GUI). Use Xcode Organizer:

1. Open `ResumeBuilder IOS APP.xcodeproj` in Xcode
2. Set scheme to **ResumeBuilder IOS APP**, destination to **Any iOS Device (arm64)**
3. **Product > Archive** — wait for Organizer to open
4. Select the new 1.0 (5) archive, click **Distribute App > App Store Connect > Upload**
5. Accept defaults through the wizard until upload completes (~10-20 min processing in ASC)

### 3. TestFlight upload

The Xcode Organizer upload in step 2 handles this. Once Xcode reports "Upload Successful", allow ~10-20 min for App Store Connect to process. Build 5 will appear in TestFlight automatically.

### 4. Device smoke (5 min, physical iPhone)

Install build 5 from TestFlight. Open PostHog project 270848 Live Events tab. Run three flows:

| Flow | Expected PostHog events |
|------|------------------------|
| Launch app | `app_launched` |
| Upload PDF → Run optimize | `resume_uploaded`, `optimization_started`, `optimization_completed`, `diagnosis_viewed` |
| Tap Export PDF | `export_pdf_tapped` |

Pass = all 5 events appear in Live Events within 30 seconds of each action. Fail = investigate before submitting.

### 5. App Store review submission

Submit build 5 for review via App Store Connect UI:
- Select build 5 under the 1.0 version
- Click "Submit for Review"

No metadata changes required. Hebrew App Store metadata was handled separately (manual ASC submission per the post-merge checklist).

---

## Out of Scope

- No Swift code changes
- No new localization strings or languages
- No analytics wiring changes
- No backend changes
- No new dependencies

---

## Success Criteria

- Build 5 appears in App Store Connect as "Waiting for Review"
- PostHog Live Events confirms at least 5 of the 8 Gate A funnel events fire on device during smoke
- Submission happens by 2026-06-19 morning to meet the 2026-06-21 D7 deadline
