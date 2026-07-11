# Work Packet WP-44 — iOS Upload Activation: Picker Landing + No-File Fallback Inputs

- Status: Ready for execution. Not started.
- Created: 2026-07-11
- Source: Live iOS Simulator first-time-user walkthrough of Resumely 1.4.1 (11) (Claude session 2026-07-11). Companion to WP-43 (web entry-funnel activation).
- Mode: Builder — one story at a time, smallest shippable diff, device QA per story.
- Outcome loop: Resumely activation (20% / 30d). Attacks the iOS `resume_file_picker_opened → resume_file_selected` drop confirmed live in PostHog project 270848.
- Repo: `/Users/nadavyigal/Documents/Projects /ResumeBuilder/ResumeBuilder IOS APP`

## Why this packet exists

The iOS Home screen is already strong (above-the-fold CTA, branded dropzone, "PDF or DOCX · up to 5MB", "Step 1 of 3" progressive disclosure, location cues). The walkthrough confirmed the drop is NOT the app's own UI — it is the handoff to Apple's system file picker:

1. Tap "Choose a file" → iOS Files opens on the **Recents** tab showing "No Recents / Recently opened documents will appear here." An empty screen; the "Browse" tab is tucked into the bottom bar.
2. Tap Browse → "On My iPhone" → **"On My iPhone is Empty."**

Two layers, both confirmed live on 1.4.1:
- **App-controllable:** `HomeTabView.swift:212` uses SwiftUI's `.fileImporter`, which cannot set a starting directory, so users always land on empty Recents.
- **Root cause:** a first-time mobile user frequently has **no resume file on the phone at all** (it lives on their laptop, in email, or on LinkedIn). No picker UX fixes that. The only real unlock is input paths that do not require a local file.

## Files in scope

| File | Role |
|---|---|
| `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` | Upload CTA + `.fileImporter` (line ~212), `resumeImportContentTypes` (line ~283), `openUploadPicker`. |
| `ResumeBuilder IOS APP/Features/V2/Home/UploadSheetView.swift` | Existing upload sheet — where a "paste text" affordance can live. |
| `ResumeBuilder IOS APP/Features/Tailor/TailorViewModel.swift` | `cachePickedFile` and the upload/optimize path the new inputs must feed. |
| `ResumeBuilder IOS APP/Core/Analytics/AnalyticsService.swift` | Event enum (`resumeFilePickerOpened`, `resumeFileSelected`, etc.) — add cases for the new paths. |
| `ResumeBuilder IOS APP/Resources/Localizable.xcstrings` | EN + HE (RTL) strings for all new copy. |

Grounding verified in code:
- `.fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:)` at `HomeTabView.swift:212`; content types `.pdf`, `.docx`, `.doc` at `:283`.
- Rich analytics already exists: `resume_upload_cta_tapped`, `resume_file_picker_opened`, `resume_file_picker_cancelled`, `resume_file_selected`, `resume_upload_*` (`AnalyticsService.swift:90-130`).
- No existing paste-text, photo/OCR, or URL-based resume-input path exists today.

## Stories (one small diff each, device QA per story)

### S1 — Picker lands on a real folder, not empty Recents (P1, app-only)
Replace the SwiftUI `.fileImporter` at `HomeTabView.swift:212` with a thin `UIViewControllerRepresentable` wrapper around `UIDocumentPickerViewController(forOpeningContentTypes:)`, setting `directoryURL` to the iCloud Drive container (or `.documentsDirectory`) so the picker opens on Browse / a populated location instead of empty Recents. Preserve the existing content types (`.pdf/.docx/.doc`), single-selection, and every current analytics call (`resumeFilePickerOpened`, `resumeFileSelected`, `resumeFilePickerCancelled`, and the `cachePickedFile` handoff).
- Acceptance: opening the picker no longer lands on an empty "Recents"; it opens on Browse or a directory with visible files. All existing upload analytics still fire identically. Device QA on a real iPhone (physical, since simulator has no user files) + iPhone 17 sim.
- Note: `directoryURL` is a best-effort hint iOS may override; if it proves unreliable on-device, fall back to documenting the limitation rather than shipping a worse control.

### S2 — "No file on your phone? Paste your resume text" fallback (P0 for the root cause)
Add a secondary affordance beneath the upload CTA (Home + `UploadSheetView`): "No file on your phone? Paste your resume text." Opens a text sheet that submits the pasted text down the same optimize/diagnosis path the file upload feeds.
- DEPENDENCY (verify before building): confirm the backend accepts a raw-text resume (the web `/api/public/ats-check` path already reads `resumeText`; confirm the iOS-facing endpoint in `Core/API/Endpoints.swift` / `APIClient.swift` has an equivalent). If no text endpoint exists, this story's backend half is a separate web-repo packet — flag it, do not fake a client-only path.
- New analytics: `resume_paste_text_opened`, `resume_paste_text_submitted` (add cases in `AnalyticsService.swift`).
- Acceptance: a user with zero files on the phone can paste resume text and reach the same first diagnosis as the file path. EN + HE strings. Focused test on the submit path.

### S3 — "Scan your resume" via on-device OCR (P2, depends on S2)
Add a "Scan a printed or on-screen resume" option using VisionKit `VNDocumentCameraViewController` + `VNRecognizeTextRequest` (on-device, no new dependency, no image leaves the device). OCR output feeds the S2 text path.
- Acceptance: scanning/photographing a resume produces text that reaches the diagnosis; privacy copy states the image is processed on-device and not uploaded. Depends on S2's text path existing.

## Explicitly OUT of scope (with reason)
- **"Import resume from a LinkedIn profile URL."** Rejected: pulling a resume from a LinkedIn profile requires scraping LinkedIn, which violates their ToS and hits the exact datacenter-IP degraded-content failure already documented for the LinkedIn *job* scrape in the web repo (thin ~222-char responses → garbage output). Do not build a LinkedIn-profile-as-resume-source path. (LinkedIn-URL for the *job description* at step 2 is a separate, existing concern handled elsewhere.)

## Constraints
- Smallest shippable diffs; Home/upload scope only; do not touch onboarding, scoring, or paywall.
- No new third-party dependencies (VisionKit is first-party). Flag anything else before adding.
- Every new user-facing string needs EN + HE (RTL) in `Localizable.xcstrings`.
- Physical-device findings trump simulator (the simulator has no user files, so S1/S2 file-presence QA must be on a real iPhone).

## Validation
- Debug build on iPhone 17 sim + physical device per story.
- Focused XCTest for the S2 text-submit path; keep `AnalyticsServiceTests` green (extend for new event cases).
- Device QA screenshots into `docs/qa/reports/`.
- `git status --short --branch` + push + PR per session-end rule.

## Measurement
- Watch `resume_file_picker_opened → resume_file_selected` for S1 lift.
- New `resume_paste_text_submitted` and scan events give a second activation path that bypasses the file picker entirely — the metric to prove the root-cause fix.
- Success signal: a rising share of first-session users who reach the first diagnosis WITHOUT ever selecting a file (paste or scan), plus higher overall picker→selected on the file path.
