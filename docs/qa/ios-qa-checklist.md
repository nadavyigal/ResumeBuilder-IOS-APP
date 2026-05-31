# iOS QA Checklist — ResumeBuilder iOS

> Run before any TestFlight build or PR merge that touches UI.
> Use `.agent-os/templates/ios-qa-report-template.md` to document results.

---

## Build Check
- [ ] Xcode branch popover shows `main` before phone rebuilds
- [ ] Local `main` HEAD matches `origin/main` (`git fetch origin && git rev-parse main` equals `git rev-parse origin/main`)
- [ ] Clean build folder before rebuilding on a physical iPhone after merging a PR
- [ ] Xcode build succeeds with no errors (`cmd+B`)
- [ ] No new warnings that could become errors in future Swift versions
- [ ] Tests pass (`xcodebuild test`)

---

## Launch Check
- [ ] App launches without crash on iPhone 17 simulator
- [ ] App launches without crash on iPhone SE (small viewport) simulator
- [ ] Splash / launch screen displays correctly
- [ ] Guest launch shows Home tab without blocking onboarding screen
- [ ] After sign-in, MainTabViewV2 loads correctly (Home, Optimized, Design, Expert, Me)

---

## Navigation Check
- [ ] Tab bar VoiceOver labels: Home, Optimized, Design, Expert, Me
- [ ] All 5 tabs are tappable and load their screen
- [ ] Tab bar is visible and not overlapped by safe area
- [ ] Back navigation works (no stuck navigation stacks)
- [ ] Deep link opens correct screen (if tested)

---

## Home Tab
- [ ] Home tab label displays (not Tailor)
- [ ] Activation banner reflects current state (no resume, job added, ATS, etc.)
- [ ] Resume upload step works (PDF preflight)
- [ ] Job URL / paste input works
- [ ] Guest: Free ATS check runs and shows score
- [ ] Guest: Sign in to Optimize CTA opens onboarding
- [ ] Auth: Optimize triggers API and switches to Optimized tab
- [ ] Saved resume library UI hidden when feature flag is off

---

## Optimized Tab
- [ ] Primary CTA is Preview & Export PDF
- [ ] Secondary Improve further group: Refine, Design, Expert
- [ ] Export success actions appear after PDF export
- [ ] OptimizedResumeView shows after optimization completes
- [ ] Resume preview renders (not blank)

---

## Design Tab
- [ ] Template gallery loads
- [ ] Template thumbnails render
- [ ] Selecting a template triggers preview
- [ ] Preview renders in WKWebView without blank screen
- [ ] Template can be applied

---

## Design Tab
- [ ] Locked state shows Go to Home when no optimization
- [ ] Template gallery loads after optimization
- [ ] Preview renders in WKWebView without blank screen
- [ ] Template can be applied

---

## Expert Tab
- [ ] Locked state shows Go to Home when no optimization
- [ ] Expert modes load after optimization

---

## Me Tab
- [ ] Guest: shows Guest mode + Sign In CTA (no fake Signed in)
- [ ] Auth: real email + Sign Out
- [ ] Credits balance shows correct value (if monetization on)
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
