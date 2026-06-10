# App Store Readiness Checklist — ResumeBuilder iOS

> Run this before submitting to App Store review.
> Requires TestFlight checklist to pass first.

---

## App Store Connect Metadata

- [ ] App name set: "Resumely" or confirmed final name
- [ ] Subtitle (30 chars max): clear value prop
- [ ] Description (4000 chars): covers all features, no placeholder text
- [ ] Keywords (100 chars): resume, ATS, job, AI, optimizer, career
- [ ] Category: Productivity (primary), Business (secondary)
- [ ] Privacy policy URL is live (not a placeholder)
- [ ] Support URL is live
- [ ] Age rating: 4+ (confirm no user-generated violent content)

---

## Screenshots

- [x] iPhone 6.7" screenshots (required): min 3, max 10 — rb-aso-002 exported 5 PNGs at 1290x2796
- [x] iPhone 6.5" screenshots (required) — rb-aso-002 exported 5 PNGs at 1242x2688
- [ ] iPad screenshots (if iPad is supported)
- [x] Screenshots show real app UI (not mockups) — launch-argument-only SwiftUI renderer, captured in simulator
- [x] Screenshots show: ATS score, Tailor, AI edits, Design/PDF export, Expert review
- [ ] App preview video (optional but recommended)

---

## IAP Products

- [ ] Credit pack products are configured in App Store Connect
- [ ] Product IDs match exactly what `StoreKitManager.swift` expects
- [ ] Products are in "Ready to Submit" state
- [ ] Pricing is correct

---

## Build Quality

- [ ] All items in TestFlight checklist pass
- [ ] No placeholder UI anywhere in the app
- [ ] No test/debug UI visible to users
- [ ] All loading/empty/error states are implemented (no blank white screens)
- [ ] Crash-free on clean install (no prior data)
- [ ] Crash-free after app update from previous version

---

## Legal

- [ ] Privacy policy covers: data collected, how it's used, Sign in with Apple, AI processing
- [ ] Terms of service present
- [ ] No third-party trademarks used without permission (resume brand names, etc.)

---

## Final Pre-Submission

- [ ] Build is archived and uploaded to App Store Connect
- [ ] Build selected in App Store Connect submission
- [ ] Compliance questions answered (uses encryption: Yes, for HTTPS)
- [ ] Export compliance documented
- [ ] "Submit for Review" clicked
