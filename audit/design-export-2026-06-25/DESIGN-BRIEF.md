# Resumely iOS — Design Improvement Brief

- Date: 2026-06-25
- Source audit: `../product-design-resumebuilder-ios-2026-06-16/audit-notes.md`
- Latitude: **Bold reimagining welcome** (still native iOS, still implementable in SwiftUI)
- Owner: founder (Nadav). Designs come back here for SwiftUI implementation.

---

## 1. The product

**Resumely** is an iOS app that helps job seekers tailor and optimize their resume to a specific job posting. The promise on the first screen today: *"Upload, match to a job, and get your first diagnosis in under 2 minutes."*

**Core flow:** guest opens app → **upload resume** (PDF or DOCX) → **add a job** (paste the description or a URL) → **ATS / Fit check** → **optimize** → **diagnosis** → **improve** → **export PDF / submit package**. Signed-in users hit a "Fit-First" verdict (Strong / Stretch / Skip) before optimizing.

**Navigation:** 5 tabs on a custom dark bottom tab bar — **Home, Optimized, Design, Expert, Me**. Optimized / Design / Expert are *locked* until the user has optimized a resume.

---

## 2. The business problem this redesign must serve

This is not a cosmetic refresh. The app has an **activation problem**:

- Over a recent 2-week window: **~0 confirmed organic D7-activated users.**
- The single biggest measurable leak is **"guest opens app → resume uploaded"** — roughly **26 guest starts → 5 uploads, an ~81% drop.** Most users *never get their resume into the app at all.*
- Therefore the **#1 job of this redesign:** make the first run — *getting a resume in and reaching the first "aha" (a diagnosis / score)* — feel effortless, motivating, and obviously valuable. Everything else is secondary.
- Secondary jobs: make the locked/empty tabs *sell the reward* so users push through; fix trust-damaging polish (especially mixed-language Me screen).

**Design north star:** a first-time user with a resume somewhere on their phone should reach their first ATS/fit result in well under 2 minutes, and never hit a dead end.

---

## 3. Audience

Job seekers, mobile-first, often mid-application and stressed. Their resume is frequently in iCloud Drive, Downloads, Gmail, or as a Word `.docx` — **not** necessarily a tidy local PDF. A meaningful subset are Hebrew speakers (RTL).

---

## 4. Platform & constraints (so designs are implementable)

- Native **iOS / SwiftUI**, iPhone. **Dark mode is the brand.**
- Must respect: **Dynamic Type**, safe areas, **VoiceOver**, **Hebrew RTL**, reduced motion.
- Bottom nav stays a bottom tab bar (it can be restyled, but it stays bottom-nav).
- Use the brand tokens in `DESIGN-TOKENS.md`. You may evolve them, but say so explicitly and keep the app recognizable (no full rebrand).
- Standard iOS components / SwiftUI only — assume **no new third-party UI frameworks**.
- Anything that needs new backend data or endpoints must be flagged (the team will scope it separately).

---

## 5. Screens to redesign (in priority order)

### Priority 1 — activation-critical

#### Screen A. Home / first run — `01-home-entry.jpg`
**Current:** a step-based layout — (1) Upload Resume, (2) Add Job, (3) Free ATS Check — with a strong product promise at the top.
**Problems (audit risks #1, accessibility #1 & #4):** the bottom tab bar overlaps / visually competes with the "Free ATS Check" step, so the actionable third step is partly hidden at rest; muted gray helper text on dark cards risks low contrast.
**Goals:** the path must be unmistakable and *fully visible above the tab bar*; "upload your resume" should be the single most obvious next action; raise motivation (why upload → what you get).
**Bold invitation:** question whether a 3-step stack is even the right first-run model. Consider an upload-first hero, a guided single-focus flow, or a progressive checklist — whatever most reliably gets a resume in.

#### Screen B. Upload entry / file picking — `02-upload-file-picker-empty-recents.jpg`
**Current:** tapping Upload opens the iOS Files picker, which can land on an empty "No Recents" with zero app guidance. (The picker now accepts **PDF and DOCX**.)
**Problems (audit risk #2):** a user whose resume lives in Downloads / iCloud / Gmail / Word gets no hint about where to look or what a valid file is — this is a dead-end, and it's exactly where most users drop.
**Goals:** an app-level moment around the file pick that (a) reassures what files work (PDF/DOCX, size limit), (b) hints where resumes usually live, (c) offers a path forward when there's no obvious file.
**Bold invitation:** this is the highest-leverage screen. Consider non-file routes to a first result — paste resume text, "I don't have a resume yet" path, or a sample/demo — so the funnel never dead-ends on "file not found."

### Priority 2 — motivation / push-through

#### Screen C. Locked tabs — Optimized / Design / Expert — `03-optimized-empty-state.jpg`, `04-design-locked-state.jpg`, `05-expert-locked-state.jpg`
**Current:** each locked tab explains the gate ("optimize on Home first") and offers a generic **"Go to Home"** button.
**Problems (audit risks #3 & #4):** they undersell the reward — no preview of the optimized resume, template choices, ATS fixes, cover letter, or submit package; repeated identical "Go to Home" adds navigation without telling the user *which input is still missing*.
**Goals:** turn each locked state into a *motivating teaser* of its value (a compact preview of the eventual output) and replace the generic CTA with a specific next-input prompt (e.g. "Add your resume + a job to unlock").
**Bold invitation:** reconsider whether these should even be separate locked tabs during first-run, or progressive reveals that appear once relevant.

### Priority 3 — trust / polish

#### Screen D. Me / account — `06-me-mixed-language-rtl-state.jpg`
**Current:** guest state with good trust/privacy copy, but **mixed English + Hebrew + RTL/LTR** in the same view.
**Problems (audit risk #5, accessibility #3):** inconsistent language and tab order reads as unfinished — particularly damaging in a trust-sensitive resume product.
**Goals:** a clean, consistent Me/account screen (one language direction at a time), strong trust framing (privacy, what happens to resume data), and a clear guest → sign-in value proposition (why make an account).

---

## 6. Cross-cutting requirements

- **Accessibility:** primary content must clear the tab bar at all Dynamic Type sizes; secondary text needs sufficient contrast on dark cards; all controls labeled for VoiceOver.
- **Motivation/copy:** every empty or locked state must answer two questions — *"what do I get?"* and *"what's my next single tap?"*
- **RTL:** the design must mirror cleanly for Hebrew; call out anything that won't.

---

## 7. What "bold" means here

You're invited to rethink layout, hierarchy, and visual drama — motion, depth, gradient use, type scale, illustration — as long as it stays **native iOS** and **implementable in SwiftUI**. Non-negotiables:

1. First-run **upload → first result** must get *easier*, not just prettier.
2. Stay **dark-brand-recognizable** (evolve the system; don't require a full rebrand).
3. Respect **Dynamic Type, RTL, VoiceOver, reduced motion.**

---

## 8. What to bring back (return format)

For **each** redesigned screen, deliver:

1. **A hi-fi mockup** of the bold direction (a safer fallback variant is optional and welcome).
2. **A short rationale** — what problem it solves, what changed, why.
3. **Implementation notes** — layout structure (stacks/sections), spacing, which tokens are used, any new component, and motion intent.
4. **New copy strings** (English; flag where Hebrew/RTL needs a mirrored layout).
5. **Flags** — anything needing new backend data, endpoints, or assets.

Prioritize **Screen A (Home)** and **Screen B (Upload)** — they are the activation bottleneck. Drop returns into `returns/` in this folder (or paste them back into the chat) and implementation will proceed **one screen at a time, activation-critical screens first.**
