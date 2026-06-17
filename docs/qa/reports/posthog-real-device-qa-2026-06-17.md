# PostHog Real-Device QA - 2026-06-17

## Status

Pass with caveat: analytics instrumentation is code-covered and the physical iPhone build sends events to PostHog project 270848. Five deeper flow events are wired and covered by unit tests, but have not yet been observed in production PostHog traffic.

## Scope

- Source: connected PostHog plugin, project 270848 ("ResumeBuilder AI")
- Device: Nadav.Yigal's iPhone, iPhone 13, iOS 26.5, UDID `00008110-00192DDA2143801E`
- Branch/worktree: `codex/posthog-device-qa` at `origin/main` after PR #66 merge
- Bundle ID: `Resumebuilder-IOS.ResumeBuilder-IOS-APP`

## PostHog Project Context

The PostHog plugin initially pointed at project 171597, which returned a 404 for dashboard 1720819. The plugin context was switched to project 270848 before coverage checks.

Confirmed project context:

- Organization: Nadav Yigal AI advisory
- Project: ResumeBuilder AI
- Project ID: 270848
- Timezone: UTC
- Dashboard: [ResumeBuilder iOS - D7 Activation](https://us.posthog.com/project/270848/dashboard/1720819)

## App Coverage

`AnalyticsEvent` now has exact contract tests for all 16 app-defined events:

| Event | Code-covered | Observed in PostHog 30d |
|---|---:|---:|
| `app_launched` | yes | yes |
| `guest_mode_started` | yes | yes |
| `resume_uploaded` | yes | yes |
| `job_added` | yes | yes |
| `free_ats_completed` | yes | no |
| `sign_in_completed` | yes | yes |
| `account_deleted` | yes | yes |
| `optimization_started` | yes | yes |
| `optimization_completed` | yes | yes |
| `export_started` | yes | yes |
| `export_success` | yes | yes |
| `export_failed` | yes | yes |
| `diagnosis_viewed` | yes | no |
| `ats_improve_tapped` | yes | no |
| `export_pdf_tapped` | yes | no |
| `submit_package_saved` | yes | no |

Interpretation: the app is fully instrumented and test-covered, but the five unobserved events still need real user-path coverage in production or a dedicated authenticated manual smoke that reaches those screens/actions.

## Live PostHog Evidence

Before device QA, project 270848 showed these observed iOS events over the last 30 days with `properties.$lib = 'resumely-ios-urlsession'`:

- `app_launched`: 72 events / 16 users
- `guest_mode_started`: 54 events / 14 users
- `resume_uploaded`: 20 events / 8 users
- `job_added`: 17 events / 7 users
- `export_started`: 14 events / 3 users
- `optimization_started`: 14 events / 3 users
- `export_success`: 12 events / 3 users
- `optimization_completed`: 11 events / 3 users
- `sign_in_completed`: 5 events / 4 users
- `export_failed`: 2 events / 1 user
- `account_deleted`: 1 event / 1 user

After real-device launch and test activity from `2026-06-17T12:25:25Z`, PostHog showed:

- `app_launched`: 2 events / 1 user, latest `2026-06-17T12:27:57.832Z`
- `resume_uploaded`: 2 events / 1 user, latest `2026-06-17T12:27:10.090Z`
- `job_added`: 1 event / 1 user, latest `2026-06-17T12:27:04.186Z`
- `optimization_started`: 1 event / 1 user, latest `2026-06-17T12:27:06.825Z`

## Real-Device QA

Runtime config in the built app was present:

- `API_BASE_URL`: set
- `POSTHOG_API_KEY`: set
- `POSTHOG_HOST`: set

Commands run:

```sh
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -configuration Debug -destination 'platform=iOS,id=00008110-00192DDA2143801E' -derivedDataPath /tmp/resumely-device-qa-derived build
xcrun devicectl device install app --device 00008110-00192DDA2143801E '/tmp/resumely-device-qa-derived/Build/Products/Debug-iphoneos/ResumeBuilder IOS APP.app'
xcrun devicectl device process launch --device 00008110-00192DDA2143801E Resumebuilder-IOS.ResumeBuilder-IOS-APP
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS,id=00008110-00192DDA2143801E' -derivedDataPath /tmp/resumely-device-qa-test-derived -only-testing:'ResumeBuilder IOS APPTests/AnalyticsServiceTests'
```

Results:

- Physical-device Debug build: passed
- Device install: passed
- Device launch: passed
- Focused device test run: passed, 8 tests, 0 failures
- Test result bundle: `/tmp/resumely-device-qa-test-derived/Logs/Test/Test-ResumeBuilder IOS APP-2026.06.17_15-27-05-+0300.xcresult`

## Remaining Coverage Gap

The following events are fully wired and tested but still not observed in project 270848:

- `free_ats_completed`
- `diagnosis_viewed`
- `ats_improve_tapped`
- `export_pdf_tapped`
- `submit_package_saved`

Next QA should use an authenticated manual device smoke that completes resume/job input, reaches Diagnosis, taps Improve ATS, exports PDF, and saves a Submit Package. That will prove the final five events with real production navigation rather than unit-level contract coverage.
