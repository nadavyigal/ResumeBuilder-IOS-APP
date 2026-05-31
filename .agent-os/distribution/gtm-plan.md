---
type: gtm-plan
product: ResumeBuilder iOS
version: v1.0 build 1 (pre-submission)
inherited_from: new-ResumeBuilder-ai-/docs/gtm/canonical-90-day-plan.md
status: draft
created: 2026-05-27
last_updated: 2026-05-27
owner: founder
---

# GTM Plan — ResumeBuilder iOS (Resumely)

## 0. Inheritance Map

Source: `new-ResumeBuilder-ai-/docs/gtm/canonical-90-day-plan.md` (dated 2026-02-14)

| Block | Web source | iOS treatment |
|---|---|---|
| Positioning one-liner | canonical-90-day-plan.md North Star | carry with edit — App Store subtitle is 30-char tighter derivative |
| Audience segments | canonical-90-day-plan.md implicitly | carry as-is — same job seekers; commute/mobile behavior emphasized |
| Job-to-be-done | canonical-90-day-plan.md Awareness message | carry as-is |
| Messaging architecture | canonical-90-day-plan.md Messaging | carry with edit — paywall framing shifts from subscription CTA to credit-pack CTA |
| Hebrew variant | week-1-marketing-message-bank-en-he.md | carry with edit — iOS-specific Hebrew metadata not yet authored |
| Pricing | Web uses Stripe; iOS uses credit packs (IAP) | DIVERGENCE — blocking question — see section 7 |
| Core funnel loop | Content → Free ATS Check → Signup | carry with edit — web signup flips to App Store install; ATS result page CTA must change |
| Email lifecycle (5-email sequence) | canonical-90-day-plan.md Email | carry with edit — iOS needs post-install variant; web post-signup sequence is separate |
| Social distribution playbook | week-1-social-copy-pack.md | carry as-is — CTA on posts flips to App Store install once iOS is live |
| Programmatic SEO | canonical-90-day-plan.md Programmatic SEO | carry with edit — mobile CTA must point to App Store, not web signup |
| ASO | not in web GTM | net new — Tier A on iOS |
| Directory submissions | distribution-os/projects/resumebuilder.md | net new — App Store URL must be in every pack |
| App Store launch model | not in web GTM | net new |
| Attribution tagging (at=/ct=) | not wired | net new — must be added before web feeder channels go live |
| CRO backlog (web surfaces) | canonical-90-day-plan.md CRO | drop — iOS CRO is onboarding to first export, not web hero/paywall |

Carry count: 6 | Edit count: 7 | Drop count: 1 | Net new count: 4

---

## 1. One-Line Positioning

- **One-liner**: Resumely is the mobile resume workspace that tailors your resume to any job posting and catches ATS blockers before you apply.
- **App Store subtitle (30 chars)**: `<fill>` — candidate: "AI Resume Tailor & ATS Check"
- **Web hero headline**: "See how recruiter systems read your resume before you apply." (from web GTM — carry as-is)

---

## 2. Audience Segments

| Segment | Description | iOS-likely | Web-likely | Trigger | Where to reach |
|---|---|---|---|---|---|
| A — Active mobile job seeker | Applying from phone during commute, lunch, between interviews | High | Medium | Job posting seen on LinkedIn or job board app | App Store search, LinkedIn posts, directory listings |
| B — Career switcher | Updating a stale resume for a new field | Medium | High | Career change decision, often desktop research | Web landing with App Store CTA; SEO articles |
| C — Hebrew-speaking job seeker | Israeli professionals applying to English or Hebrew-language roles | High | Medium | Same trigger as A, Hebrew-language context | Hebrew App Store metadata, Hebrew community posts |
| D — Resume polisher | Has a resume, wants a tailored version for a specific role fast | High | Medium | Specific job posting in hand | App Store search: "resume tailor" / "ATS resume" |

---

## 3. Job To Be Done

"I have a job posting in front of me and I want to know — quickly, on my phone — whether my resume will make it past the ATS filter and what to fix before I apply."

---

