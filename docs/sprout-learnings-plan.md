# What Resumely should learn from Sprout: audit and plan

Date: 2026-11-21. Mode: study and plan only. No code, pricing or App Store Connect change was made.
Source brief: founder's "Brief for Claude Code / Codex" (Sprout competitor study + golf-app second source).
Repos read: iOS `main` at `fbe2e40`; web `new-ResumeBuilder-ai-` at `3a32aea` (2026-11-11), API routes only.

All Sprout figures are founder claims or third-party estimates. Resumely numbers below come from code or from
`Agentic OS/DECISIONS.md` with their date. Anything else is "unknown, need to check in PostHog".

---

## 0. The one-paragraph verdict

Resumely already does the parts of Sprout's playbook that users like, and none of the parts they hate. It is
guest-first: no sign-up wall, free and unlimited Match Score estimates, 3 free PDF exports, a paywall that opens
only on an export after the user has seen their own score and a PDF preview, and a rating prompt only after a
successful export. Sprout's hard paywall would reverse all of that, so do not copy it. What Resumely lacks is a
short first-run intro (it opens straight on the Home check screen), early price transparency, two funnel events,
a small-phone paywall check, and, above all, reach. Fresh PostHog numbers (section 1, A4b): about 4 new real iOS
users a week, and only 3 of 26 new users reached a first check. At that volume no A/B test can finish, so the first
work is ASO and measurement, then a small intro.

## Founder decisions (2026-11-21)

1. Intro: yes, max 2 screens (1 benefit screen + 1 question), clear Skip, only after PR 1 has a baseline.
2. Slogan "לפני הגשה, בודקים התאמה. רזומלי" is approved for the welcome screen.
3. Pricing: keep packs + Pro monthly. No first-month discount for now.
4. Live App Store name is "Resume AI - CV Builder" (id 6776752349). "Resumely: AI Resume Match" is NOT approved; the rename is open. Keywords must not be based on it. Founder will paste live subtitle, keywords and prices.
5. Hebrew: plural form everywhere.
6. Creator referrals: later, after the App Store work.
7. Web: no intro or price line for now. iOS first.

---

## 1. Audit of the current state (Task A)

### A1. Onboarding flow today

There is no onboarding sequence. `OnboardingView` is an auth form (Sign in with Apple + email), shown as a sheet only
when the user taps sign-in.

| # | What the user sees | File |
|---|---|---|
| 1 | Launch, session bootstrap spinner, anonymous Supabase session created | `ResumeBuilder IOS APP/App/RootView.swift:7-22`, `ResumeBuilder_IOS_APPApp.swift:61-63` (`app_launched`, `guest_mode_started`) |
| 2 | Home check screen: language buttons (HE/EN), "Upload your resume for a recruiter-style read", "Try a sample CV" | `Features/V2/Home/HomeTabView.swift:901` (language), `Features/V2/Home/HomeActivationState.swift:37-50`, `Features/V2/Home/SampleCV/SampleCV.swift:30` |
| 3 | Upload CV (file picker or sample) | `HomeTabView.swift:548-590`, `Features/Tailor/TailorViewModel.swift:306` (`cv_uploaded`) |
| 4 | Paste job description or link | `Features/V2/Home/JobInputPolicy.swift`, `HomeTabView.swift:1366-1554` |
| 5 | AI consent sheet (first check only) | `HomeTabView.swift:1643-1650`, `Features/V2/Home/AIConsentSheet.swift` |
| 6 | "Analyzing" loading screen with real pipeline steps | `Features/V2/Home/ResumeOptimizationLoadingView.swift` |
| 7 | Result: optimization review and diagnosis with before/after Match Score estimate | `Features/V2/Home/FirstSessionJourneyRoute.swift:4-24`, `Features/V2/History/OptimizationReviewView.swift` |
| 8 | Optimized tab: PDF preview, export; paywall on a paid export | `Features/V2/Improve/OptimizedResumeView.swift`, `Features/V2/Paywall/ExportPaywallSheet.swift` |
| 9 | Rating prompt after a successful export | `OptimizedResumeView.swift:1512-1516` |

Questions asked before value: none (language is a button, not a question). The fit-check step exists but is off:
`Core/API/BackendConfig.swift:22` `isFitCheckEnabled = false`. Flags are compile-time constants, not remote.

