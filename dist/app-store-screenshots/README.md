# Resumely App Store Screenshots

Generate the complete upload package:

```bash
./scripts/generate-app-store-screenshots.sh
```

The 1206x2622 set comes from an iPhone 17 simulator, iPhone only:

```bash
IPHONE_ID=<iPhone 17 simulator id> IPHONE_DIR=iphone-6.3-1206x2622 CAPTURE_IPAD=0 ./scripts/generate-app-store-screenshots.sh
```

Final drag-and-drop folders:

- `app-store-v2/iphone-6.3-1206x2622/` (Apple's required "Dynamic Island, medium display" size)
- `app-store-v2/iphone-6.5-1242x2688/`
- `app-store-v2/ipad-13/`

Each folder contains 5 ordered PNG files, one per `MarketingScreenshotSlot`. `app-store-v1/` is the June 2026 10-slot set, kept as history; do not upload it. Upload each directory to its matching App Store Connect device-size section.
