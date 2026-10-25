# Resumely 1.5.6 (35), October 25, 2026

Status: release preparation, not submitted. Runtime base is merged main `7ff303de60bf94924dae7f3c21843d358168a63b`. Only Debug/Release version/build metadata changes for this candidate.

## Completed this session

- Bumped both configurations from 1.5.4 (33) to 1.5.6 (35). Intermediate 1.5.5 is not uploaded; this candidate includes its merged account/consent fixes and the payment implementation.
- Project plist and whitespace checks pass. All 11 Python release-script tests pass.
- Full iOS 26.5 iPhone 17 Pro simulator test run: 582 XCTest cases, one skipped, zero failures; five Swift Testing cases pass. Result: `/tmp/resumely-release-1-5-6-tests.xcresult`.
- ASC live read: 1.5.4 (33) Ready for Distribution; TestFlight has no 1.5.6 upload. Created 1.5.6 Prepare for Submission and saved English release notes and revised App Review instructions. No submission yet; build upload later succeeded as recorded below.
- ASC live catalog: three existing consumables remain Prepare for Submission; one-export review screenshot field is empty. EN/HE metadata and review-note text exist.
- Xcode Devices confirms connected iPhone 13 with app build 35 installed. Screenshot capture works, but the initial capture shows iOS Settings, not a review asset.
- Read-only database check: existing ASC demo account has balance 3 and one purchase grant. Founder explicitly approved setting only this demo account to zero. The update was conditional on its observed balance of 3, returned one row at 0, and a separate read confirmed 0. Purchase and unlock ledger history was preserved.

- Rechecked all 15 existing marketing PNGs: each size set has five distinct opaque files at the expected 1206x2622, 1242x2688 and 2064x2752 dimensions. Upload staging copies are in `/Users/nadavyigal/Desktop/Resumely-1.5.6-assets/`.
- Store-version validator exits 1 as expected for a future candidate: repo 1.5.6, live 1.5.4 released October 22. This is not a claim that main/public already runs 1.5.6.

- Distribution export started with automatic App Store signing, team 8VC4R5M425 and manageAppVersionAndBuildNumber=false. No build-number rewriting or upload was requested by this export command.
- Chrome native path dialog is not accepting automated navigation. Browser extension file upload is available but requires the user-controlled Allow access to file URLs setting; no extension permission was changed by the agent.

- App Store distribution export PASSED: `/tmp/Resumely-1.5.6-35-export/ResumeBuilder IOS APP.ipa`. Extracted package version/build, bundle and production API match. Deep/strict signature verification passes; `get-task-allow=false`, Sign in with Apple entitlement and `beta-reports-active=true` are present.
- Actual physical iPhone 13 build-35 paywall captured at 07:34 Jerusalem after the founder reached it on a new optimization at zero credits. All three localized StoreKit prices are visible: ILS 12.90 / 39.90 / 59.90. Screenshot staged outside git at `/Users/nadavyigal/Desktop/Resumely-1.5.6-assets/paywall-review-iphone13.png`; no purchase performed today.
- Build upload PASSED at 07:49:35 Asia/Jerusalem after founder completed the macOS signing prompt. Xcode reports Upload succeeded and uploaded package processing. Build 35 subsequently finished processing and was selected and saved on ASC version 1.5.6. Final review submission remains outstanding.
- Browser upload continues to reject local-file access after the founder reported enabling it and the page was refreshed. Attempt to inspect chrome://extensions was rejected by browser URL policy; no alternate route to those settings was attempted. Native screenshot selection is handed to the founder.

## Existing device evidence

Payment source from #208/#209 is in main via #207. #212 at `71f6f9f` records the final real iPhone five-pack Sandbox purchase (+5), automatic export (-1), new export (-1), free repeat and balance 3. This is prior dated evidence, not a repeated device test today. Its hosted documentation review is pending. No production-money sale is inferred. P2 issues #210/#211 remain accepted follow-ups, not marked fixed.

## Blocking before submission

- Build 35 is processed, selected and saved for 1.5.6. Release archive and App Store distribution export both pass; extracted distribution entitlements verified as described above.
- Current-head release PR review and integration.
- Attach the captured real candidate paywall to all three consumables and associate all three with 1.5.6. The screenshot is captured, not uploaded yet. Fixture screenshots were not used.
- Set up the existing review demo account to reach the paywall, preserving the public-off switch; verify its allowlist and zero-credit state. The demo balance reset is approved and verified; existing unlocked resumes remain free.
- Archive/export/upload are complete. Build 35 is processed and selected. Check encryption/privacy and all localizations, then submit with products.

## Billing boundary

Public `EXPORT_CREDITS_ENABLED` remains off. No public sale before October 31 and no activation performed by this release preparation. Account credentials and raw user records are not included here.

## Apple validation and final browser handoff

Adding the one-export consumable for review was rejected with the explicit validation: "You must add a Review Information screenshot." No consumable was added/submitted by that validation attempt. The browser file-upload bridge still reports local-file access unavailable after a connection reset; native path-navigation attempts did not work. No blocked Chrome-settings route was bypassed. The required one-export review screenshot picker is open for the founder to select `/Users/nadavyigal/Desktop/Resumely-1.5.6-assets/paywall-review-iphone13.png`. After selection, save and repeat for the five/ten packs, then associate all three with the version. Existing marketing screenshots are inherited; replacement sets are staged but not uploaded.