### A2. Paywall

- SDK: native StoreKit 2. No RevenueCat, no Superwall. Delivery is verified server-side (`Core/Payments/StoreKitManager.swift`, `Core/Payments/ReceiptVerifier.swift`, endpoint `iapVerify`).
- Products (`StoreKitManager.swift:9-14`): `resumely.exports.14`, `resumely.exports.5.v2`, `resumely.pro.monthly`. Sale order: 14-pack, 5-pack, Pro.
- Prices: the app shows `product.displayPrice` only. The test config `ResumeBuilder IOS APPTests/Resumely.storekit` has 14 exports $7.99, 5 exports $3.99, Pro monthly $9.99, no introductory offer. **Live prices: needs ASC check.**
- Trial: none. Free tier: 3 free exports per account ("welcome grant", `Core/Payments/ExportCredits.swift:85,122`) and unlimited Match Scores.
- When it opens: only after a server 402 on export, and only once this account has seen its own Match Score and a PDF preview (`Core/Payments/PaywallEligibility.swift:1-47`).
- Sheet content: title, value line, "Match Scores stay free and unlimited.", offers, "Renews monthly until cancelled.", Restore Purchases, Terms, Privacy, estimate footer (`ExportPaywallSheet.swift:4-22, 354-460`).
- Dismiss: X button and swipe; logs `paywall_dismissed`; no follow-up offer (`ExportPaywallSheet.swift:631-680`).
- Layout: `ScrollView` in a `.large` sheet, RTL set explicitly. Small-phone behaviour not verified this session. A DEBUG harness exists: launch argument `--smoke-paywall` (add `--smoke-he`) in `Features/V2/Paywall/PaywallSmokeHarness.swift`.

### A3. Rating request

`@Environment(\.requestReview)` (system API) in `OptimizedResumeView.swift:48`, gated by `Core/Review/ReviewPromptGate.swift:56-71`:
fires only after a completed export, once per app version, never for internal testers. Event `app_store_review_requested`.
Nothing is gated on a rating. This already matches the golf-app rule and is the opposite of Sprout.

### A4. Analytics

PostHog via a custom transport (`Core/Analytics/AnalyticsService.swift:9`, enabled by `BackendConfig.isPostHogEnabled`).
Funnel events that exist and fire: `app_launched`, `guest_mode_started`, `resume_upload_cta_seen`, `resume_file_picker_opened`,
`cv_uploaded`, `job_added`, `analysis_cta_tapped`, `ai_consent_shown/accepted/declined`, `optimization_started/completed`,
`match_score_viewed`, `diagnosis_viewed`, `pdf_preview_viewed`, `paywall_viewed`, `paywall_shown`, `paywall_dismissed`,
`purchase_started/completed/cancelled/failed`, `export_completed`, `app_store_review_requested`.

Correction (2026-11-21): `onboarding_started` does fire, once per new install, through `OnboardingStartedOnce`
(`AnalyticsService.swift:975-1002`, entry `home`). PostHog shows it from 1.6.0 on. The first audit missed the helper.

Gaps:
- No intro or per-screen onboarding events (there are no intro screens yet; they ship with the intro PR).
- No `paywall_offer_selected` (which row the user tapped before buying or leaving).
- No `job_input_seen`: only `job_input_validation_shown` (invalid input) and `job_added` exist, so we cannot tell whether a user who picked a CV ever reached the job step.
- No event for "price disclosed before first use"; it ships with the intro.

### A4b. Fresh baseline (PostHog project 270848, pulled 2026-11-21)

Definition: iOS persons whose first `app_launched` was in the window, `is_internal_tester` false. HogQL, not a saved insight.

New real iOS users per week (Monday start): 09-28: 5, 10-05: 3, 10-12: 2, 10-19: 7, 10-26: 2, 11-02: 4, 11-09: 3, 11-16 (partial): 1.
Last 4 full weeks: 16, so **about 4 a week**. Last 7 full weeks: 26.

First-session funnel, the 26 new users from 2026-09-28 to 2026-11-15 (any time after first launch):

