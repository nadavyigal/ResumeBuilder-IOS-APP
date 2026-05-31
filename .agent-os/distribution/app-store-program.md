# ResumeBuilder iOS — App Store Program

Primary acquisition surface. Use `marketingskills/skills/aso/SKILL.md` for every audit and rewrite.

## Current State

Audited: 2026-05-27. Source: readiness checklist, progress.md, StoreKitManager.swift.

- App name: **Resumely** — confirmed by founder 2026-05-28
- Subtitle: `<fill>` — not yet authored; 30-char limit
- Promotional text: `<fill>` — not yet authored; 170-char limit
- Keywords (100 chars total): draft only — "resume, ATS, job, AI, optimizer, career" (from readiness checklist); full optimized 100-char string not yet written
- Description (4000 chars): `<fill>` — not yet written
- Categories (Primary / Secondary): Productivity / Business (from readiness checklist)
- Screenshots: `<fill>` — not yet created; checklist requires iPhone 6.7" + 6.5" minimum; tabs to show: Score, Tailor, Design, PDF export, Profile
- App preview video: not yet / no URL
- In-app purchase tiles: none at launch — **free app, no paywall** (confirmed by founder 2026-05-28); IAP deferred to next stage; StoreKit scaffold (`credits_basic`, `credits_saver`, `credits_super`) remains in code but inactive

### App Store Listing Status
- **Submission state**: Pre-submission (tasks/progress.md: "No App Store submission yet", phase "TestFlight prep")
- **English metadata**: entirely `<fill>` — name, subtitle, keywords, description, screenshots all needed
- **Hebrew metadata**: entirely `<fill>` — no Hebrew .lproj files exist; progress.md flags "no Hebrew/RTL support" as a risk

### IAP / Pricing Status
- **Launch model: FREE** — confirmed by founder 2026-05-28; no paywall at launch
- Pricing deferred to next stage
- IAP scaffold in code (`credits_basic`, `credits_saver`, `credits_super`) remains but is inactive
- App Store price tier: Free

## Tracked Keyword Themes

- ai resume
- ats resume
- resume builder
- resume maker
- job application
- cv builder
- resume scanner
- ats checker
- cover letter
- resume tailor

## Localization

- English (US) — primary
- Hebrew (he) — authored, not translated
- (add others if expanded)

Each locale gets its own:
- App name suffix or alternate
- Subtitle
- Keyword set
- Description
- Screenshot caption set
- Screenshots if visuals differ

## Quarterly ASO Tasks

- Audit listing against `marketingskills/skills/aso/SKILL.md` checklist
- Re-rank tracked keywords (top 10 priority); rotate in 2 new candidates
- Refresh screenshots if positioning or UI shifted
- Update "what's new" with every release
- Compare against Teal, Rezi, Kickresume listings
- Hebrew metadata refresh

## Web → App Store Attribution

Web landings link to App Store with attribution tags:

- `at=` — affiliate token (founder's iTunes affiliate)
- `ct=` — campaign token (e.g., `ct=web-ats-builder`, `ct=ats-tool-result`)
- `pt=` — provider token (optional)

Capture `ct` value per page so we can attribute installs to channel.

## Free ATS Tool Handoff

The free ATS tool result page is a major install driver. Required on the result page:

- One primary App Store CTA above the fold (after the score)
- Mobile detection: iOS → App Store; other → web signup fallback
- A specific benefit attached: "Re-tailor for any role in the app"
- No email gating before the score is shown

## Review Response Policy

- Reply to every 4 / 5-star review with a personal note
- Reply to 1 / 2-star reviews factually, never defensively
- Aggregate review themes monthly; promote to `lessons.md` if cross-product
- Surface in next release what the reviews asked for (and say so in "what's new")

## Apple Search Ads

Out of scope by default per founder constraint (no paid ads). Re-evaluate only after organic ASO proves on tracked keywords for 90 days.

## Open ASO Questions

- App Store listing status: pre-submission confirmed from repo; TestFlight not yet submitted (founder to confirm if TestFlight build was submitted to Apple)
- Apple Developer account region: US? Israel? Affects pricing display + tax — unknown, founder to confirm
- iPad screenshots required this release? Unknown — checklist says "if iPad is supported"; check app target capabilities
- Are integration partners (LinkedIn, job boards, ATS systems) listed in description for ranking? To be added when description is written
- Credit pack prices: must be set in App Store Connect before submission; `credits_basic`, `credits_saver`, `credits_super` product IDs ready in code
- Web → App Store `at=` / `ct=` attribution: NOT wired (see assets-needed.md — top priority)
