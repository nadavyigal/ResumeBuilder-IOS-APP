# Resumely App Store creative asset (October 2026)

One image for the product page header and the search results card. These placements are new in
App Store Connect (2026-10-05) and show only on iOS 27 and iPadOS 27 or later. Upload steps:
`docs/aso/2026-10-app-store-asset-publish-checklist.md`. Experiment: rb-aso-003.

## Files

| File | Use | Size |
|---|---|---|
| `resumely-universal-5244x2950.png` | Upload this one. A universal asset serves both placements. | 5244x2950, 16:9 |
| `resumely-header-3840x1646.png` | Fallback: dedicated product page header | 3840x1646, 21:9 |
| `resumely-search-3840x2560.png` | Fallback: dedicated search results | 3840x2560, 3:2 |

The two fallbacks are centre crops of the universal image, so all three look the same. Use them only if
App Store Connect's Preview shows the universal image cut badly. All are opaque RGB PNGs (no alpha).

## Copy

- See what the job asks for.
- Fix what's missing.
- Tailor your resume to one posting, then export a clean PDF.

No "ATS", no score promise, no price and no "free" (guideline 2.3.14, EXD-012, EXD-035).
The phones show three iPhone screenshots from `../app-store-screenshots/app-store-v2/iphone-6.3-1206x2622/`
(slots 01, 03, 04), so the image matches the screenshot set.

## Layout

Every word sits inside both crops: the header keeps the middle 21:9 band and search keeps the middle 3:2
band of the universal image. The phones bleed off the bottom on purpose.
Colours are the app's tokens (`Core/DesignSystem/Tokens/AppColors.swift`): background #050814 / #0D1224,
accents #6C63FF, #4EA8FF, #40E0D0.

## Rebuild

```bash
./scripts/render-app-store-creative-assets.sh
```

Edits go in `source/creative.html`. The script renders it with headless Chrome, writes the three PNGs,
checks size, alpha and banned words, and writes `validation-report.txt`.
