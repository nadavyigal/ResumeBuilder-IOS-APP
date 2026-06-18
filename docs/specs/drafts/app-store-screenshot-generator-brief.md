# Product Brief — App Store Screenshot Generator

**Date:** 2026-06-05
**Author:** Codex
**Status:** Draft

---

## Problem

Resumely currently generates five attractive marketing screenshots, but they cover only half of the product story, one contains truncated copy, and there is no required iPad set. The duplicated 6.5-inch exports are alternate sizes, not five additional App Store screenshots. This leaves the App Store listing incomplete and makes screenshot production dependent on manual resizing and review.

## Solution

Expand the app's launch-argument-only marketing mode into a deterministic catalog of 10 unique scenes. Render every scene for both Apple's 6.9-inch iPhone and 13-inch iPad screenshot wells, then export validated PNGs and a manifest from one local capture workflow.

## User Story

As the app owner, I want Resumely to generate its own polished App Store screenshot sets so that I can drag the files into App Store Connect without editing, resizing, logging in, or exposing real user data.

## Scope (In)

- Ten unique English (US) screenshot scenes using Resumely's existing dark visual language.
- One 6.9-inch iPhone set of 10 accepted-size portrait PNGs.
- One 13-inch iPad set of 10 accepted-size portrait PNGs.
- Deterministic fictional resume, job, score, and application data.
- Responsive SwiftUI layouts for phone and tablet.
- A local capture/export script using Xcode and `simctl`.
- Automated checks for count, dimensions, format, alpha rendering, and duplicate files.
- Visual review of all 20 final images before replacing the old screenshot set.

## Scope (Out)

- Uploading files to App Store Connect.
- App preview videos.
- Localized screenshot sets beyond English (US).
- Live API, authentication, StoreKit, or production user data in screenshot mode.
- New SPM packages or design tools.
- Changing normal app navigation or behavior.

## Success Metrics

- `dist/app-store-screenshots/app-store-v1/iphone-6.9/` contains 10 unique, ordered PNGs accepted by Apple's 6.9-inch well.
- `dist/app-store-screenshots/app-store-v1/ipad-13/` contains 10 unique, ordered PNGs accepted by Apple's 13-inch iPad well.
- No visible clipping, truncation, placeholder copy, personal data, or unsupported product claim.
- All scenes accurately represent functionality available in the submitted build.
- A single documented command regenerates the complete set.
- Xcode build, tests, and screenshot-mode simulator smoke tests pass.

## Open Questions

1. Final marketing copy can be refined during implementation, but it must remain accurate to v1.0 behavior.
2. The initial set will use English (US); future localization should be a separate story.

## Risks

- iPad layouts may look stretched if phone compositions are merely scaled instead of recomposed.
- Screenshot copy can become inaccurate if product behavior changes after capture.
- Simulator status-bar time can vary unless capture setup is normalized.
- SwiftUI text can truncate differently across devices, so every output must be inspected at final pixel dimensions.
