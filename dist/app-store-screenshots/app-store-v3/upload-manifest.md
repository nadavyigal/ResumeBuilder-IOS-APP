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

## Resumely avatar

Every frame carries the Resumely avatar (the robot with the R on its chest), in a different place on each:
waving from the phone's corner (1), peeking in from the right (2), rising from the bottom left (3), peeking
from the left (4), on the phone's corner (5). It is never mirrored: a flip reverses the R.
Cutout: `scripts/aso-v3/src/robot.png`, made from `robot-source.png` by uniting Apple Vision subject masks
(`avatar-mask.swift`, run on the full image and on the right hand alone) with a flood fill of the white
background. Vision alone dropped the right hand; the flood fill alone ate the white fingertips.

## App Preview (motion, plays before the screenshots)

File: `app-preview/resumely-app-preview-886x1920.mov`. 21 s, 886x1920 portrait, H.264 High 4.0 at
3.3 Mbps (8.7 MB, so it fits a 10 MB browser upload; stills checked sharp), 30 fps, silent stereo AAC 256 kbps / 48 kHz (Apple requires a stereo track). Apple's accepted
iPhone preview size is 886x1920 for every 19.5:9 iPhone section (spec read 2026-10-28), so one file covers
6.3", 6.5" and 6.9". Upload it to the first slot of the iPhone 6.5" (or 6.9") **App Previews** well.
Set the poster frame at 5 s (phone, job post card and avatar all on screen).

Storyboard: avatar pops in, headline highlights in (0-3 s); phone rises, job post card marks three keywords
(3-7.5 s); what's missing (7.5-11 s); edits with a tap on Apply improvement (11-14.5 s); PDF templates
(14.5-17.5 s); end card with the avatar, "Resumely", "Tailor your resume to any job" (17.5-21 s).

Review risk: App Review guideline 2.3.4 says previews should show captured footage of the app, with
overlays allowed. The phone screens are the app's own `MarketingScreenshotView` renders and the avatar
and text are overlays, but the opening 3 s and the end card show no app screen. If Apple rejects the
preview, shorten those two parts first.

Checked 2026-10-29 with `probe.swift`: 21.0 s; video avc1 886x1920, 30 fps, 3.3 Mbps (below Apple's
10-12 Mbps target, which is a target, not a limit); audio AAC, 2 channels, 48 kHz, both tracks enabled.
The silent track encodes far below 256 kbps because it is silence. `encode.swift` writes 11 Mbps (22 MB);
the uploaded copy used `AVVideoAverageBitRateKey: 3_300_000`.

Uploaded 2026-10-29 to version 1.5.7: first App Previews slot of iPhone 6.3" and 6.5". Poster frame left at
Apple's default (5 s).

Regenerate: serve `scripts/aso-v3/` over http, run `capture-frames.js` as a Playwright snippet, then compile
and run the encoder (the `swift` interpreter stalls on it; compile with `swiftc` first):
`swiftc -O encode.swift -o encode && ./encode <framesDir> <out.mov> 886 1920`.

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
