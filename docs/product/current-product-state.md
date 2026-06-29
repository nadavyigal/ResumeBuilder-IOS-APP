# Current Product State — ResumeBuilder iOS

**Version:** 1.2 (build 7)
**Status:** Submitted to App Store Connect review
**Date:** 2026-06-28

---

## What the App Does

Resumely iOS is a native SwiftUI app that helps users check job fit, tailor a resume to a specific role, and export a polished application package from iPhone. Users upload an existing resume, add a job description or job link, review a Resumely Match Score and top gaps, apply targeted edits, choose a professional design template, and export a resume PDF with supporting application materials.

---

## The 5 Tabs

### Home / Fit-First (`Features/V2/Home/`, `Features/V2/Fit/`)
- Upload-first entry with Fit-First triage before optimization
- Displays Strong / Stretch / Skip fit guidance and top gaps
- Sends upload-journey and fit-check analytics for post-1.2 funnel reads
- Status: **Working**

### Match Score Surfaces (`Features/V2/Score/`, Optimized)
- Displays the self-defined Resumely Match Score, not an official employer ATS score
- Shows job-specific guidance, missing keywords, formatting signals, and quick wins
- Shows quick wins (easy improvements) and issue summary
- Status: **Working**

### Tailor / Optimize Flow (`Features/V2/` — TailorView, Home)
- User adds a job description or URL
- App runs Fit-First when enabled, then routes into `/api/optimize`
- Shows diagnosis, optimization result, targeted edits, and score improvement
- Leads to `OptimizedResumeView`
- Status: **Working**

### Design Tab (`Features/V2/Design/` — RedesignResumeView)
- User selects a template from the design gallery
- App applies the template to their optimized resume
- Shows preview via WKWebView
- Status: **Working** — design picker access from OptimizedResumeView not yet complete (phase 6)

### Me / Applications (`Features/Profile/`)
- User tracks job applications they have submitted
- Saved application package includes resume, job link, cover letter, and interview/screening Q&A where available
- Can add notes, compare resume versions, mark applied status
- Status: **Working**

### Submit Package (`Features/V2/Improve/SubmitApplicationViewModel.swift`)
- Builds a reviewable draft before save
- Saves/reopens job link, cover letter, and interview/screening Q&A from Me
- Status: **Working**

---

## What Is Missing / Not Yet Built

- In-app resume section text editing (users cannot edit resume content in-app)
- Resume creation from scratch (currently requires uploading an existing resume)
- Multiple resume management (only one active resume per user)
- Paste-text diagnosis, sample/demo diagnosis, parser-stage progress callbacks, point-delta apply-all fixes, resumable offline analysis, and a true connection-loss auto-resume
- Post-1.2 production funnel read for upload, fit check, optimization, and export

---

## Auth & Accounts

- Sign in with Apple (primary)
- Anonymous/public check session supported where the endpoint allows it
- JWT stored in Keychain via `KeychainStore.swift`
- Session refreshed on app launch via `AppState.bootstrapAndRefreshSession()`

---

## AI / API

- Backend is a separate Next.js service
- API base URL set via `API_BASE_URL` Info.plist key
- Key endpoints: `/api/public/ats-check`, `/api/optimize`, `/api/v1/optimizations/[id]`, `/api/v1/chat`, `/api/v1/expert-workflows`, design templates, download/export, applications.

---

## Payments

- StoreKit 2 via `StoreKitManager.swift`
- Credits/paywall scaffolding exists, but monetization remains gated off for the current activation-read phase.
- IAP receipt verification via `ReceiptVerifier.swift`
- Paywall in `PaywallView.swift`
