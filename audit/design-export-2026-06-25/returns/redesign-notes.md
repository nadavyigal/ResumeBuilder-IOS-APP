# Resumely — Activation Redesign: Return Notes

Source: `Resumely Redesign.dc.html` (claude.ai design project "Resumely iOS design improvement", pulled 2026-06-25). 16 screens, all native-iOS/SwiftUI implementable, all reuse the existing brand tokens (no rebrand). Brand gradient confirmed unchanged: `#6C63FF → #4EA8FF → #40E0D0`. Glass cards: 16px radius, navy `#050814` base.

Global token note from the design file: body/helper text bumped to white 72% / 50% (up from the audit-flagged 60%/35%) for WCAG AA — apply this contrast bump everywhere these screens touch shared text styles.

---

## A — Home · first run (upload-first hero)

**Why:** Old 3-step stack pushed step 3 (ATS Check) behind the tab bar and split attention across two empty inputs. New model: upload is the single dominant target; "Add job" / "ATS score" shrink to a 3-chip progress path. All content clears the 100pt tab-bar zone.

**Layout:** VStack(spacing:16) in ScrollView, page padding 20. Hero = glass card (radius 20) wrapping a dashed-stroke drop zone. Primary button = brand gradient, radius 14. Progress path = HStack of 3 equal chips (numbered circle + label), current step highlighted with sky tint, future steps muted. Motion: hero glow pulses subtly on appear; respect reduced-motion.

**Copy:** H1 "See your résumé like a recruiter does" / sub "Upload, match to a job, and get your first diagnosis in under 2 minutes." / drop-zone "Upload your résumé — PDF or DOCX · up to 5 MB" / button "Choose a file" / motivation strip "See what a recruiter notices in the first 7 seconds — then fix it." Progress chips: "Upload" / "Add job" / "ATS score". Secondary links under button: "Paste text" · "Try a sample".