## 4. Before / After

- **Before**: User runs a manual comparison, guesses at keyword gaps, submits the same resume everywhere, gets no callbacks.
- **After**: User pastes the job posting, sees the exact blockers, applies one-tap fixes, exports a tailored PDF in minutes, applies with confidence.

---

## 5. Differentiators

| Differentiator | Earned | Mobile-specific |
|---|---|---|
| ATS-aware optimization tied to a specific job posting | Yes — core product flow | Yes — paste-a-posting on iPhone is the hero interaction |
| Hebrew-authored content (not auto-translated) | Partially — web has EN/HE; iOS strings not yet authored | Yes — Hebrew App Store metadata will be authored |
| Instant tailoring without uploading to another service | Yes — same backend as web | Yes — no laptop needed |
| Templates that actually parse (PDF export via WKWebView) | Yes — tested in progress.md | Yes — export from phone |

---

## 6. Anti-Positioning

- Not a generic resume builder — a resume tailor; job-specific output is the point
- Not a career coach — no human in the loop
- Not a subscription product on iOS — credit packs; pay per batch of tailoring work
- Not a desktop tool ported to mobile — mobile is the primary surface
- Not a translation tool — Hebrew content is authored for native speakers

---

## 7. Pricing

**HARD CHECKPOINT — partial blocking question. Founder confirmation required.**

| Axis | Web | iOS |
|---|---|---|
| Model | Unknown from source — Stripe is wired; no price found in codebase | Credit packs (one-time IAP) — `credits_basic`, `credits_saver`, `credits_super` |
| Model | Web: freemium + paid upgrade (Stripe) | **iOS: FREE at launch** — confirmed by founder 2026-05-28; no paywall |
| Launch price | Free tier has limited features; paid upgrade via Stripe | **Free** — App Store price tier: Free |
| Paid tier | Stripe upgrade available | Deferred to next stage; IAP scaffold exists but inactive |
| Prices | Web paid price points `<fill — Stripe dashboard>` | None at launch |
| Trial | N/A | N/A |
| Cross-platform restore | Freemium account (email sign-in) | N/A at launch — all features free on iOS; pricing parity not yet relevant |
| Family Sharing | N/A | N/A |
| Regional pricing | `<fill>` | Free universally at launch |
| Apple's cut | N/A | N/A at launch |
| Cancellation / refund | Stripe | N/A at launch |

**Pricing decision (2026-05-28)**: iOS launches free. No IAP, no paywall, no StoreKit at launch. Pricing comes in a future stage. This simplifies the App Store listing (no IAP products to configure, no pricing copy needed), removes the cross-platform restore blocker, and lets the team focus on activation and ASO before monetisation.

---

## 8. Channels

| Tier | Channel | iOS notes |
|---|---|---|
| A | App Store Optimization | Pre-submission; English listing must be written from scratch; Hebrew metadata as close T+30 follow |
| A | Web landing to App Store CTA | All web landings need mobile-detect + App Store CTA; `at=`/`ct=` attribution not yet wired |
| A | Free ATS / resume scoring tool (web) | Exists in web GTM; result page CTA must flip to App Store on iOS; not yet confirmed wired |
| A | Directory submissions (with App Store URL) | Pack does not exist; App Store URL not available until listing is live |
| A | Lifecycle email (post-install) | Not started; no email platform wired to iOS events |
| A | Conversion review (iOS onboarding to first export) | Most leveraged surface; no analytics wired yet |
| A | Hebrew market (App Store metadata + landing) | Hebrew not yet authored on iOS; launch English-only then Hebrew at T+30 |
| B | Programmatic SEO with App Store CTA | Carry from web; mobile CTA swap required; Tier B until ASO + landings prove |
| B | Career coach + HR partnerships | Carry from web; include App Store URL in outreach kit |
| C | LinkedIn founder updates | Carry from web; add App Store link once listing is live |

Killed / not in scope:
- Apple Search Ads — out of scope per founder constraint; re-evaluate after 90 days of organic ASO data
- Daily social media — LinkedIn only, low-frequency, carry from web playbook

