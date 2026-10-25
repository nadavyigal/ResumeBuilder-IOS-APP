# Resumely 1.5.6 (35), October 25, 2026

Status: release preparation, not submitted. Runtime base is merged main `7ff303de60bf94924dae7f3c21843d358168a63b`. Only Debug/Release version/build metadata changes for this candidate.

## Completed this session

- Bumped both configurations from 1.5.4 (33) to 1.5.6 (35). Intermediate 1.5.5 is not uploaded; this candidate includes its merged account/consent fixes and the payment implementation.
- Project plist and whitespace checks pass. All 11 Python release-script tests pass.
- Full iOS 26.5 iPhone 17 Pro simulator test run: 582 XCTest cases, one skipped, zero failures; five Swift Testing cases pass. Result: `/tmp/resumely-release-1-5-6-tests.xcresult`.
- ASC live read: 1.5.4 (33) Ready for Distribution; TestFlight has no 1.5.6 upload. Created 1.5.6 Prepare for Submission and saved English release notes and revised App Review instructions. No submission or upload yet.
- ASC live catalog: three existing consumables remain Prepare for Submission; one-export review screenshot field is empty. EN/HE metadata and review-note text exist.
- Xcode Devices confirms connected iPhone 13 with app build 35 installed. Screenshot capture works, but the initial capture shows iOS Settings, not a review asset.
- Read-only database check: existing ASC demo account has balance 3 and one purchase grant. Founder explicitly approved setting only this demo account to zero. The update was conditional on its observed balance of 3, returned one row at 0, and a separate read confirmed 0. Purchase and unlock ledger history was preserved.

- Rechecked all 15 existing marketing PNGs: each size set has five distinct opaque files at the expected 1206x2622, 1242x2688 and 2064x2752 dimensions. Upload staging copies are in `/Users/nadavyigal/Desktop/Resumely-1.5.6-assets/`.
- Store-version validator exits 1 as expected for a future candidate: repo 1.5.6, live 1.5.4 released October 22. This is not a claim that main/public already runs 1.5.6.

- Distribution export started with automatic App Store signing, team 8VC4R5M425 and manageAppVersionAndBuildNumber=false. No build-number rewriting or upload was requested by this export command.
- Chrome native path dialog is not accepting automated navigation. Browser extension file upload is available but requires the user-controlled Allow access to file URLs setting; no extension permission was changed by the agent.

## Existing device evidence

Payment source from #208/#209 is in main via #207. #212 at `71f6f9f` records the final real iPhone five-pack Sandbox purchase (+5), automatic export (-1), new export (-1), free repeat and balance 3. This is prior dated evidence, not a repeated device test today. Its hosted documentation review is pending. No production-money sale is inferred. P2 issues #210/#211 remain accepted follow-ups, not marked fixed.

## Blocking before submission

- Complete App Store distribution export/signing. The Release archive succeeded at `/tmp/Resumely-1.5.6-35.xcarchive`; metadata is 1.5.6 (35), expected bundle, production API, non-exempt encryption false. Deep/strict codesign verification passes and internal-file scan passes. Archive uses development signing (`get-task-allow=true`); export must be rechecked for distribution entitlements (`false`) before upload. Export is waiting inside codesign.
- Current-head release PR review and integration.
- Capture the real candidate paywall after real StoreKit product loading; attach to all three consumables and associate all three with 1.5.6. Fixture screenshots are not real purchase evidence.
- Set up the existing review demo account to reach the paywall, preserving the public-off switch; verify its allowlist and zero-credit state. The demo balance reset is approved and verified; existing unlocked resumes remain free.
- Validate/export and upload build 35, wait for processing, select it for 1.5.6, check encryption/privacy and all localizations, then submit with products.

## Billing boundary

Public `EXPORT_CREDITS_ENABLED` remains off. No public sale before October 31 and no activation performed by this release preparation. Account credentials and raw user records are not included here.