| Step | Event | People | Of arrivals |
|---|---|---|---|
| Opened app | `app_launched` | 26 | 100% |
| Saw upload card | `resume_upload_cta_seen` | 25 | 96% |
| Tapped upload | `resume_upload_cta_tapped` | 11 | 42% |
| Picked a file | `resume_file_selected` | 7 | 27% |
| Job input error shown | `job_input_validation_shown` | 7 | 27% |
| Added a job | `job_added` | 3 | 12% |
| Started first check | `analysis_cta_tapped` / `optimization_started` | 3 | 12% |
| Result ready | `optimization_completed` | 3 | 12% |
| Exported | `export_success` | 3 | 12% |

**Open to first check: 3 of 26 reached it, an 88% drop-off.** The biggest losses: upload card seen to tap (25 to 11),
and file picked to job added (7 to 3). Everyone who started a check also exported. No purchase and no paywall view
in this cohort. Most of these users ran 1.5.x, which predates `match_score_viewed`, `pdf_preview_viewed` and
`paywall_viewed`, so those read 0 here. Numbers this small move a lot from one person; treat them as direction.

### A5. Localization

- Strings in `Resources/Localizable.xcstrings` with Hebrew; paywall strings translated (checked 4 keys).
- Paywall sets `layoutDirection` itself because sheets do not inherit it (`ExportPaywallSheet.swift:432`, lesson 2026-10-19). Any new intro screen or sheet must do the same.
- Polish issue: Hebrew mixes plural ("קבלו עוד הורדות PDF") and masculine singular ("העלה את קורות החיים שלך"). Pick one form; plural is gender-neutral.

### A6. Match Score: can it run as a preview before payment?

It already does, free and unlimited.
- Guest with an anonymous session: full upload + optimize pipeline (`HomeTabView.swift:592-623`, `canOptimize`).
- No session at all: `POST /api/public/ats-check`, rate-limited to 5 checks per IP per 7 days (web `src/app/api/public/ats-check/route.ts:27-28`).
- Cost per score: `scoreResume` uses OpenAI `text-embedding-3-small` (web `src/lib/ats/utils/embeddings.ts:90`) plus a `gpt-4o-mini` quick-wins call (web `src/lib/ats/quick-wins/generator.ts:133`). The optimize path adds the main rewrite call. Latency and cost per check: unknown, need to check in Vercel logs and PostHog (`optimization_completed` timing).

### A7. ASO metadata in the repo (docs only; live values need ASC check)

- EN (`docs/app-store/en-metadata.md`): name "Resume AI - CV Builder"; subtitle options "AI Resume Tailor & Job Match"; keywords `cv builder,job application,cover letter,career,scanner,optimizer,interview,linkedin,job seeker` (94 chars). Problems: "cv builder" repeats title words; multi-word phrases with spaces waste characters; 6 characters unused.
- HE (`docs/app-store/he-metadata.md`): name "Resumely: בונה קורות חיים"; subtitle "קורות חיים מותאמים לכל משרה"; keywords use multi-word phrases with spaces and repeat "קורות חיים" from the name.
- App Preview video: none found in the repo (`docs/aso/2026-10-app-store-asset-publish-checklist.md` mentions the tab only).
- Two scored ASO experiments (`rb-aso-001`, `rb-aso-002`) were logged as never filed in ASC (DECISIONS.md, 2026-09-01). Current status unknown.

---

## 2. Gap map (Task B)

