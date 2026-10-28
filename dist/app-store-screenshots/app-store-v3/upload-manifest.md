# Resumely App Store Screenshot Upload Manifest (v3, rb-aso-004)

Generated: 2026-10-28. Replaces the live v2 set (dark navy, shipped with 1.5.6).
Locale: English (US).
Source: `scripts/aso-v3/panel.html`, rendered by `scripts/aso-v3/render.sh` in headless Chrome.
The phone screens are crops of the v2 renders of `MarketingScreenshotView` (`scripts/aso-v3/src/`), so every
on-screen label is still the app's own.

## Why v3

The v2 frames are near-black with a small headline, so in search results they read as three dark slabs and
the message is lost at thumbnail size. v3 uses a cobalt background, a two-line headline on a highlighter
stroke (the size is shared by all five frames), and a phone that fills the lower frame. Search shows only the
first three frames, so 1 to 3 carry the whole story: tailor, see what is missing, fix it.

## Drag-And-Drop Folders

| App Store Connect section | Folder | Size |
|---|---|---|
| iPhone with Dynamic Island (medium display), 6.3" | `iphone-6.3-1206x2622/` | 1206x2622 |
| iPhone with Face ID (large display), 6.5" | `iphone-6.5-1242x2688/` | 1242x2688 |
| iPad 13" | `ipad-13-2064x2752/` | 2064x2752 |

All files are opaque RGB PNGs. Delete the 5 v2 images in each section first, then upload in order.
The click path is the same as part A of `docs/aso/2026-10-app-store-asset-publish-checklist.md`.

## Display Order and Copy

1. `01-tailor.png`: **Tailor your resume / to this job.** Paste a job post. See your Match Score and what's missing.
2. `02-missing.png`: **See what's missing / before you apply.** Top gaps and missing keywords, straight from the job post.
3. `03-edits.png`: **Fix it in / your own voice.** Targeted edits, one section at a time. You approve each one.
4. `04-export.png`: **Send a clean PDF / from your phone.** Classic, Modern and Minimal templates, ready to share.
5. `05-expert.png`: **Get an expert / second look.** Six review tools with rewrites you can stand behind.

## Metadata to change with the same version

| Field | Now | New | Limit |
|---|---|---|---|
| Subtitle | Resume & CV Maker | Tailor Your Resume to Any Job | 29 / 30 |
| Promotional Text | (check in ASC) | Paste a job post and see how well your resume matches it. Resumely shows what is missing, helps you fix it in your own voice, and exports a clean PDF from your phone. | 166 / 170 |

Promotional Text can change any time without review. The subtitle ships with the next version.

## Claim check

- No "ATS", "guaranteed", "get interviews" or "pass" on any frame (product-marketing.md words to avoid).
- Match Score is shown as the app's own score; no employer-score claim.
- Frame 1 job post card is fictional ("Senior Product Designer"), matching the job in the app screen under it.
- "Six review tools" matches the six expert modes in `ExpertModesViewModel.swift`.

## Regenerate

```bash
cd scripts/aso-v3
./render.sh "$PWD" "$PWD/../../dist/app-store-screenshots/app-store-v3/iphone-6.3-1206x2622" 1206 2622 1
./render.sh "$PWD" "$PWD/../../dist/app-store-screenshots/app-store-v3/iphone-6.5-1242x2688" 1242 2688 1.03
./render.sh "$PWD" "$PWD/../../dist/app-store-screenshots/app-store-v3/ipad-13-2064x2752" 2064 2752 1.45
```

`render.sh` flattens each PNG to opaque RGB (needs Pillow). Check sizes and alpha before upload:
`sips -g pixelWidth -g pixelHeight -g hasAlpha dist/app-store-screenshots/app-store-v3/*/*.png`.

## Experiment log row

```markdown
| rb-aso-004 | ResumeBuilder iOS | ASO | Bright, high-contrast v3 screenshots with a two-line headline and the new subtitle will raise search conversion over the dark v2 set | Impressions → product page views, and impressions → first-time downloads, 28 days before vs 28 days after publish (App Store Connect App Analytics) | unscored | published with VERSION on YYYY-MM-DD, measuring | YYYY-MM-DD | YYYY-MM-DD + 28 days |
```
