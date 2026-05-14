# Workflow: TestFlight Readiness Review

> Run before uploading any build to TestFlight.
> Use `.agent-os/templates/testflight-report-template.md` for the report.

---

## Steps

### 1. iOS QA Must Pass First
The iOS QA checklist (`docs/qa/ios-qa-checklist.md`) must be complete and passing before starting TestFlight review. Do not skip to TestFlight without QA.

### 2. Work Through the TestFlight Checklist
Read `docs/qa/testflight-checklist.md` in full. Walk through each section:

**Build & Signing:**
- Confirm bundle ID: `Resumebuilder-IOS.ResumeBuilder-IOS-APP`
- Confirm signing team in Xcode
- Archive with Release scheme

**Entitlements:**
- `com.apple.developer.applesignin` present
- No unexpected entitlements

**Info.plist:**
- `API_BASE_URL` is set to production/staging (not localhost)
- Version number (`CFBundleShortVersionString`) is correct
- Build number (`CFBundleVersion`) is incremented

**App Icon & Launch Screen:**
- All icon slots filled
- No transparent pixels

### 3. Archive the App
In Xcode: Product → Archive → Validate → Distribute (TestFlight)

If archive fails, fix the error before proceeding.

### 4. Core Flow Smoke Test (After Archive, On Real Device)
Upload to TestFlight, install on a real iPhone, and test:
- Cold launch
- Sign in with Apple
- Upload resume (or use existing)
- Run ATS score
- Run optimization
- View PDF preview
- Export PDF
- Sign out

### 5. Verify No Test Data or Secrets
- No hardcoded test tokens in the build
- API points to correct environment (not localhost)
- No debug UI visible in Release build

### 6. Write the TestFlight Report
Use `.agent-os/templates/testflight-report-template.md`.
Save to `docs/qa/reports/testflight-[version]-[date].md`.

### 7. Update Progress
Update `tasks/progress.md` → Status field to "Ready for TestFlight".

---

## Pass Criteria
- Archive succeeds without errors
- All entitlements correct
- Info.plist: API_BASE_URL set, version incremented
- Core flows pass on real device
- No test data / secrets in build
- QA checklist already passed