| Sprout / golf pattern | Exists in Resumely? | Recommendation | Why | Effort |
|---|---|---|---|---|
| Play before pay: preview Match Score before paywall | Yes. Free unlimited score, 3 free exports (`PaywallEligibility.swift`, `ExportCredits.swift:85`) | Keep | This is Resumely's edge against Sprout's hard paywall | none |
| Hard paywall right after onboarding | No | Don't adopt | Reverses the edge; top 1-star theme for Sprout; with ~2 arrivals a week nothing would be learned | n/a |
| Early price transparency | Partial. Prices appear only on the paywall | Adapt: one honest line on the intro "how it works" screen | Answers Sprout's "price hidden until after my data" complaint | S |
| Benefit screens between questions | No | Adapt: one benefit screen, not five | Each added screen risks the logged 63% launch bounce | S |
| Short question block (golf: 2 questions) | No questions | Adopt 1 question (job-hunt stage) + existing language choice | Personalizes copy; feeds PostHog segments | S |
| Personalized result screen | Yes. Diagnosis with before/after estimate (`OptimizationReviewView.swift`) | Keep; title it with the user's job | Already the "aha" | S |
| "Analyzing" screen (labor illusion) | Yes, real steps (`ResumeOptimizationLoadingView.swift`) | Keep, no fake delay | Real wait already exists | none |
| CV upload during onboarding | Yes, it is the first action on Home | Keep | | none |
| Sign-up before use | No (guest-first) | Don't adopt | Apple 5.1.1(v) and trust | n/a |
| Paywall on small phone (SE / mini) | Unknown. ScrollView sheet, harness exists | Adopt a check on iPhone SE (3rd gen) EN + HE, large Dynamic Type | Golf founder lost 5 days of sales to overflow | S |
| Win-back / discount on dismiss | No | Don't adopt now | Fake-discount risk; a real one needs an ASC offer and volume to matter | M |
| Weekly / monthly job-hunt plans | Partial. Packs + Pro monthly, no weekly | Founder decision; recommend no weekly | Weekly renewals are Sprout's cancel complaint; packs already fit a short hunt | M |
| Referral (3 friends = credits) | No (Ambassador skeleton removed 2026-11-13) | Later, with creator program | Needs server codes + attribution | L |
| Rating timing | Yes, after export, system API (`ReviewPromptGate.swift`) | Keep | Matches golf rule, beats Sprout | none |
| Forced rating before use | No | Never adopt | Guideline 5.6.1 and trust | n/a |
| Step-by-step funnel analytics | Mostly. Core events and `onboarding_started` fire; no `job_input_seen` or offer-row event | Adopt the 2 missing events | The job step is where the fresh baseline loses most people | S |
| App Preview video | No | Adopt (founder records, ASC upload) | Golf app: downloads doubled at same reach | M |
| ASO name / subtitle / keywords | Docs exist; live needs ASC check | Adopt: fill 100 chars, single words, no title repeats | 79% of golf downloads came from search | S |
| Screenshots: 1 benefit, 2-4 big words | Briefs exist (`launch-assets/aso/screenshot-briefs.md`) | Check against the rule when filing | | S |
| Auto-apply, job feed, Chrome extension, MCP | No | Watch only | Out of scope by brief | n/a |

---

## 3. Proposed first-run flow (Task C.1)

Founder decision 2026-11-21: max 2 intro screens (1 benefit + 1 question), clear Skip, built only after PR 1 has a
baseline. Screens 1 and 3 below merge into one benefit screen (welcome line, slogan in Hebrew, how it works, what is
free); screen 2 keeps only the job-hunt stage question (language stays on Home). Hebrew uses the plural form.
The table below is the original 3-screen draft, kept for the copy.

Rule: a Skip on each screen, one action per screen. Intro shows once (`@AppStorage("intro_completed_v1")`).
New screens go in `Features/V2/Intro/`. Every Match Score mention says estimate / הערכה.

| # | Screen | Goal | English | Hebrew | Event |
|---|---|---|---|---|---|
| 1 | Welcome | Say what it does in one line | "Check how well your CV fits a job before you apply." Button: "Start". Link: "I have an account" | "בודקים כמה קורות החיים מתאימים למשרה, לפני שמגישים." כפתור: "מתחילים". קישור: "יש לי חשבון". Slogan "לפני הגשה, בודקים התאמה. רזומלי" only if approved for in-app use | `onboarding_started {entry}` + `intro_step_viewed {step: welcome}` |
| 2 | Language + stage | Personalize, 1 question | "Which language is your CV in?" (Hebrew / English). "Where are you in your job hunt?" Applying now / Starting soon / Just looking | "באיזו שפה קורות החיים?" (עברית / אנגלית). "איפה אתם בחיפוש העבודה?" מגישים עכשיו / מתחילים בקרוב / רק מסתכלים | `intro_step_viewed {step: profile}`, `intro_answer {question, answer}` |
| 3 | How it works + price | Benefit + early transparency | "1. Upload your CV. 2. Paste a job. 3. Get a Match Score estimate and a tailored CV. Match Score estimates are free. Your first 3 PDF downloads are free. After that, download packs or Pro." Button: "Upload my CV" | "1. מעלים קורות חיים. 2. מדביקים משרה. 3. מקבלים הערכת התאמה וקורות חיים מותאמים. הערכות ההתאמה בחינם. 3 הורדות PDF ראשונות בחינם. אחר כך, חבילות הורדה או Pro." כפתור: "להעלאת קורות חיים" | `intro_step_viewed {step: how}`, `intro_pricing_seen`, `intro_completed {skipped}` |
| 4 | Upload CV / sample (existing) | First action | unchanged | unchanged | existing `cv_uploaded {method}` |
| 5 | Paste job (existing) | | unchanged | unchanged | existing `job_added` |
| 6 | AI consent (existing) | Required | unchanged | unchanged | existing `ai_consent_*` |
| 7 | Analyzing (existing) | Honest wait | unchanged | unchanged | existing `optimization_started` |
| 8 | Result (existing) | Aha: estimate for this job | unchanged | unchanged | existing `match_score_viewed`, `diagnosis_viewed` |
| 9 | Preview, export, paywall on 4th export (existing) | | unchanged | unchanged | existing + new `paywall_offer_selected` |
| 10 | Rating after export (existing) | | unchanged | unchanged | existing `app_store_review_requested` |

