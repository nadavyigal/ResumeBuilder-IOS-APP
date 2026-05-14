# TestFlight Readiness Checklist — ResumeBuilder iOS

> Run this before uploading any build to TestFlight.
> Use `.agent-os/templates/testflight-report-template.md` to document results.

---

## Build & Signing

- [ ] Scheme set to "Release" (not Debug) for archive
- [ ] Bundle ID is `Resumebuilder-IOS.ResumeBuilder-IOS-APP`
- [ ] Signing team is correct in Xcode → Signing & Capabilities
- [ ] Provisioning profile is valid and not expired
- [ ] Archive completes without errors in Xcode Organizer
- [ ] No DEBUG-only code paths that expose internal state in Release

---

## Entitlements (`ResumeBuilder_IOS_APP.entitlements`)

- [ ] `com.apple.developer.applesignin` is present (Sign in with Apple)
- [ ] Push notification entitlement present if PushService is active
- [ ] No entitlements present that require additional App Store review (e.g. health, NFC)

---

## Info.plist

- [ ] `API_BASE_URL` is set to the production/staging API URL (not localhost)
- [ ] Privacy usage strings present for any permission used:
  - Camera (if any photo upload)
  - Photo Library (if picking from Photos)
  - Notifications (if push used)
- [ ] `CFBundleShortVersionString` (Marketing Version) is correct
- [ ] `CFBundleVersion` (Build Number) is incremented from previous TestFlight upload

---

## App Icon & Launch Screen

- [ ] App icon set is complete (all required sizes in `Assets.xcassets`)
- [ ] No placeholder or missing icon slots
- [ ] Launch screen displays correctly (no blank white flash)

---

## Core Flows (manual smoke test)

- [ ] Cold launch → Onboarding → Sign in with Apple → Main tabs
- [ ] Upload resume → Score tab shows ATS score
- [ ] Tailor tab → paste job description → Optimize → see result
- [ ] Design tab → select template → preview renders
- [ ] Profile tab → credits balance → sign out
- [ ] PDF export → share sheet → exported file opens

---

## Crash-Free Verification

- [ ] No crash on launch (test 5 cold launches)
- [ ] No crash when network is slow (throttle in simulator settings)
- [ ] No crash when optimization API returns error (test with bad job description)
- [ ] No crash on sign out and re-sign-in

---

## Data & Privacy

- [ ] No test user credentials, API keys, or debug tokens embedded in binary
- [ ] No console logs that expose JWT tokens (grep for `print(token)` style logs)
- [ ] User data is not logged to console in Release

---

## TestFlight Distribution

- [ ] Internal testers added (Nadav + any QA team members)
- [ ] TestFlight build description updated with what's new
- [ ] Beta app review notes provided if required by Apple

---

## Known Issues to Document

List any known issues in the TestFlight notes so testers are aware:
- [ ] Known issue: phases 3/5/6 of optimization detail are not complete (see plan-phases-3-5-6.md)
- [ ] Known issue: Hebrew/RTL not supported
