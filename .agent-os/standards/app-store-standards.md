# App Store Standards — ResumeBuilder iOS

---

## No Placeholder UI

Before App Store submission, verify:
- No "Lorem ipsum" text anywhere
- No "TODO" or "Coming soon" labels visible to users
- No debug-only screens reachable in production
- No hardcoded test data displayed in UI

---

## Privacy Strings

Every permission the app requests must have a usage string in Info.plist:
- `NSPhotoLibraryUsageDescription` — if user can pick a resume from Photos
- `NSCameraUsageDescription` — if camera is ever used (unlikely for this app)
- `NSUserNotificationsUsageDescription` — if push notifications are requested

---

## App Icon

- All required icon sizes must be in `Assets.xcassets`
- No transparent pixels in app icon (Apple rejects these)
- Icon must look good at both 60×60 (home screen) and 1024×1024 (App Store)

---

## Launch Screen

- Launch screen must not be blank white (jarring on dark-mode-only app)
- Launch screen should match the app's visual identity
- Launch screen must not display user data (it may be shown in app switcher)

---

## Store Listing Quality

- Description must be written in clear English (no machine-translated text)
- Screenshots must show the actual app — not wireframes or mockups
- Keywords should be relevant and not stuffed with irrelevant terms
- Subtitle (30 chars) should be compelling and unique

---

## IAP Review

- All in-app purchase products must be in "Ready to Submit" state in App Store Connect
- Product IDs must match exactly what the code uses in `StoreKitManager.swift`
- IAP must be tested on a physical device with a sandbox account before submission

---

## Compliance

- Answer "Yes" to uses encryption (HTTPS)
- Answer export compliance questions correctly
- No use of private APIs (grep for `_UIPrivate`, etc. before submission)
- No UIWebView usage (App Store rejects apps using UIWebView — use WKWebView only, which this app already does)
