# Resumely App Store Screenshots

Generate the complete upload package:

```bash
./scripts/generate-app-store-screenshots.sh
```

Final drag-and-drop folders:

- `app-store-v2/iphone-6.5-1242x2688/`
- `app-store-v2/ipad-13/`

Each folder contains 5 ordered PNG files, one per `MarketingScreenshotSlot`. `app-store-v1/` is the June 2026 10-slot set, kept as history; do not upload it. Upload each directory to its matching App Store Connect device-size section.