The "3 free" number and the product names in screen 3 are UNVERIFIED against live server config; read them from
the credits endpoint or confirm before shipping. No price figures on the intro: amounts stay on the paywall where
`displayPrice` is live.

---

## 4. Paywall plan (Task C.2, recommendation only)

- Timing: keep the export gate. Do not move it before first use.
- Transparency: intro screen 3 states what is free and what is paid; the paywall keeps "Match Scores stay free and unlimited."
- Small phone: run `--smoke-paywall` and `--smoke-paywall --smoke-he` on iPhone SE (3rd gen) at default and XL Dynamic Type. Pass = price, period, Continue, Restore, Terms and Privacy reachable, and Continue visible without scrolling. If not, pin Continue in a bottom bar.
- Dismiss: keep a plain close. No discount on dismiss now. If later wanted, use a real ASC introductory offer on Pro, never an inflated anchor.
- Pricing options for Nadav (no change made):
  1. Keep packs + Pro monthly; reframe copy around a job hunt ("for your job hunt"). Recommended now: no volume to test against.
  2. Add an ASC introductory offer on Pro monthly (first month lower). Real price, Apple shows terms. Test only after paywall views reach the threshold in section 6.
  3. Weekly Pro. Not recommended: Sprout's weekly renewals drive its cancel and refund complaints.
  4. A ~20% price rise test (Sprout claim). Only after option 1 has a baseline.

---

## 5. Success metrics and how to read them in PostHog (Task C.3)

Exclude internal testers (existing internal flag) in every insight. Unique persons, 30-day window.

| Metric | Definition | PostHog insight |
|---|---|---|
| Intro completion | `intro_completed` / `onboarding_started` | Funnel, 2 steps |
| Activation | `match_score_viewed {source: own}` / `app_launched` (first time) | Funnel: `app_launched` → `cv_uploaded` → `job_added` → `match_score_viewed` |
| Export | `export_completed` / `match_score_viewed` | Funnel |
| Paywall conversion | `purchase_completed` / `paywall_viewed` | Funnel, breakdown by `paywall_offer_selected.product_id` |
| 7-day retention | Returned with `app_launched` or `match_score_viewed` on days 1-7 after first `match_score_viewed` | Retention insight |
| Trial conversion | No trial exists | n/a |

Baselines for all rows: unknown, need to check in PostHog before PR 3 ships.

---

## 6. Experiment plan (Task C.4)

A/B testing is not possible at current volume. Detecting a 10-point change from a 50% baseline needs about 400 people
per arm; at the fresh ~4 new users a week (A4b) that takes about 4 years. So:

- Method: before/after with fixed windows. Baseline 4 weeks before the intro ships, compare 4 weeks after.
- Minimum before reading: 30 people reach `onboarding_started`, or 6 weeks, whichever comes first.
- Decide only on large effects: intro kept if launch → `cv_uploaded` does not drop more than 10 points against baseline.
- Stop criteria: launch → `cv_uploaded` falls by more than 15 points in the first 2 weeks with at least 15 people, a crash in the intro, or an App Review rejection. Turn the intro off with its flag and ship a hotfix (flags are compile-time, so a build is needed).
- A/B on paywall pricing: only once `paywall_viewed` reaches about 100 unique persons a month.
- Reach work (ASO, App Preview video) is measured in App Store Connect analytics (impressions, product page views, conversion), not PostHog.

