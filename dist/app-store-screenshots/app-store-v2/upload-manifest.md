# Resumely App Store Screenshot Upload Manifest (v2, G1b)

Generated: 2026-10-19, from `main` at Resumely 1.5.2 (30)
Locale: English (US)
Source: the app's launch-argument-only marketing screenshot mode (`MarketingScreenshotView`), captured by `scripts/generate-app-store-screenshots.sh`
Simulators: Resumely Screenshots 11 Pro Max (iPhone, 1242x2688 native); iPad Pro 13-inch (M5) (2064x2752 native)

## Drag-And-Drop Folders

- iPhone 6.5-inch: `iphone-6.5-1242x2688/`, 5 opaque RGB PNGs, 1242x2688
- iPad 13-inch: `ipad-13/`, 5 opaque RGB PNGs, 2064x2752

In App Store Connect, delete all 10 current screenshots in each device section first, then upload the 5 files in order. The old set (`../app-store-v1/`, June 2026) claims an "ATS score" and shows screens the app no longer has.

## Display Order

1. `01-tailor.png`: Your resume, tailored for this job
2. `02-blockers.png`: See exactly what's blocking you
3. `03-ai-edits.png`: Edits that fit the role, in your voice
4. `04-templates.png`: Clean templates, ready to send
5. `05-expert.png`: Six expert tools, one tap each

## Captions (bottom line of each image)

1. AI resume tailor and Match check for job seekers
2. Resumely Match Score, our own measure of job fit
3. Targeted resume edits from the job description
4. Classic, Modern and Minimal resume templates
5. Expert review with editable rewrite suggestions

## Claim check against 1.5.2

- No "ATS" anywhere on any image (`CopyClaimsTests.testMarketingSlotsNeverSayATS`).
- Slot 2 subscores use the app's real labels: Keyword Alignment, Content Quality, Format & Structure, Design (`Models/ResumeAnalysis.swift`).
- Slot 3: the rewrite uses only the fact in the "before" line (18%), matching 1.5.2's "Add only if true".
- Slot 4: Classic, Modern and Minimal are the app's templates.
- Slot 5: the six expert tools and "Achievement Quantifier" are the app's names (`ExpertModesViewModel.swift`).
- All people, companies and numbers are fictional.

## Validation

See `validation-report.txt`.
