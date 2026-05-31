# ResumeBuilder — Hebrew Program

Confirmed in scope (2026-05-28). Hebrew market is a material differentiator — authored metadata required.

## Principles

- Authored, not translated
- Tone matches Israeli job market norms
- Local job titles, not literal English-to-Hebrew
- Date formats, education conventions, military service handling done correctly
- Separate landing experience, not a route deep in the English site

## Surfaces

- Hebrew landing page
- Hebrew programmatic SEO subset (top roles in the Israeli market)
- Hebrew lifecycle email variants for users whose first action was in Hebrew
- Hebrew variants of the free ATS tool

## App Store Hebrew Approach (Confirmed 2026-05-28)

- **App Store listing**: single listing with Hebrew locale added (not a separate listing)
- **Hebrew metadata needed**: subtitle (30 chars), keywords (100 chars), description (4000 chars), screenshots with Hebrew captions
- **In-app RTL**: not yet implemented (progress.md flags as risk) — do not make Hebrew in-app experience claims until complete
- **Launch sequence**: English first, Hebrew metadata at T+30 after App Store listing goes live

## Open Questions

- App name in Hebrew — same as English or Hebrew variant? (blocked until English name is decided)
- Which subdomain or path for the web Hebrew experience (he.resumebuilder.ai? resumebuilder.ai/he?)
- Templates: are they Hebrew-RTL aware end-to-end (PDF export via WKWebView on iOS)?
- Pricing in ILS or USD in the App Store Connect?
- Local payment methods (relevant for web Stripe, not iOS IAP which Apple handles)?

## Measurement

- Hebrew signup share
- Hebrew → export rate
- Hebrew SEO indexed pages