**Flags:** "Try a sample" needs a bundled sample résumé asset + a no-auth demo diagnosis path (backend/state — out of scope for UI story, stub the tap target with a TODO + analytics event so it's wireable later).

---

## B — Upload · app-level sheet (no dead ends)

**Why:** Tapping Upload used to drop users straight into the iOS Files picker, often landing on an empty "No Recents" — the ~81% drop-off point. Insert an app-level sheet first: sets expectations, points to where résumés live, offers two non-file routes so the funnel can't dead-end.

**Layout:** SwiftUI `.sheet` with `.presentationDetents([.medium, .large])` over a dimmed Home. "Browse Files" launches `.fileImporter([.pdf, .docx])`. Location chips (iCloud Drive / Downloads / Mail) are non-tappable hints (or deep-link to UIDocumentPicker directories) — 3 equal-width tiles. Below a divider ("no file handy?"): two glass list rows — "Paste résumé text" and "Try a sample résumé". Motion: sheet springs up; reduced-motion → fade.

**Copy:** Sheet title "Add your résumé" / sub "PDF or DOCX, up to 5 MB. We'll read it the way an ATS does." / primary button "Browse Files" / row 1 "Paste résumé text — Copy from anywhere — works great" / row 2 "Try a sample résumé — See a real diagnosis in 20 seconds".

**Flags:** Paste-text route needs a plain-text → diagnosis endpoint (backend). Sample route needs a bundled sample + demo diagnosis (no auth) (backend). Both new — stub UI affordances, wire to existing `cachePickedFile`/upload pipeline where a real endpoint exists, otherwise disable with "Coming soon" state rather than dead tap.

---

## D — Me · guest account (one language, trust-first)

**Why:** Old Me screen mixed English + Hebrew + RTL/LTR in one view — reads as unfinished, which is poison in a résumé/trust product. New: renders one direction at a time, leads with a clear sign-in value prop, gives privacy its own card. Language is an explicit choice, not an accident.

**Layout:** Single `LocalizedStringKey` source per render; whole view flips with `.environment(\.layoutDirection, .rightToLeft)` for Hebrew — never mixed mid-view. Identity row (avatar initial + "Guest" / "Not signed in"). Value card = brand-gradient-tint fill, CTA "Create free account" + "Already have one? Sign in". Stats row = HStack of 3 tiles (Optimized / ATS checks / Templates). Trust card = teal-tinted, shield icon. Language picker = 2-segment control (English / עברית), active segment gets brand gradient fill.

**Copy:** "Account" / "Guest" · "Not signed in" / value card "Save your progress — Create a free account to save every optimization, sync across devices, and export unlimited PDFs." / CTA "Create free account" / "Already have one? Sign in" / trust "Your résumé stays private. We never sell or share your data. Delete it anytime."

**Flags · RTL:** Hebrew = full mirror (tab order, chevrons, stat order all flip). No mixed-direction state allowed anywhere on this screen. No new backend.

---

## C1 — Optimized · locked (teaser, not dead end)

**Why:** Old state was a generic empty state + "Go to Home." New: previews the actual output (blurred ATS score card with real metric rows) so the reward is visible, replaces the vague CTA with a 2-step checklist naming exactly what's missing.

**Layout:** Reuse the real score-card component rendered with demo data, `.blur(radius: 3)` + centered lock-icon overlay. Checklist rows reflect live state (`hasResume` / `hasJob` flags) and tick off as inputs land. This same template (preview slot + copy only differ) drives C1/C2/C3.

**Copy:** "Optimized" / "Here's what you'll unlock." / preview caption "Your résumé, scored & rewritten" / sub "An ATS match score, keyword gaps, and line-by-line fixes — tuned to your target job." / checklist "Upload your résumé" / "Add a job to match against" / CTA "Upload résumé on Home".

**Flags:** Checklist needs the app to expose `hasResume` / `hasJob` flags to these tabs — this is local state, not backend (likely already derivable from `AppState.latestOptimizationId` / `TailorViewModel` — confirm during implementation).

---

## C2 — Design · locked (template preview)

**Why:** Old state hid the Design tab's entire value. New: blurred row of real template thumbnails proves there's something worth unlocking, same name-the-gap checklist + specific CTA.

**Layout:** Thumbnails are the real template render pipeline at small scale (reuse `TemplateThumbnail.swift`), blurred behind the lock icon. Shared locked-state component — only the preview slot + copy differ from C1/C3.

**Copy:** "Design" / "Recruiter-ready templates, one tap." / preview caption "12 ATS-safe templates" / sub "Swap layouts, colors, and fonts. Every template stays parseable by the bots." / checklist "Upload your résumé" / "Run Optimize once" / CTA "Upload résumé on Home".

**Flags:** None new — reuses existing template assets + the shared lock-state component from C1.

---

## C3 — Expert · locked (cover letter & submit)

**Why:** Same pattern as C1/C2 — blurred preview of a cover-letter document proves the value of Expert mode before requiring an optimization.

**Layout:** Blurred document preview with 3 pill tabs ("Cover letter" / "Recruiter Qs" / "Submit") + placeholder text lines, lock-icon overlay. Same shared locked-state component.

**Copy:** "Expert" / "The full submit package, done for you." / preview caption "Cover letters & submit packages" / sub "A tailored cover letter, likely recruiter questions, and an export-ready package for every application." / checklist "Upload your résumé" / "Run Optimize once" / CTA "Upload résumé on Home".

**Flags:** None new — reuses the shared lock-state component.

---

## E1 — Got it · parsing (read-through, not a spinner)

**Why:** The moment after a file lands is when doubt creeps in. Instead of a blank spinner: a visible read-through — file confirmed, a scan-line animating over a mini résumé render, and a 3-step parse checklist ticking. Buys the 1-3s parse time while building trust the app actually read the résumé.

**Layout:** File-confirmed row (icon, filename, size/pages, checkmark) above a mini white résumé-shaped card with an animated scan-line sweep (`scanmove` keyframe, hidden under reduced-motion). Below: 3-row checklist, each row state = done (filled gradient check) / active (spinner) / pending (empty ring).

**Copy:** Badge "STEP 1 · UPLOAD" / checklist "Extracted your text" (done) → "Detecting sections & dates" (active, spinner) → "Checking ATS readability" (pending) / footer "Reading your résumé the way an ATS does…"

**Flags:** Auto-advances to E2 when parse completes (no tap). Needs parser to emit per-stage progress events so the checklist reflects reality, not a fake timer — until that exists, drive the 3 stages off existing parse/upload completion callbacks with a minimum-display-time floor so it never flashes. If parse fails → inline recoverable error (see R1), never a dead end.

---

## E2 — Match to a job (one field, skippable)

**Why:** Matching to a real job makes the score meaningful, but requiring it would stall first-timers. Single paste field, live keyword chips proving the listing was understood, explicit Skip that still produces a score against general ATS standards.

**Layout:** Badge "STEP 2 · MATCH". `TextEditor`-style paste field (sky-tinted border, glow) with placeholder/typed JD text. Below: "WE'LL MATCH ON" label + wrapping keyword chips extracted client-side on paste (teal for skill keywords, sky for domain/role keywords, "+N" overflow chip). Primary button "Run my diagnosis" with trailing arrow. Below button: "Skip — score against general standards" text link.

**Copy:** H1 "Which job are we aiming at?" / sub "Paste the listing and we'll score your résumé against its exact keywords." / button "Run my diagnosis" / skip link "Skip — score against general standards."

**Flags:** Keyword extraction can run on-device (client-side, no backend needed). The generic-rubric scoring path (Skip) must exist server-side so Skip isn't a dead button — confirm `FitCheckViewModel`/existing ATS endpoints already support a no-JD scoring mode; if not, flag as backend work, don't fake it client-side.

---

## E3 — Analyzing (the recruiter-framed wait)

**Why:** Covers a real 10-20s of model work while teaching the mental model ("a recruiter scans in 7 seconds"). Rotating insight lines make the wait feel like work happening for the user, raising perceived value before the number lands.

**Layout:** Centered conic-gradient spinning ring (brand colors) with a centered icon. H1 below. A single rotating insight-line chip (teal dot + text, cycles ~2.5s, `floatup` fade-in per line). Linear progress bar (brand gradient) + "Almost there" label + 3 pulsing dots. Footer: honest time estimate.

**Copy:** H1 "Scanning like a recruiter would in 7 seconds" / rotating lines: "Comparing your verbs against 4,000 hires for this role…", "Checking formatting an ATS can parse…", "Finding your strongest 3 lines…" / footer "Usually takes about 15 seconds."

**Flags:** Insight copy deck is content work, not engineering — keep claims method-framed (no fabricated stats presented as fact) for legal/trust review before shipping copy. Reduced-motion: swap conic spinner for a static progress bar. Auto-advances to E4 on result; if it overruns, copy shifts to "Putting it together…".

---

## E4 — First score (the payoff & the next move)

**Why:** The screen the whole funnel exists for. Must instantly read 3 things: a score (animated ring + count-up), an encouraging-not-punishing verdict, and one obvious next move. Surfaces the single biggest win with a point value so "See all fixes" feels worth it.

**Layout:** "YOUR FIRST DIAGNOSIS" label. Large score ring (gradient stroke, animated draw + count-up, e.g. 68/100) with verdict pill below ("Good start — 3 quick fixes to 80+"). 3-tile sub-score row (Keywords / Format / Impact, each tappable to jump to that section). "Biggest win" card (violet-tinted, trophy icon, named fix + point estimate). Primary button "See all N fixes" with trailing arrow.

**Copy:** "Your first diagnosis" / score "68 / out of 100" / verdict "Good start — 3 quick fixes to 80+" / biggest-win "Biggest win: add 4 missing keywords — '...', '...' — worth ~+9 points." / CTA "See all 9 fixes."

**Flags:** Needs the scoring model to return banded sub-scores + ranked fixes with point deltas. Point-delta estimates must be defensible (re-score on apply, not a static guess) — flag as backend/model work if not already present. Verdict copy is banded by score: <50 "Let's fix the basics", 50-74 "Good start", 75+ "Strong — polish it".

---

## E5 — Fixes list (apply & watch it climb)

**Why:** Turns the score into a game you're winning. Each fix is concrete (real before→after diff, not advice), carries a point value, and a sticky header re-scores live as you apply — 68 → 77 → 80+ — with a target marker to chase. This loop earns the next session and the account sign-up.

**Layout:** Sticky header: title "Your fixes", live score (old score strikethrough → arrow → new score, gradient), progress bar with a target-marker tick, "N of M applied · +X so far" / "Target 80 ↗". Below: scrollable fix cards in 3 states — Applied (collapsed, teal tint, strikethrough title, point badge), Open/expanded (impact badge + point value, title, before/after diff block [red strikethrough line / teal added line with bolded changed words], "Apply fix" + "Skip" buttons), Pending (collapsed, icon + title + subtitle + point value + chevron). Sticky footer: "Apply all N · +X" primary button + a secondary icon button (likely sort/filter).

**Copy:** "Your fixes" / "2 of 9 applied · +9 so far" / "Target 80 ↗" / impact badge "IMPACT · HIGH" / fix title "Lead with stronger verbs (+6 pts)" / diff before "Responsible for managing the redesign of the checkout" → after "**Led** the checkout redesign, **cutting** drop-off 23%" / "Apply fix" / "Skip" / footer "Apply all 7 · +13".

**Flags:** Needs re-score-on-apply (server) + an edit-in-place/undo model for bullets. Point deltas must reconcile live so the climb never lies — if server re-score isn't instant, use optimistic local re-score reconciled async, never a stale/fake number. Crossing target fires the S1 success state.

---

## R1 — Couldn't read it (scanned / image PDF)

**Why:** A huge share of uploads are scanned/image-only PDFs with no text layer — a silent killer. Name it plainly ("scanned image — no selectable text"), tie to why it matters ("an ATS can't read it either"), offer the exact same escape hatches as the happy path. Amber tone reads as a heads-up, not an error.

**Layout:** Back chevron + "Upload" label. Centered warning hero (amber triangle icon in rounded square) + H1 + explanation. Offending-file row (icon, filename, "Image-only · no text layer"). Recovery stack: primary gradient button "Paste the text instead", then a 2-up row "Choose another file" / "Try a sample". Footer tip line.

**Copy:** "We couldn't read that résumé" / "It looks like a scanned image — there's no selectable text, so an ATS can't read it either." / "Paste the text instead" / "Choose another file" / "Try a sample" / tip "Tip: in most apps, 'Export as PDF' keeps the text readable."

**Flags:** Triggered when extracted text length ≈ 0 after parse. On-device OCR fallback is optional/out-of-scope for this pass. Paste-text path (shared with Upload sheet B) must exist before this screen can fully deliver its primary CTA — if not present yet, this screen still ships with the other two recovery routes active and "Paste the text instead" feature-flagged off until B's paste-text endpoint lands.

---

## R2 — Won't work yet (wrong type / too big)

**Why:** Same recovery pattern as R1, for the other common upload failure: wrong file type or file too large. Same amber heads-up tone, same non-dead-end recovery set (paste text / choose another file / try a sample), so every upload failure mode resolves through one consistent component rather than a bespoke error per case.

**Layout:** Shares R1's component shell — back chevron, warning hero, offending-file row (showing the actual type/size problem), same 3-route recovery stack. Implementation should generalize R1 into a single `UploadFailureView` parameterized by failure reason (`.scannedImage`, `.wrongType`, `.tooLarge`) rather than duplicating the screen.

**Flags:** No new backend — purely a client-side validation message (file type/size check already exists per `UploadFilePreflight`); confirm preflight already classifies these reasons, otherwise add the classification (still local validation, no new endpoint).

---

## R3 — Connection lost mid-analysis

**Why:** A drop mid-analysis is the scariest failure — it feels like losing everything. Invert it: "paused at 72%, your résumé and job are saved, nothing's lost," with auto-resume on reconnect plus a manual Retry. Amber, not red — this is recoverable.

**Layout:** "You're offline" status line. Centered paused-progress orb (ring at the paused percentage, amber stroke, pause-icon center). H1 "Connection dropped mid-analysis" + sub naming the paused percent and reassurance. Teal reassurance chip ("Resumes automatically when you're back"). Primary gradient button "Retry now" with a refresh icon.

**Copy:** "You're offline" / "Connection dropped mid-analysis" / "We paused at 72%. Your résumé and job are saved — nothing's lost." / "Resumes automatically when you're back" / "Retry now."

**Flags:** Needs a resumable analysis job (checkpoint + idempotent re-run) and local persistence of in-flight inputs — backend work. Until that lands, implement the UI shell with a simpler behavior (full retry from scratch on reconnect) and flag the "resume from 72%" framing as not-yet-true; don't ship copy claiming a capability the backend doesn't have. Driven by `NWPathMonitor` for the offline banner + auto-retry trigger.

**As actually implemented (2026-06-25):** `ConnectionLostView` ships the honest fallback described above, not the bold spec above it. No `NWPathMonitor` exists in the app, so there is no offline-banner auto-detection and no auto-retry on reconnect — "Retry now" is a manual, real re-invocation of the failed `optimize()`/`runFreeATS()` call via `TailorViewModel.isConnectionError` (classified from real `URLError` cases). Copy says "still here, nothing's lost" (true within the current app session — inputs live in `TailorViewModel` state) and does not claim auto-resume. Treat the auto-resume/NWPathMonitor description above as the future-state target, not the current build.

---

## S1 — You hit the target (celebrate & point forward)

**Why:** Fires the instant the score crosses the target band — the peak-trust moment. Celebrates concretely (score + delta + "recruiter-ready" framing), then offers exactly two forward moves: polish in a template, or save the work. The account ask is deliberately *not* here — it's the next screen, S2.

**Layout:** Radial celebratory glow background. "RECRUITER-READY" label. Large score ring (animated draw + count-up) with "out of 100" sub-label. Delta chip ("Up 14 points — from 68"). H1 "Your résumé is ready to send". Two next-move cards: violet-tinted "Make it look the part → Drop it into an ATS-safe template" (routes to Design), teal-tinted "Lock in your progress → Save free so you don't lose this" (routes to S2).

**Copy:** "Recruiter-ready" / "82 / out of 100" / "Up 14 points — from 68" / "Your résumé is ready to send" / "Make it look the part — Drop it into an ATS-safe template" / "Lock in your progress — Save free so you don't lose this."

**Flags:** Triggered on score ≥ target band — confirm/define the target band per role (likely a fixed threshold like 80 is fine for v1; flag per-role banding as future work). One-shot confetti + ring/count-up; reduced-motion → static. Shown once per milestone, not repeatedly. "Recruiter-ready"/percentile claims must be method-defensible — review copy before shipping.

---

## S2 — Save your 82 (account at peak value)

**Why:** Leads with what the user just earned ("Save your 82") and frames sign-in as protecting that, not gating it. Three concrete keeps, Apple-first for one-tap (App Store requirement + lowest friction), an honest "Maybe later" that keeps the guest session fully usable, privacy line repeated.

**Layout:** Bottom sheet over a dimmed/blurred S1. Mini score badge (gradient square, score + "SCORE" label) + title "Save your 82" + sub. "What you keep" checklist (3 rows, teal checkmarks). "Continue with Apple" (white button, Apple logo, primary per App Store requirement). "Continue with email" (glass outline button). "Maybe later" text link. Footer privacy line.

**Copy:** "Save your 82" / "Create a free account so this never disappears." / keeps: "Your optimized résumé & score history" / "Unlimited PDF exports, any template" / "Sync across your iPhone & iPad" / "Continue with Apple" / "Continue with email" / "Maybe later" / footer "Your résumé stays private. We never sell or share your data."

**Flags:** Needs guest→account data merge on sign-in (likely partially exists per `AppState`/auth — confirm). Sign in with Apple must be present (App Store requirement if any account creation exists — confirm current entitlement/capability is configured). "Maybe later" relies on local persistence already covering guest work — confirm guest state survives app restart before shipping this copy as a guarantee.
