# WP-31 — Hebrew ASO Draft Asset Pass

**Status:** DRAFT — founder review only. Do **not** paste into App Store Connect until approved.
**Canonical source:** `.agents/product-marketing.md` (last updated 2026-06-28)
**Supersedes:** nothing — this is a candidate set; `docs/app-store/he-metadata.md` remains the current submission mirror until founder picks variants.
**App Store Connect:** not touched by this pass.
**Character counts:** verified 2026-07-13 with a Unicode length check (App Store counts characters including spaces). Subtitle ≤30, Keywords ≤100, Promotional Text ≤170.

---

## Claim Verification Matrix

Every line below was checked against `.agents/product-marketing.md`. Rows marked **GATED** must not ship in Hebrew listing copy until product QA clears the gate.

| Claim theme | In draft? | Canonical support | Gate |
|-------------|-----------|-------------------|------|
| Fit before effort / Fit-First | Yes | Differentiation: "Fit-First triage: Strong / Stretch / Skip"; Approved rules: "Fit-First is the front-door story" | None |
| Resumely Match Score (not official ATS) | Yes | Glossary + Objections table; "Words to avoid: official ATS score, pass ATS" | None |
| Missing keywords / top gaps | Yes | Customer language + use cases | None |
| Targeted, user-controlled edits | Yes | Differentiation + Objections ("Will AI make my resume sound fake?") | None |
| Application package (resume PDF, cover letter, job link) | Yes | Product overview + glossary | None |
| Export PDF from iPhone | Yes | "Mobile-native path from upload to fit check to edits to application package" | None |
| ATS-friendly formatting (process-descriptive) | Optional in keywords only | "Keep ATS for discoverability only in process-descriptive contexts" | None |
| Hebrew / RTL app experience | Yes (UI surfaces) | Persona: "Authored Hebrew support and RTL-aware resume surfaces" | None |
| RTL PDF export quality | **No in promo/captions** | RTL resume preview/PDF handling exists in code; **real-device Hebrew preview/PDF QA not completed** (`docs/qa/pdf-export-checklist.md` § "Hebrew / RTL (if applicable — currently not in scope)", all boxes unchecked) | **GATED — product QA** |
| Guaranteed interviews / pass ATS / beat bots | **Excluded** | "Words to avoid" list | N/A |
| Free tier specifics ("1 optimization free") | **Excluded from promo** | Business model defers monetization; free-activation framing may drift post-1.4.1 — confirm with founder before reusing `he-metadata.md` description bullets | Founder confirm |

---

## Subtitle Candidates (30 characters max)

App Store counts characters including spaces. Fit/Match wedge preferred per Approved Marketing Execution Rules.

| ID | Hebrew | Chars | Rationale | Canonical fit |
|----|--------|-------|-----------|---------------|
| **S1 (recommended)** | `בדיקת התאמה לפני הגשה` | 21 | Fit-First front door; mirrors EN "Check your fit before you apply" | ✅ Fit-First + approved ASO lead |
| S2 | `התאמת קורות חיים מהאייפון` | 25 | Mobile-first completion wedge | ✅ Mobile-native path |
| S3 | `ציון התאמה וחבילת מועמדות` | 25 | Match Score + application package | ✅ Resumely Match Score + package glossary |
| S4 | `קורות חיים מותאמים לכל משרה` | 27 | Current `he-metadata.md` subtitle — tailor-first, weaker Fit-First lead | ⚠️ Allowed but not recommended ASO lead |
| S5 | `מילות מפתח, פערים, ייצוא PDF` | 28 | Feature list; dense, less brand | ✅ Missing keywords / top gaps / export — no ATS-score claim |

**Founder pick:** S1 unless Israel ASO testing favors tailor keywords (then S4 as control).

---

## Keywords Field Candidates (100 characters max)

Comma-separated, no spaces after commas (App Store Connect convention). `ATS` retained only as discoverability token per canonical process-descriptive rule — never paired with "pass" / "ציון שלך" / guaranteed outcome language.

| ID | Keywords | Chars | Notes |
|----|----------|-------|-------|
| **K1 (recommended)** | `קורות חיים,התאמה למשרה,מילות מפתח,חבילת מועמדות,מכתב מקדים,מחפש עבודה,ייצוא PDF` | 79 | Fit/Match + package + export; no ATS token |
| K2 | `קורות חיים,בקשת עבודה,ATS,מחפש עבודה,כתיבת קורות חיים,ייעול קורות חיים,מכתב מקדים` | 81 | Current `he-metadata.md` set — proven layout, ATS discoverability only |
| K3 | `קורות חיים,ציון התאמה,פערים,עריכה ממוקדת,מכתב מקדים,ייצוא PDF,מחפש עבודה` | 72 | Emphasizes Resumely Match Score framing (התאמה, not "ציון ATS") |
| K4 | `קורות חיים,התאמה לפני הגשה,בינה מלאכותית,מכתב מקדים,ראיון עבודה,לינקדאין,PDF` | 76 | Broader expert-mode discovery; "בינה מלאכותית" is category, not "AI guarantees hire" |

**Founder pick:** K1 for positioning alignment; K2 if keyword volume tests need the `ATS` token.

---

## Promotional Text Candidates (170 characters max)

| ID | Hebrew | Chars | Notes |
|----|--------|-------|-------|
| **P1 (recommended)** | `בדוק התאמה לפני ההגשה. Resumely מראה מה חסר, עוזרת להתאים קורות חיים ומייצאת חבילת מועמדות מהאייפון.` | 100 | Matches approved 1.2 EN promo in `.agents/product-marketing.md` + current `he-metadata.md`; no RTL PDF claim |
| P2 | `לפני שמגישים: בדקו התאמה למשרה, ראו פערי מילות מפתח, בצעו עריכות ממוקדות וייצאו קורות חיים ומכתב מקדים מהאייפון.` | 112 | Stronger Fit-First + targeted-edits emphasis |
| P3 | `קורות חיים שלא נשמעים כמו צ'אטבוט. התאמה אמיתית למשרה, עריכות בשליטתכם, וחבילת מועמדות מהאייפון.` | 96 | Anti-generic-AI angle (aligned with `docs/app-store/en-metadata.md` demand-mining draft); no fake-score claim |

