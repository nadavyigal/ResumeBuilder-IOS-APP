# App Store Readiness Checklist — ResumeBuilder iOS

> Run this before submitting to App Store review.
> Requires TestFlight checklist to pass first.
>
> **Archive from:** `main` after PR #57 merge  
> **Version:** 1.0 (4) — bumped for resubmission after prior ASC uploads through build 3

---

## App Review Information (paste into ASC)

**Sign-in:** Email and password only. Sign in with Apple is intentionally hidden in this build because the prior review hit Supabase `provider_disabled` on 2026-06-10. Do not attempt Apple Sign In during review.

**Notes to reviewer:**

```
Sign in with the demo email/password below (not Sign in with Apple).

Recommended review path:
1. Home → Import a text-based PDF resume (Word/Pages export; scanned PDFs are rejected locally with guidance)
2. Paste a job description → Optimize
3. Optimized → Preview & Export PDF → share/export
4. Optional: Submit Package → review draft → Save Package to Me → open package in Me

Saved resume library is disabled in v1.0 (backend endpoint not live). Monetization/IAP is disabled in this build.
```

**Demo account:** Use your onboarded test email + password (must have completed at least one optimization). Confirm the account works on a clean install before submitting.

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

Upload from repo (slot order in `dist/app-store-screenshots/rb-aso-002/upload-manifest.md`):

| ASC slot | Local path |
|----------|------------|
| iPhone 6.9" / 6.7" | `dist/app-store-screenshots/rb-aso-002/iphone-6.7/slot-1.png` … `slot-5.png` (1290×2796) |
| iPad 13" | `dist/app-store-screenshots/rb-aso-002/ipad-13/slot-1.png` … `slot-5.png` (2048×2732) |

- [x] iPhone 6.7" screenshots (required): 5 PNGs at 1290×2796
- [x] iPad 13" screenshots (required — app targets iPhone + iPad): 5 PNGs at 2048×2732
- [x] Screenshots show real app UI (launch-argument marketing renderer)
- [ ] **ASC action:** Upload iPhone set to 6.9" iPhone section; upload iPad set to 13" iPad section
- [ ] **ASC action:** Visually confirm iPhone slot 2 has no truncated blocker text before upload
- [ ] App preview video (optional)

Do not upload `iphone-6.5/` duplicates into the same iPhone section.

---

## IAP Products

N/A for v1.0 resubmission — `BackendConfig.isMonetizationEnabled = false`. Skip IAP configuration unless monetization is enabled in a future release.

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
