# Resumely screenshot upload manifest

Read and reviewed: 2026-10-31. **Only en-US exists. There is no Hebrew screenshot set.**

State: READY FOR APPROVAL for the local screenshot set. Upload is gated on the version decision below. No ASC changes have been made.

## Version decision

The original target was the 1.5.7 draft. The read-only pricing source now builds **1.6.0 (36)**. Both simulators were freshly installed with that build and have matching executable hashes. Confirm the receiving draft and its intended UI before upload. These images do not establish that any version is deployed or available to users.

## New upload candidates

Four panels, in this order, for each device slot. PASS means local visual and pixel checks passed. It does not authorize upload to an unconfirmed version.

| Locale | Device slot | Order | Pixel dimensions | File path from worktree root | Verdict |
|---|---|---:|---|---|---|
| en-US | iPhone Dynamic Island medium, 6.3-inch | 1 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.3-1206x2622/01-tailor.png` | PASS |
| en-US | iPhone Dynamic Island medium, 6.3-inch | 2 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.3-1206x2622/02-missing.png` | PASS |
| en-US | iPhone Dynamic Island medium, 6.3-inch | 3 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.3-1206x2622/03-edits.png` | PASS |
| en-US | iPhone Dynamic Island medium, 6.3-inch | 4 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.3-1206x2622/04-review.png` | PASS |
| en-US | iPhone Face ID large, 6.5-inch | 1 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.5-1242x2688/01-tailor.png` | PASS |
| en-US | iPhone Face ID large, 6.5-inch | 2 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.5-1242x2688/02-missing.png` | PASS |
| en-US | iPhone Face ID large, 6.5-inch | 3 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.5-1242x2688/03-edits.png` | PASS |
| en-US | iPhone Face ID large, 6.5-inch | 4 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/release-iphone-6.5-1242x2688/04-review.png` | PASS |
| en-US | iPad 13-inch | 1 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/release-ipad-13-2064x2752/01-tailor.png` | PASS |
| en-US | iPad 13-inch | 2 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/release-ipad-13-2064x2752/02-missing.png` | PASS |
| en-US | iPad 13-inch | 3 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/release-ipad-13-2064x2752/03-edits.png` | PASS |
| en-US | iPad 13-inch | 4 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/release-ipad-13-2064x2752/04-review.png` | PASS |

SHA-256 hashes: `audit/aso-v3-t2/release-outputs.json`. Upload the individual PNGs, not the JPG review sheets or compare.png.

## Copy and source

1. Check your resume / against this job. Actual Home upload surface.
2. See what’s missing / before you apply. Actual Match Check view with example fit data.
3. Add a claim / only if it’s true. Actual opt-in phrase confirmation with example data.
4. Review the changes / in your resume. Actual Resume Diagnosis and before/after review with example data.

Source captures: `scripts/aso-v3/release-captures/iphone/` and `scripts/aso-v3/release-captures/ipad/`. Captured on iPhone 17 and iPad Pro 13-inch (M5). No iPhone 17 Pro use. The iPad captures show the genuine wide adaptive layout. They are not phone crops.
Home is the normal app surface. Other views are reached through existing DEBUG smoke harnesses in the pricing source, with the actual view components and example data. The final panels label example data. App views were not edited. Full raw captures are retained. Final images frame excerpts of these real captures, including cropped lower scroll content.

Home is framed above the unmeasured recruiter timing claim. Every final image has the Resumely avatar and name. No app rename. No ATS, interview or job guarantee, or unmeasured app-speed claim in the final marketing copy. Estimate disclaimers in the actual UI are retained where visible. The old export and expert panels are removed from the upload set; this candidate set makes no paid PDF or expert-tool promise. The paywall was compared separately with pricing-v2-s3 and the live simulator layout. Sample paywall prices were not used in upload assets.

## Superseded v3 assets

Keep these files for recovery and historical comparison. Do not upload them with the replacement set.

| Locale | Device slot | Former order | Pixel dimensions | File path from worktree root | Verdict |
|---|---|---:|---|---|---|
| en-US | ipad-13-2064x2752 | 1 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/ipad-13-2064x2752/01-tailor.png` | REMOVE |
| en-US | ipad-13-2064x2752 | 2 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/ipad-13-2064x2752/02-missing.png` | REMOVE |
| en-US | ipad-13-2064x2752 | 3 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/ipad-13-2064x2752/03-edits.png` | REMOVE |
| en-US | ipad-13-2064x2752 | 4 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/ipad-13-2064x2752/04-export.png` | REMOVE |
| en-US | ipad-13-2064x2752 | 5 | 2064x2752 | `dist/app-store-screenshots/app-store-v3/ipad-13-2064x2752/05-expert.png` | REMOVE |
| en-US | iphone-6.3-1206x2622 | 1 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/iphone-6.3-1206x2622/01-tailor.png` | REMOVE |
| en-US | iphone-6.3-1206x2622 | 2 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/iphone-6.3-1206x2622/02-missing.png` | REMOVE |
| en-US | iphone-6.3-1206x2622 | 3 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/iphone-6.3-1206x2622/03-edits.png` | REMOVE |
| en-US | iphone-6.3-1206x2622 | 4 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/iphone-6.3-1206x2622/04-export.png` | REMOVE |
| en-US | iphone-6.3-1206x2622 | 5 | 1206x2622 | `dist/app-store-screenshots/app-store-v3/iphone-6.3-1206x2622/05-expert.png` | REMOVE |
| en-US | iphone-6.5-1242x2688 | 1 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/iphone-6.5-1242x2688/01-tailor.png` | REMOVE |
| en-US | iphone-6.5-1242x2688 | 2 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/iphone-6.5-1242x2688/02-missing.png` | REMOVE |
| en-US | iphone-6.5-1242x2688 | 3 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/iphone-6.5-1242x2688/03-edits.png` | REMOVE |
| en-US | iphone-6.5-1242x2688 | 4 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/iphone-6.5-1242x2688/04-export.png` | REMOVE |
| en-US | iphone-6.5-1242x2688 | 5 | 1242x2688 | `dist/app-store-screenshots/app-store-v3/iphone-6.5-1242x2688/05-expert.png` | REMOVE |

## Apple requirements checked 2026-10-31

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
  PNG/JPEG; 1 to 10 screenshots per supported slot. The selected 1206x2622, 1242x2688 and 2064x2752 pixel sizes are accepted. iPad 13-inch screenshots are required when the app runs on iPad.
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/
  Preview duration 15 to 30 seconds, max 500 MB, max 30 fps. H.264 target 10 to 12 Mbps, High 4.0; stereo AAC, 44.1 or 48 kHz.
- https://developer.apple.com/app-store/review/guidelines/#accurate-metadata
  2.3.2 disclose purchases when featured; 2.3.3 show the app in use; 2.3.4 previews use app screen-capture footage.

## App Preview: HOLD, separate from screenshots

No replacement preview is proposed. Opening and end-card content remains a 2.3.4 concern. The reported 29 Oct upload to 1.5.7 is historical evidence, not current ASC verification. See `audit/aso-v3-t2/approval-packet.md` for the separate exact removal action and the screenshot handoff. Do not upload or submit the movie with this set.
