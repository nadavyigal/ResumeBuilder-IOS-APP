# rb-aso-002 Upload Manifest

Rendered: 2026-05-28
Product: Resumely iOS
Locale: English (US)
Status: Ready for App Store Connect upload; upload blocked locally by missing App Store Connect credentials/session.

## Output Folders

- `iphone-6.7/` - 5 PNGs, 1290 x 2796 — upload to ASC **6.9" iPhone** screenshot section
- `ipad-13/` - 5 PNGs, 2048 x 2732 — upload to ASC **13" iPad** screenshot section (required: `TARGETED_DEVICE_FAMILY = 1,2`)
- `iphone-6.5/` - 5 PNGs, 1242 x 2688 — alternate size only; do not duplicate in the same ASC iPhone section
- `source-iphone-17-pro-max/` - source simulator PNG captures, 1320 x 2868

## Upload Order

1. `slot-1.png` - Your resume, tailored for any job
2. `slot-2.png` - See exactly what's blocking you
3. `slot-3.png` - AI edits that actually fit the role
4. `slot-4.png` - ATS-friendly templates that impress recruiters
5. `slot-5.png` - Expert analysis for every section

## Captions

1. AI resume tailor and ATS checker for job seekers
2. ATS resume score by section - find the blockers before applying
3. AI resume optimization by job description - improve bullets and summary
4. Resume design templates - ATS safe and professionally formatted
5. Expert resume review with AI rewrite suggestions

## Notes

- Captured from the app's launch-argument-only marketing screenshot mode using the Build iOS Apps plugin on iPhone 17 Pro Max simulator.
- Exported to exact App Store screenshot dimensions with `sips`.
- Local App Store Connect upload could not be completed because no Fastlane configuration, App Store Connect API key, or active ASC browser/session is available in this workspace.