**Do not use (examples of blocked copy):**
- Any line implying "עובר ATS" / "מובטח ראיון" / "ציון ATS רשמי"
- Any line claiming polished **RTL PDF export** until QA gate clears (see Reviewer Note)

**Founder pick:** P1 for parity with approved EN promo; P3 if anti-generic-AI test is approved for Hebrew.

---

## Screenshot Captions (5 slots)

Captions map to `MarketingScreenshotSlot` order (`rb-aso-002` upload manifest slots 1–5). Each caption must reflect a **reachable in-app surface**. Wording uses **התאמה / ציון התאמה של Resumely**, not "ציון ATS".

| Slot | In-app surface | Hebrew caption | Chars | Claim check |
|------|----------------|----------------|-------|-------------|
| 1 — Tailor | Home → job paste → tailor entry | `התאמת קורות חיים למשרה — בדיקת התאמה לפני עריכה` | 47 | ✅ Fit-First + tailor |
| 2 — Blockers | Score / section blockers UI | `ציון התאמה של Resumely לפי סעיפים — מצאו חסמים לפני הגשה` | 56 | ✅ Self-defined score; no official ATS |
| 3 — AI edits | Optimization / targeted edits | `עריכות ממוקדות לפי תיאור המשרה — בשליטתכם` | 41 | ✅ Targeted edits objection response |
| 4 — Templates | Design / export CTA | `תבניות ידידותיות ל-ATS וייצוא PDF מהאייפון` | 42 | ✅ ATS-friendly (process); export from phone — **RTL PDF quality not claimed** |
| 5 — Expert | Expert modes grid | `מכתב מקדים, הכנה לראיון ולינקדאין — בנוסף לקורות החיים` | 54 | ✅ Application package / expert modes in product overview |

**GATED alternative for slot 4 (use only after Hebrew PDF QA pass):**
`תבניות בעברית ו-RTL — ייצוא PDF מלוטש מהאייפון` (46 chars) — **do not ship** until `docs/qa/pdf-export-checklist.md` Hebrew/RTL section is checked on a physical iPhone.

---

## Reviewer Note (founder + QA)

### Purpose
WP-31 is a **draft-only** Hebrew ASO refresh aligned to `.agents/product-marketing.md` (Fit/Match first, application package, honest Resumely Match Score). Nothing in this file has been published to App Store Connect.

### Recommended default bundle
- Subtitle **S1** · Keywords **K1** · Promo **P1** · Captions as table above

### RTL / PDF export gate (mandatory)
Product marketing allows "Authored Hebrew support and RTL-aware resume surfaces" for **in-app UI**. It does **not** certify production-ready **RTL PDF export**.

Outstanding: **real-device Hebrew resume preview/PDF QA** remains open. `docs/qa/pdf-export-checklist.md` lists the Hebrew/RTL PDF checks under "Hebrew / RTL (if applicable — currently not in scope)" with every box unchecked (RTL text direction, mixed Hebrew/English alignment, PDF export preserves RTL direction).

**Rule for this draft:** Promo text and screenshot captions may claim **PDF export from iPhone** and **ATS-friendly templates** (process-descriptive). They must **not** claim Hebrew/RTL PDF fidelity, "מושלם בעברית", or RTL layout in the exported PDF until QA signs the checklist on a physical device.

### Claims audit — passed
- Fit-First / check before apply
- Resumely Match Score as self-defined fit guidance
- Missing keywords, top gaps, targeted edits
- Application package (resume, cover letter, job materials)
- Mobile-native flow from upload to export
- Expert modes (cover letter, interview, LinkedIn) as product capabilities

### Claims audit — excluded or gated
| Claim | Status |
|-------|--------|
| Pass ATS / guaranteed interview / official ATS score | Excluded |
| RTL PDF export quality | **GATED on product QA** |
| "1 free optimization" and exact free-tier limits | Defer to founder — description in `he-metadata.md` may be stale vs live 1.4.1 monetization posture |
| Paid acquisition / ASO volume scale | Blocked per canonical rules until post-live funnel read (PostHog window per `tasks/progress.md`) |

### Pre-submit checklist (founder)
- [ ] Pick subtitle, keywords, and promo variants (S/K/P IDs above)
- [ ] Confirm free-tier bullets if updating full Hebrew description (not part of this draft pass)
- [ ] Run Hebrew screenshot capture per `he-metadata.md` (`-AppleLanguages "(he)" -AppleLocale he_IL`)
- [ ] Audit `MarketingScreenshotView` for hardcoded English strings before Hebrew screenshot upload
- [ ] Complete Hebrew/RTL PDF QA on physical iPhone before enabling any RTL PDF marketing claim
- [ ] Paste approved fields into App Store Connect → Hebrew localization manually
- [ ] Preview Hebrew listing in ASC before submit

### Next work after approval
1. Merge winning variants into `docs/app-store/he-metadata.md`
2. Capture `dist/app-store-screenshots/he/` set
3. Update `launch-assets/aso/screenshot-briefs.md` Hebrew frame copy if captions change
4. Log decision in `tasks/progress.md` under WP-31

---

*Generated: 2026-07-13 · WP-31 draft-only · No App Store Connect changes made. Character counts Unicode-verified. No publishing or paid acquisition initiated.*
