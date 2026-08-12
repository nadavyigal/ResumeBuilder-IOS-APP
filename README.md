# ResumeBuilder iOS App

SwiftUI iOS client for uploading, optimizing, redesigning, and exporting resumes.

**Source of truth:** [github.com/nadavyigal/ResumeBuilder-IOS-APP](https://github.com/nadavyigal/ResumeBuilder-IOS-APP), branch **`main`** only. Clone this repo and work on `main`; older feature branches have been removed to avoid drift.

Historical tags include `pre-consolidation-r3` (prior `main`), `pre-consolidation-r2`, and `consolidated-2026-05-11` for provenance.

## Requirements

- Xcode 16+
- iOS 17 SDK
- Valid Apple signing setup for your team

## Setup

1. Open `ResumeBuilder IOS APP.xcodeproj` in Xcode.
2. Select the `ResumeBuilder IOS APP` scheme.
3. Confirm signing under the app target (`Signing & Capabilities`).
4. If needed, set `API_BASE_URL` in target build settings (`Info` tab -> custom keys).
5. Create `Secrets.xcconfig` at the repo root (gitignored, already wired as the base
   configuration for Debug and Release):

   ```
   POSTHOG_API_KEY = ...
   SUPABASE_ANON_KEY = ...

   # Team installs, excluded from every activation metric.
   # Plus-aliases fold into the base address, so name+qa@example.com matches name@example.com.
   INTERNAL_TESTER_EMAILS = you@example.com
   INTERNAL_TESTER_USER_IDS = <supabase-user-uuid>
   ```

   **Do not skip the last two.** They are declared in `Config/Info.plist` and read at
   runtime; when they are undefined the allowlist is empty and every team install is
   counted as a real user in the activation numbers. That shipped undetected for months
   because an unset allowlist looks exactly like "no testers used this build". The app
   logs a warning on launch when both are empty.

## Running

1. Build and run the app from Xcode.
2. Authenticate through onboarding.
3. Upload a resume.
4. Go to Improve and tap **Optimize for This Job**.

## Testing

The project includes optimization flow tests in `ResumeBuilder IOS APPTests`:

- `ResumeOptimizationParsingTests` validates decode compatibility across API payload shapes.
- `ImproveViewModelTests` validates optimize success and user-facing error handling.
- `ResumeOptimizationServiceSwiftTestingTests` validates injectable optimization mocks and decode paths.

Pick a simulator that exists on your machine (examples: **iPhone 16**, **iPhone 17**).

```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Derived data tip (CI or paths with unusual metadata):

```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "/tmp/RB_ios_derivedData" \
  test
```
