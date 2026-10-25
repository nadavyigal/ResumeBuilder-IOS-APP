# Resumely 1.5.6 (35), October 25, 2026

Status: build uploaded, processed and selected; final submission not performed yet. Release branch: `release/1.5.6-35`, PR #213. Runtime base: merged main `7ff303de60bf94924dae7f3c21843d358168a63b`. Only Debug/Release version/build metadata changes; runtime code is unchanged.

## Binary and tests

- Both configurations advance from 1.5.4 (33) to 1.5.6 (35). This candidate includes the merged account/consent fixes and payment implementation. Intermediate 1.5.5 was not uploaded.
- Project plist and whitespace checks pass. All 11 Python release-script tests pass.
- Full iOS 26.5 iPhone 17 Pro simulator run: 582 XCTest cases, one skipped, zero failures, plus five Swift Testing cases. `/tmp/resumely-release-1-5-6-tests.xcresult`.
- Signed Release archive passes: `/tmp/Resumely-1.5.6-35.xcarchive`. Version/build, expected bundle, production API host and no unintended source/config documents in the payload verified.
- App Store distribution export passes: `/tmp/Resumely-1.5.6-35-export/ResumeBuilder IOS APP.ipa`. Extracted package metadata matches; deep/strict signature verification passes. Distribution entitlements contain `get-task-allow=false`, Sign in with Apple and `beta-reports-active=true`.
- Xcode upload succeeded at 07:49:35 Asia/Jerusalem. ASC processed build 35; selected and saved on version 1.5.6. No upload is pending.
- Store-version validator intentionally exits 1 for this future candidate: repo 1.5.6, live App Store 1.5.4 released October 22. This is not shipped-version drift on main.

## Device and payment evidence

- Connected iPhone 13 runs build 35, confirmed in Xcode Devices.
- #212 at `71f6f9f` records the final prior real iPhone five-pack Sandbox purchase (+5), automatic export (-1), new export (-1), free repeat and balance 3. This is prior dated evidence, not a repeated purchase today. No production-money sale is inferred.
- Founder explicitly approved resetting only the existing App Review demo account from three credits to zero. The conditional one-row update returned zero; a separate read confirmed it. Purchase/unlock ledger history was preserved.
- Today the founder signed in, tailored a new resume and reached the actual paywall. Physical screenshot captured at 07:34 Jerusalem shows all three real StoreKit prices: ILS 12.90 / 39.90 / 59.90. No purchase performed today.
- Real screenshot is outside git: `/Users/nadavyigal/Desktop/Resumely-1.5.6-assets/paywall-review-iphone13.png`. No credentials or user resume files are committed.
- P2 #210/#211 remain accepted follow-ups, not falsely marked fixed.

## App Store Connect

- Version 1.5.6 created as Prepare for Submission; build 35 selected and saved. EN release notes and actual purchase-review instructions saved. Existing review credentials are retained.
- All three consumables (`resumely.exports.1`, `.5`, `.10`) have the actual paywall screenshot uploaded and are Ready for Review in one draft submission. The one-export product was initially rejected for a missing screenshot; that field is now supplied and validation passes.
- English native iPhone 6.3 screenshot set uploaded and ordered: Tailor, Blockers, AI edits, Templates, Expert.
- English iPad 13 screenshot set replaced with five validated images in the same order. Old candidate references were removed; originals remain in Asset Library.
- English iPhone 6.5 replacement upload completed with five images; final order verification remains before submission. All 15 local marketing PNGs pass expected dimensions, opacity and uniqueness checks.
- Header/search creative asset experiment stays separate; no creative asset assigned to this release. HE screenshots remain check-only under the existing publishing checklist.

## Privacy disclosure correction

The prior published ASC label declared Name, Email Address, User ID and Other User Content only. Release source additionally sends persistent installation/session IDs (aliased to the account), product interaction events, purchase-completed product/price/currency and technical error codes through AnalyticsService; the server retains purchase ledger records.

- Published Device ID: Analytics, linked to identity, not used for tracking.
- Published Purchase History: App Functionality and Analytics, linked to identity, not used for tracking.
- Published Product Interaction: Analytics, linked to identity, not used for tracking.
- Other Diagnostic Data remains incomplete: App Functionality and Analytics selected, linked-to-identity selected; continue through tracking definitions, select no tracking, then Publish.
- Existing User ID still needs Analytics added alongside App Functionality.
- No card details are collected by this implementation. No advertising-ID or advertising-tracking code was found in the iOS source search.
- Desktop control first stopped because the Mac locked. Founder confirmed unlock, but computer-control tools were then unavailable in the continuation. No final submission is claimed.

## Review and remaining steps

- Hosted Codex completed clean on original metadata head `0297189`; later commits record validation/status only and need one final-head request.
- Independent fresh read-only review at `c4bd49b` passes with no release blockers. Two stale documentation statements were identified for this final rewrite; no runtime fix or repeated test run required.
- Verify 6.5 screenshot order, finish the two privacy items above and add version 1.5.6 to the existing three-product draft. English (U.S.) is the only existing ASC localization; Hebrew is an add-localization option, not a missing release-note field.
- Complete current-head PR pre-check per Agentic OS GLOBAL-WORKFLOWS 7b, integrate the release metadata, and submit the combined app/products when ready.

## Boundaries and tooling

Public billing remains off. No sale before October 31 and no public activation performed. This release preparation does not change pricing, server configuration, migrations or account credentials.

The extension upload bridge rejects local-file access; its Chrome settings URL was blocked by browser policy and not bypassed. The founder restored the ordinary native Open picker, which allowed the agent to select the staged images through supported UI controls. No extension/security settings were changed by the agent.