---

## 9. Acquisition Funnel

```
App Store search (ASO organic)
  → App Store listing
    → install

Web landing (mobile device, iOS detected)
  → App Store CTA (at=X, ct=web-{page-slug})
    → App Store listing
      → install

Free ATS tool result (mobile)
  → App Store CTA above the fold
    → App Store listing
      → install

Directory listing (with App Store URL)
  → App Store listing
    → install
```

Source share targets (to be set after first 30 days of data):
- ASO organic: ~50%
- Web feeder: ~30%
- Directory referrals: ~10%
- Other / direct: ~10%

---

## 10. Activation Funnel (Post-Install)

```
install
  → first open
    → sign in (Apple or email)
      → onboarding complete
        → PDF upload
          → ATS score viewed
            → optimization run
              → first resume exported  ← ACTIVATION EVENT
```

- **Activation event**: `first_resume_exported`
- **Target activation rate**: `<fill after first cohort>`
- **Current activation rate**: unknown — no analytics wired

---

## 11. Retention Funnel

- Day 1: exported at least one resume
- Day 7: returned to tailor for a new job posting
- Day 30: used credits more than once OR returned after initial batch
- Cohort weekly retention target: `<fill after first 30 days>`

---

## 12. Lifecycle Program (Post-Install)

See `lifecycle-program.md` for full stage list.

Stages this GTM relies on:
- Welcome (post-install + account creation): NOT STARTED
- Didn't-start-in-24h push: NOT STARTED — PushService.swift scaffolded; no delivery platform wired
- Activation hit (first export): NOT STARTED
- 14-day return: NOT STARTED
- Pre-paid offer / credit reminder: NOT STARTED — requires IAP to be live first

Web 5-email sequence (post web-signup) continues unchanged. iOS lifecycle is a separate track triggered by app events.

---

## 13. Launch Model

App Store review and release cycle.

- **Cadence**: patches as needed; minor versions monthly; major version (V2) quarterly or feature-milestone
- **Marketing push triggers**:
  1. App Store Live (V1.0) — first full marketing push
  2. Hebrew metadata live — secondary push to Hebrew market
  3. V1.x with a major feature — LinkedIn + email to existing users
- **V1.0 launch sequence**:
  - T-7: prepare listing (screenshots, copy), wire web App Store CTAs
  - T-3: submit to App Store review
  - T-0: approve and release; flip web feeder CTAs; submit to top-5 directories
  - T+1: LinkedIn founder update (EN + HE)
  - T+7: first ASO keyword check; collect early review data
  - T+14: iterate listing based on keyword data and reviews
- **Channels per launch**: ASO refresh, web hero update, LinkedIn post (EN + HE), top-5 directory submissions

---

## 14. Metrics And Targets

### 90-day targets (App Store live + first distribution cycle)

| Metric | Current | 90-day target |
|---|---|---|
| App Store impressions | 0 (not live) | `<set after listing goes live>` |
| App Store page views | 0 | `<fill>` |
| Installs | 0 | `<fill>` |
| Install conversion rate (page view to install) | — | > 30% |
| Activation rate (install to first export) | — | `<fill after first cohort>` |
| Day-7 retention | — | `<fill>` |
| Credits purchased | 0 | `<fill — after IAP live>` |

### 180-day targets

| Metric | Current | 180-day target |
|---|---|---|
| Monthly active users | 0 | `<fill>` |
| Paid conversion rate | 0 | `<fill>` |
| Hebrew market installs | 0 | `<fill>` |

---

## 15. Risks And Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| App Store review rejection | Medium | High | Follow readiness checklist; privacy policy must be live before submit |
| IAP not live at submission | High | High | Parked StoreKit must be activated and sandbox-tested on device |
| Hebrew metadata not authored at launch | High | Medium | Launch English-only first; Hebrew as T+30 milestone |
| No analytics at launch | High | Medium | Wire PostHog iOS SDK before first submit |
| Web CTAs still pointing to web signup on iOS | High | High | Attribution wiring is Tier A blocker before feeder channels go live |
| Cross-platform pricing confusion | High | Medium | Resolve divergence explicitly before writing App Store description |
| ATS parser claims on iOS vs web | Low | High | iOS calls same backend; claims are accurate; do not claim iOS-only features that are web-only |
| No Hebrew/RTL in iOS app | High | Medium | Do not claim Hebrew in-app experience until RTL is implemented |

