# Resumely App Store Screenshots

Generate the complete upload package:

```bash
./scripts/generate-app-store-screenshots.sh
```

The 1206x2622 set comes from an iPhone 17 simulator, iPhone only:

```bash
IPHONE_ID=<iPhone 17 simulator id> IPHONE_DIR=iphone-6.3-1206x2622 CAPTURE_IPAD=0 ./scripts/generate-app-store-screenshots.sh
```

`CAPTURE_IPAD=0` validates the iPhone set alone (`--iphone-only`). To re-check PNGs already in a folder without
the simulator: `SKIP_CAPTURE=1 IPHONE_DIR=... CAPTURE_IPAD=0 ./scripts/generate-app-store-screenshots.sh`.
Regression checks: `python3 -m unittest discover -s scripts -p 'test_app_store_screenshot_scripts.py'`.

**Current set: `app-store-v3/` (2026-10-28).** Upload folders and copy are in `app-store-v3/upload-manifest.md`;
it is rendered by `scripts/aso-v3/render.sh`, not by the simulator script below. `app-store-v2/` is the set live in 1.5.6.

v2 drag-and-drop folders (history):

- `app-store-v2/iphone-6.3-1206x2622/` (Apple's required "Dynamic Island, medium display" size)
- `app-store-v2/iphone-6.5-1242x2688/`
- `app-store-v2/ipad-13/`

Each folder contains 5 ordered PNG files, one per `MarketingScreenshotSlot`. `app-store-v1/` is the June 2026 10-slot set, kept as history; do not upload it. Upload each directory to its matching App Store Connect device-size section.
