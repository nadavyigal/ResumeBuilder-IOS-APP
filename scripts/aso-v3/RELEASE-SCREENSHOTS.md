# Release screenshot candidates, 31 Oct 2026

Four panels replace the old five-panel marketing fixture set:
1. Home: check a resume against a job.
2. Match Check: estimated fit and gaps.
3. Add only if true: opt-in phrase confirmation.
4. Resume Diagnosis: before/after change review.

Source: actual iPhone 17 and iPad Pro 13-inch (M5) simulator captures of the pricing worktree Debug app. Home is the normal app surface. The other screens use the release views through existing DEBUG smoke harnesses with example data. They are not synthetic MarketingScreenshotView renders. The example-data label is present in the final artwork. These captures do not prove that a release build is uploaded, a payment product is enabled, or any feature is available to users.

The pricing worktree is read-only for this track. Its current source was built successfully into this track's ignored DerivedData. Both simulators were refreshed and verified as 1.6.0 (36). The requested ASC draft is 1.5.7, so the upload target must be confirmed before upload. It has in-progress T1 changes. Source hashes and capture device/launch records are in audit/aso-v3-t2. Compare the final submitted build if release UI changes again.

Original full captures are retained under release-captures/iphone and release-captures/ipad. Final artwork frames excerpts of those captures. Home ends above the unmeasured recruiter timing line. The iPad excerpt keeps the actual wide adaptive layout. No phone crop is used for iPad. The Resumely avatar stays outside the app content and is not mirrored.

The old PDF and expert panels are removed from this candidate set. This set makes no PDF purchase or expert-tool promise. The paywall was inspected separately in audit/aso-v3-t2/ipad-paywall-current.png and against pricing-v2-s3 references; it is not an upload asset. Its fixture prices are not verified live StoreKit prices.

## Reproduce

The app must already be installed on the two documented simulator IDs. Do not use iPhone 17 Pro.
Compile the local OCR helper if needed:

```
swiftc audit/aso-v3-t2/ocr.swift -o audit/aso-v3-t2/ocr
python3 scripts/aso-v3/capture-release.py
python3 scripts/aso-v3/render-release.py
```

`CHROME_BIN` can select an installed Chrome binary. Final validation records its version. The renderer uses fresh staging directories, checks every required image, validates exact dimensions and RGB mode, then copies the complete set into the release folders. It captures four exact-size panels in a vertical browser grid for each slot and splits the resulting PNG at exact panel boundaries. It awaits every panel's image readiness and fails on browser/protocol errors. The HTML pins the artwork canvas to the requested pixel size so Chrome's window chrome cannot leave a white strip.

No ASC changes are performed. App Preview remains HOLD and is separate from these screenshots.
