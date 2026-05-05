# ResumeBuilder iOS App

SwiftUI iOS client for uploading, optimizing, redesigning, and exporting resumes.

## Requirements

- Xcode 16+
- iOS 17 SDK
- Valid Apple signing setup for your team

## Setup

1. Open `ResumeBuilder IOS APP.xcodeproj` in Xcode.
2. Select the `ResumeBuilder IOS APP` scheme.
3. Confirm signing under the app target (`Signing & Capabilities`).
4. If needed, set `API_BASE_URL` in target build settings (`Info` tab -> custom keys).

## Running

1. Build and run the app from Xcode.
2. Authenticate through onboarding.
3. Upload a resume.
4. Go to Improve and tap **Optimize for This Job**.

## Testing

The project includes optimization flow tests in `ResumeBuilder IOS APPTests`:

- `ResumeOptimizationParsingTests` validates decode compatibility across API payload shapes.
- `ImproveViewModelTests` validates optimize success and user-facing error handling.

Run tests:

```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 16" test
```

If running in a restricted environment, set a writable local derived data directory:

```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination "platform=iOS Simulator,name=iPhone 16" -derivedDataPath ".derivedData" test
```
