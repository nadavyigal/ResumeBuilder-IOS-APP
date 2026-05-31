# ResumeBuilder iOS — SEO Program (Web Feeder)

Web SEO is now a **feeder** to App Store install, not the conversion endpoint. Every page's mobile CTA points to the App Store; desktop CTA optionally falls back to web signup. Programmatic SEO is Tier B until the ASO + bespoke-landing path proves install conversion.

## Bespoke Tier 1 Pages

Every page below has a mobile-prominent App Store CTA. Desktop optionally shows a web signup CTA as fallback.

- `ats-resume-builder`
- `ai-resume-tailoring`
- `resumebuilder-ai-vs-teal`
- `resumebuilder-ai-vs-rezi`
- `resume-templates-that-pass-ats`
- `ats-resume-checker` (the free tool's landing — result page hands off to App Store)
- `resume-builder-ios-app` (App Store landing equivalent on web)

## Programmatic Tier 1 Templates

Each template generates many pages, but every page must clear a thin-content bar.

| Template | Pattern | Example | Data per page |
|---|---|---|---|
| Role example | `{role}-resume-example` | `software-engineer-resume-example` | A real sample resume snippet, key bullets, an explanation |
| Industry guide | `{industry}-resume-guide` | `fintech-resume-guide` | Industry-specific keywords, 3 templates, FAQ |
| Experience level | `{level}-resume-template` | `entry-level-resume-template` | Structural guidance, sample, do / don't |

## Quality Bar Per Programmatic Page

- Real example (not just keyword swap)
- At least 600 words of unique guidance
- One link to relevant Tier 1 page
- Schema (BreadcrumbList + appropriate Article / FAQPage)
- Internal links to 2 sibling pages
- A clear CTA to start a resume in the editor

## Tier 2 (after Tier 1 proves)

- `resume-tips-by-industry` (separate from the guide pages)
- Localization variants (Hebrew, see `hebrew-program.md`)
- Cover letter generator pages

## Internal Linking

- Homepage links to top 3 Tier 1 bespoke pages
- Each Tier 1 page links to the free tool
- Programmatic sibling links bounded (no link wheels)
- 1 link from a programmatic page to its category Tier 1 page

## Schema

- `SoftwareApplication` for product
- `FAQPage` on Tier 1
- `Article` on programmatic pages with structured headings
- `BreadcrumbList`

## Measurement

- Indexed pages
- Top queries by clicks
- Avg position for primary queries
- Bounce rate per Tier 1 vs programmatic
- **Web → App Store install rate per page** (use `at=` and `ct=` Apple attribution tags)
- Web → signup rate per page (fallback metric)
- Programmatic page set → App Store install rate (per template)
