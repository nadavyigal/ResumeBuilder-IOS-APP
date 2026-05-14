# Workflow: iOS QA Review

> Use before any TestFlight build or PR merge that touches UI.

---

## Steps

### 1. Open the Checklist
Read `docs/qa/ios-qa-checklist.md` in full before starting.

### 2. Build
```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```
Build must succeed. If it fails, stop — the QA is blocked.

### 3. Run Tests
```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```
All tests must pass.

### 4. Walk Through Checklist on iPhone 17 Simulator
For each item in `docs/qa/ios-qa-checklist.md`:
- Mark ✅ pass, ❌ fail, ⚠️ partial
- Note the exact issue for any fail/partial

Focus areas:
- Launch and onboarding
- All 5 tabs
- PDF export
- Auth (sign in / sign out)

### 5. Walk Through Checklist on iPhone SE Simulator
Repeat the navigation and core flow checks on iPhone SE (375pt wide).
Note any layout overflows or clipped content.

### 6. Check Dark Mode
The app is dark-mode-only. Verify no visual breaks:
- No hardcoded white/light backgrounds
- No illegible text contrast
- All components render as expected

### 7. Write the QA Report
Use `.agent-os/templates/ios-qa-report-template.md`.
Save report to `docs/qa/reports/ios-qa-[date].md`.

### 8. Update Progress
Update `tasks/progress.md` → Last Validation field.

---

## Pass Criteria
- Build: no errors
- Tests: all pass
- Launch: no crash (5 cold launches)
- All 5 tabs: load correctly
- Auth: sign in / sign out works
- PDF export: renders and exports
- iPhone SE: no layout failures
- All issues documented in QA report