---

## 16. Open Questions

| Question | Blocking? | Owner | Resolution path |
|---|---|---|---|
| Web pricing model | ~~Blocking~~ RESOLVED | — | Freemium + paid upgrade (Stripe) — confirmed 2026-05-28 |
| iOS launch pricing | ~~Blocking~~ RESOLVED | — | **Free at launch** — confirmed 2026-05-28; pricing deferred to next stage |
| iOS credit pack prices | ~~Blocking~~ RESOLVED | — | N/A at launch; IAP inactive |
| Cross-platform restore mechanism | ~~Blocking~~ RESOLVED | — | N/A at launch; revisit when iOS pricing stage begins |
| App name | ~~Blocking~~ RESOLVED | — | **Resumely** — confirmed 2026-05-28 |
| Apple Developer account region | Medium | Founder | Check App Store Connect account settings |
| Hebrew App Store approach | ~~Blocking~~ RESOLVED | — | Single listing with Hebrew locale added — confirmed 2026-05-28 |
| Free ATS tool result page iOS CTA | High — Tier A blocker | Engineering | **Confirmed web shows signup CTA only** — must add App Store CTA with `ct=ats-tool-result` before web feeder channel goes live |
| Apple Search Ads | ~~Blocking~~ RESOLVED | — | Out of scope — confirmed 2026-05-28 |

---

## 17. Decision Log

Append-only.

- 2026-05-27: Distribution OS installed for ResumeBuilder iOS — GTM v0 drafted from `canonical-90-day-plan.md`; open questions captured in section 16
- 2026-05-27: App Store status — pre-submission confirmed from tasks/progress.md; phase "TestFlight prep"; "No App Store submission yet"
- 2026-05-27: iOS pricing model — credit packs (one-time IAP) confirmed from StoreKitManager.swift product IDs `credits_basic`, `credits_saver`, `credits_super`; monetization parked pending BackendConfig.isMonetizationEnabled
- 2026-05-27: Hebrew on iOS — not yet implemented; no Hebrew .lproj files; progress.md explicitly flags "no Hebrew/RTL support" as a risk
- 2026-05-27: ATS parser parity — iOS calls same web backend endpoints; no separate local parser; claims are defensible
- 2026-05-27: Apple attribution (at=/ct=) — NOT wired anywhere; flagged as Tier A pre-launch blocker
- 2026-05-27: Free ATS tool App Store CTA — not yet confirmed; flagged for founder verification
- 2026-05-27: Apple Search Ads — out of scope per distribution-context.md founder constraint; re-evaluate after 90 days organic ASO
- 2026-05-28: App Store status CONFIRMED by founder — pre-submission; TestFlight prep in progress
- 2026-05-28: iOS pricing model CONFIRMED by founder — credit packs (one-time IAP); not subscription
- 2026-05-28: Web pricing model CONFIRMED by founder — freemium + paid upgrade (Stripe)
- 2026-05-28: iOS launch pricing CONFIRMED by founder — **free at launch**; no IAP, no paywall; pricing deferred to next stage; simplifies listing and removes cross-platform restore blocker
- 2026-05-28: App name CONFIRMED by founder — **Resumely**; unblocks all ASO copy work
- 2026-05-28: Hebrew App Store approach CONFIRMED by founder — single listing with Hebrew locale added (not a separate listing)
- 2026-05-28: Free ATS tool result page iOS CTA CONFIRMED by founder — currently shows web signup CTA only; App Store CTA not wired; this is a confirmed Tier A blocker for web feeder channel
- 2026-05-28: Apple Search Ads CONFIRMED out of scope by founder — re-evaluate after 90 days organic ASO data
