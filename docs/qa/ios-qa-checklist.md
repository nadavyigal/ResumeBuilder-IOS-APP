# iOS QA Checklist — ResumeBuilder iOS

> Run before any TestFlight build or PR merge that touches UI.
> Use `.agent-os/templates/ios-qa-report-template.md` to document results.

---

## Build Check
- [ ] Xcode build succeeds with no errors (`cmd+B`)
- [ ] No new warnings that could become errors in future Swift versions
- [ ] Tests pass (`xcodebuild test`)

---

## Launch Check
- [ ] App launches without crash on iPhone 17 simulator
- [ ] App launches without crash on iPhone SE (small viewport) simulator
- [ ] Splash / launch screen displays correctly
- [ ] Sign in with Apple prompt appears correctly for unauthenticated users
- [ ] After sign-in, MainTabViewV2 loads correctly (5 tabs visible)

---

## Navigation Check
- [ ] All 5 tabs are tappable and load their screen
- [ ] Tab bar is visible and not overlapped by safe area
- [ ] Back navigation works (no stuck navigation stacks)
- [ ] Deep link opens correct screen (if tested)

---

## Score Tab
- [ ] ATS score displays (or upload prompt if no resume)
- [ ] ATSDial renders with correct score value
- [ ] Score breakdown sections are readable
- [ ] Quick Wins section displays
- [ ] Issue Summary displays
- [ ] "Upload Resume" CTA works if no resume uploaded

---

## Tailor Tab
- [ ] Job description input field is reachable and usable
- [ ] Resume file is selectable / already selected
- [ ] "Optimize for This Job" button triggers API call
- [ ] Loading state displays during optimization
- [ ] OptimizedResumeView shows after optimization completes
- [ ] Resume sections display (not empty) in OptimizedResumeView

---

## Design Tab
- [ ] Template gallery loads
- [ ] Template thumbnails render
- [ ] Selecting a template triggers preview
- [ ] Preview renders in WKWebView without blank screen
- [ ] Template can be applied

---

## Track Tab
- [ ] Applications list loads (empty state or list)
- [ ] Can add a new application
- [ ] Application detail view opens
- [ ] Applied status toggle works

---

## Profile Tab
- [ ] User name / account info displays
- [ ] Credits balance shows correct value
- [ ] Sign out works (returns to Onboarding)
- [ ] Paywall / upgrade flow opens (does not crash)

---

## Auth Flow
- [ ] Unauthenticated user sees Onboarding screen
- [ ] Sign in with Apple completes successfully
- [ ] After sign-in, app navigates to main tabs
- [ ] Sign out clears session and returns to Onboarding
- [ ] Resume upload prompt appears after auth if no resume exists

---

## PDF Export
- [ ] "Preview PDF" opens ResumePreviewWebView
- [ ] PDF renders without blank areas or text overflow
- [ ] "Export" / "Share" triggers share sheet
- [ ] Exported file opens correctly in Files app
- [ ] File has reasonable size (< 5 MB)

---

## Accessibility
- [ ] All interactive elements have accessibility labels
- [ ] Text is readable at default text size
- [ ] No touch targets smaller than 44×44 pt

---

## Small iPhone (SE) Viewport
- [ ] Run on iPhone SE simulator (375pt wide)
- [ ] Tab bar labels are not clipped
- [ ] Resume section cards are not overflowing
- [ ] Text inputs are not hidden behind keyboard
- [ ] All CTAs are reachable without scrolling dead zones

---

## Dark Mode
- [ ] All screens render correctly in dark mode (expected — app is dark-mode-only)
- [ ] No hardcoded white or black backgrounds causing visual breaks
- [ ] Text contrast is readable

---

## Performance
- [ ] No visible lag when switching tabs
- [ ] AI optimization call shows progress indicator
- [ ] Template gallery loads within 3 seconds
