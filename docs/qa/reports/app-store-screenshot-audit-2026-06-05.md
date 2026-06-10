# App Store Screenshot Audit — 2026-06-05

## Result

Not ready for final App Store submission.

## Apple Requirements Verified

- Apple accepts 1–10 screenshots per supported device size and localization; exactly 10 is not required.
- The highest-resolution iPhone screenshots can scale to smaller iPhone display sizes.
- Accepted 6.9-inch portrait sizes include 1290x2796.
- A 13-inch iPad screenshot set is required when the app runs on iPad.
- Screenshots should show the app in use; text and image overlays are allowed.

Official references:

- https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots
- https://developer.apple.com/app-store/review/guidelines

## Existing Assets

- `dist/app-store-screenshots/rb-aso-002/iphone-6.7/`: 5 unique PNGs at 1290x2796, accepted for Apple's current 6.9-inch slot.
- `dist/app-store-screenshots/rb-aso-002/iphone-6.5/`: the same 5 concepts at 1242x2688. These are alternate-size versions, not screenshots 6–10.
- All five reviewed iPhone files are portrait PNGs in sRGB.

## Blocking Corrections

1. Create a 13-inch iPad screenshot set because the build setting is `TARGETED_DEVICE_FAMILY = 1,2`.
2. Re-render iPhone slot 2 so "Needs keyword and skills alignment" is not truncated.

## Upload Recommendation

Upload the five corrected 1290x2796 iPhone images to the 6.9-inch iPhone section. Do not upload the 6.5-inch duplicates as additional screenshots in the same section. Upload a separate iPad set to the 13-inch iPad section.
