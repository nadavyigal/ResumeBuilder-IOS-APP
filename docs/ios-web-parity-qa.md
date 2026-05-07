# iOS Web Parity QA

## Contract Smoke Checks

Use these payload expectations while testing the native app against the deployed web API.

### Anonymous ATS
- Launch signed out.
- Open Score.
- Choose a text-based PDF resume.
- Paste a LinkedIn job URL into the URL field.
- Tap Run ATS Score.
- Expected: `/api/public/ats-check` returns `success`, `sessionId`, `score.overall`, `preview.topIssues`, optional `quickWins`, and `checksRemaining`.
- Expected UI: top issues and quick wins render, and full optimization remains locked behind sign-in.

### Anonymous Session Conversion
- Complete an anonymous ATS check.
- Sign in or create an account.
- Expected: app calls `/api/public/convert-session` with the stored `sessionId`.
- Expected UI: no blocking error if conversion fails, because conversion is best-effort.

### Authenticated Optimization
- Launch signed in.
- Open Tailor.
- Choose a text-based PDF resume.
- Paste the same LinkedIn job URL.
- Tap Optimize.
- Expected: `/api/upload-resume` receives multipart `resume` and `jobDescriptionUrl`.
- Expected response: `success: true`, `resumeId`, `jobDescriptionId`, `reviewId`, `nextStep: "review"`.

### Review And Apply
- After optimization, wait for the review card.
- Accept/reject at least one change.
- Tap Apply Accepted Changes.
- Expected: app calls `/api/v1/optimization-reviews/{id}/apply` with `approvedGroupIds`.
- Expected response: `optimizationId`.
- Expected UI: Design Optimized Resume link appears.

### Supabase Resume Visibility
- Optimize and apply a resume on web using the same account.
- Open iOS Profile or Track.
- Expected: `/api/optimizations` returns that optimization.
- Expected UI: the latest optimized resume appears with job title/company and a preview when `rewriteData` is present.

### Design Templates
- Open Design Optimized Resume.
- Expected: `/api/v1/design/templates` returns templates.
- Expected UI: template list shows category/premium/ATS score, selecting a template updates the preview label.
- Optional: enter a style request and submit.
- Expected: `/api/v1/design/{optimizationId}/customize` is called with `changeRequest`.

## Build Verification

Run from `/Users/nadavyigal/Documents/Projects /ResumeBuilder`:

```bash
xcodebuild -project "ResumeBuilder IOS APP/ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "ResumeBuilder IOS APP/build/DerivedData" ENABLE_USER_SCRIPT_SANDBOXING=NO build
```

If Cursor sandboxing prevents Xcode's Swift macro plugin server from running, rerun the same command outside the sandbox in Terminal/Xcode.