---

## 7. Small PRs (drafts, not opened) (Task C.5)

| PR | Scope | Files | Risk | Test | Review tier |
|---|---|---|---|---|---|
| 1. Funnel events | Add `job_input_seen` and `paywall_offer_selected`. (`onboarding_started` already fires; intro events ship with PR 4.) | `Core/Analytics/AnalyticsService.swift`, `Features/V2/Home/HomeTabView.swift`, `Features/V2/Paywall/ExportPaywallSheet.swift`, `ResumeBuilder IOS APPTests/AnalyticsServiceTests.swift` | Low; no PII in properties | Unit tests for names and properties | 1 |
| 2. Paywall small-phone pass | SE + HE + XL type check; pin Continue only if it fails | `Features/V2/Paywall/ExportPaywallSheet.swift` (only if needed) | Purchase path untouched; layout only | Simulator screenshots via `--smoke-paywall`, existing paywall tests | 1 (2 if purchase code changes) |
| 3. ASO refresh (docs + founder ASC action) | EN keywords `tailor,match,job,application,cover,letter,career,scanner,optimizer,interview,linkedin,seeker,hebrew` (99 chars); HE keywords `קורות,חיים,משרה,עבודה,מועמדות,מכתב,מקדים,התאמה,ציון,מגייס,ראיון,קריירה,לינקדאין,כתיבת,שכתוב` (91 chars; check whether ASC counts bytes); App Preview video brief; file `rb-aso-001/002` | `docs/app-store/en-metadata.md`, `docs/app-store/he-metadata.md`, `launch-assets/aso/screenshot-briefs.md` | Keyword repeats with live name; Hebrew byte limit | ASC field counter after paste; read-back | 0 |
| 4. Intro flow (after PR 1 baseline) | 3 screens from section 3, Skip on each, shown once, behind a flag | new `Features/V2/Intro/IntroFlowView.swift`, `IntroFlowViewModel.swift`, `IntroCopy.swift`; `App/RootView.swift`; `Core/API/BackendConfig.swift`; `Resources/Localizable.xcstrings`; new `IntroFlowViewModelTests.swift` | Adds a step before the logged biggest cliff; RTL in sheets | VM tests (shown once, skip, answers tracked), EN + HE simulator smoke, iPhone SE | 1 |
| 5. Pricing (decision-gated) | Only after Nadav picks a section 4 option | ASC config, paywall copy | Money | Sandbox purchase, StoreKit tests | 2 |

---

## 8. Risks (Task C.6)

- App Store 3.1.2: price, period, auto-renew and terms visible before purchase. The paywall shows `displayPrice`, "Renews monthly until cancelled.", Restore, Terms, Privacy. Keep all of it in view on small phones (PR 2).
- App Store 5.6.1: ratings only through the system prompt, never gated. Current code complies; keep it.
- App Store 5.1.1(v): do not require sign-up for non-account features. Guest-first complies; Sprout's sign-up-first pattern would not fit.
- "Free" claims: say exactly what is free (estimates, first 3 PDFs). Confirm the 3 against the server.
- Trust: no fake discounts, no weekly renewals by surprise, no job-outcome promises; the Match Score is always called an estimate (DECISIONS.md, Resumely Match Score rule).
- RTL: new screens and sheets must set `layoutDirection`; pick one Hebrew grammatical form.
- Funnel: any screen before upload can raise the logged 63% launch bounce. Hence max 3 screens, Skip, and the stop rule.

---

## 9. Open questions for Nadav (Task C.7)

Answered 2026-11-21; see "Founder decisions" at the top. Still open: live subtitle, keywords and prices (founder to
paste), and the app rename. Original questions kept below for the record.

1. May the intro add up to 3 screens before the first check, given launch to first check is the biggest logged drop-off?
2. Is "לפני הגשה, בודקים התאמה. רזומלי" approved for the in-app welcome screen?
3. Pricing: keep packs + Pro monthly (recommended), or plan an introductory offer on Pro?
4. What are the live ASC name, subtitle, keywords and prices? This audit read only repo docs and the test StoreKit file.
5. Hebrew form: plural (gender-neutral) everywhere?
6. Creator program: should the product get referral codes and attribution deep links now, or after reach work?
7. Should the web app get the same intro and transparency line?
