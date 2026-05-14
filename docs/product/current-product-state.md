# Current Product State — ResumeBuilder iOS

**Version:** 1.0 (build 1)
**Status:** Pre-release — targeting TestFlight
**Date:** 2026-05-13

---

## What the App Does

ResumeBuilder iOS is a native SwiftUI app that helps users improve their resumes using AI. Users upload an existing resume (PDF), run an ATS score analysis, get AI-powered optimization suggestions tailored to a specific job, apply a professional design template, and export a polished PDF.

---

## The 5 Tabs

### Score Tab (`Features/V2/Score/`)
- Displays ATS (Applicant Tracking System) score for the user's uploaded resume
- Shows breakdown by category: keywords, formatting, structure
- Shows quick wins (easy improvements) and issue summary
- Status: **Working**

### Tailor Tab (`Features/V2/` — TailorView)
- User pastes a job description
- App uploads resume + job → calls `/api/optimize`
- Shows optimization result (sections, score improvement)
- Leads to `OptimizedResumeView`
- Status: **Working** — phases 3/5/6 of review flow are in progress (see `plan-phases-3-5-6.md`)

### Design Tab (`Features/V2/Design/` — RedesignResumeView)
- User selects a template from the design gallery
- App applies the template to their optimized resume
- Shows preview via WKWebView
- Status: **Working** — design picker access from OptimizedResumeView not yet complete (phase 6)

### Track Tab (`Features/Track/` — ApplicationsListView)
- User tracks job applications they have submitted
- Can add notes, compare resume versions, mark applied status
- Status: **Working** (not in V2 migration yet)

### Profile Tab (`Features/V2/Profile/` — ProfileViewV2)
- Shows account info, sign in/out
- Shows credits balance
- Paywall / IAP upgrade flow
- Status: **Working**

---

## What Is In Progress

| Phase | Description | File |
|-------|-------------|------|
| Phase 3 | Load resume sections after apply-review → OptimizedResumeView (currently empty) | `plan-phases-3-5-6.md` |
| Phase 5 | Wire "Preview PDF" button in OptimizedResumeView to actual navigation | `plan-phases-3-5-6.md` |
| Phase 6 | Make design template picker accessible from OptimizedResumeView | `plan-phases-3-5-6.md` |

---

## What Is Missing / Not Yet Built

- In-app resume section text editing (users cannot edit resume content in-app)
- Hebrew / right-to-left language support
- Resume creation from scratch (currently requires uploading an existing resume)
- Multiple resume management (only one active resume per user)
- App Store submission (not submitted yet)
- External TestFlight testers (not yet opened to external testers)

---

## Auth & Accounts

- Sign in with Apple (primary)
- Anonymous ATS session supported (score check without account)
- JWT stored in Keychain via `KeychainStore.swift`
- Session refreshed on app launch via `AppState.bootstrapAndRefreshSession()`

---

## AI / API

- Backend is a separate Next.js service
- API base URL set via `API_BASE_URL` Info.plist key
- Key endpoints: `/api/ats-score`, `/api/optimize`, `/api/v1/optimizations/[id]`, `/api/v1/chat`, `/api/v1/expert-workflows`, design templates, download/export

---

## Payments

- StoreKit 2 via `StoreKitManager.swift`
- Credits model — users buy credits to run optimizations
- IAP receipt verification via `ReceiptVerifier.swift`
- Paywall in `PaywallView.swift`
