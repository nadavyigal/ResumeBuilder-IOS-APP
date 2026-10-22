# Resumely 1.5.4 (33): release handoff, October 21, 2026

Status: automated preparation complete; not ready for distribution. Physical-device QA, actual signing/archive validation and App Store Connect acceptance remain open. No merge, signed archive, upload or submission in this session.

## Candidate and review

- Worktree: `/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-release-1-5-4`.
- Branch: `release/1.5.4-33`; PR: https://github.com/nadavyigal/ResumeBuilder-IOS-APP/pull/203.
- Original candidate: `bed42455780bce67926ab68b40ef71cdbca0ed95`; base/main: `3e36474d1ffdf5e65b32c98eaebb918d37c34f53`. This continuation changes documentation only; record its final head from the PR before building.
- Hosted Codex completed with no findings at bed4245: https://github.com/nadavyigal/ResumeBuilder-IOS-APP/pull/203#issuecomment-6315495640. Independent fresh review approved that bump. No repeat request for bed4245. Documentation follow-up receives a new-head hosted request; original independent review remains evidence for the unchanged runtime/metadata diff, not a review of the new documentation. Fresh independent review of the documentation head remains a pre-merge gate.
- Original head was CLEAN/MERGEABLE; CodeRabbit and GitGuardian reported SUCCESS. CodeRabbit's conversation says automatic review was skipped; its green status does not prove a substantive review.
- Includes #200 consent and #202 upload identity fixes. Founder-approved #202 Features/V2 placement exception remains accepted. Follow-ups: possible duplicate prompt during slow anonymous-session creation; missing failure analytics on identity-triggered replacement upload failure; disabled Fit/legacy Tailor recovery P3. No features or billing changes here.

## Verification and limits

- Prior combined-source validation: 527 XCTest tests, one skipped, zero failures; five Swift Testing tests; all 11 upload-cache tests. Reused because runtime source is unchanged.
- This session: all 11 Python script tests passed, including measurement contract. Store validator reports candidate 1.5.4 versus live 1.5.3, released 2026-10-20T22:13:51Z. Its exit 1 is the expected planned-release mismatch, not a reason to downgrade this candidate.
- Fresh unsigned generic iOS Release build: see final PR precheck for result and metadata. Log `/tmp/resumely-154-readiness-build.log`; derived data `/tmp/resumely-154-readiness`.
- Source signing: Automatic, team `8VC4R5M425`, bundle `Resumebuilder-IOS.ResumeBuilder-IOS-APP`. Only source entitlement is Sign in with Apple (`Default`).
- Keychain reports valid Apple Development and Apple Distribution identities. Matching development profile expires June 24, 2027 (one provisioned device); store profile expires July 19, 2027 (`get-task-allow=false`, Sign in with Apple present). This inventory does not prove the attached phone is included, archive signing succeeds or ASC accepts build 33. No account/provisioning mutation performed.
- `devicectl` reports both paired phones unavailable (iPhone 13 and iPhone 13 Pro). No build-33 phone interaction occurred here.
- Prior founder iPhone 13 tests on the combined development source passed guest check, decline, swipe dismissal, agree, sign-in check with the same file/job and sign-out guest check. They are useful source-regression evidence, not installed build-33 certification. Explicit relaunch persistence and final HE layout are still unverified.
- No UI changed in this continuation; simulator screenshots were not repeated. Existing consent EN/HE simulator evidence is in task history. Final phone journey must include preview/export and HE layout. Historical checklist entries saying Hebrew is unsupported or naming a Score tab are stale; test the current Home/Optimized/Design/Expert/Me flow.

## Founder phone pass

Use your own résumé or a synthetic QA résumé and a representative pasted job. Record device, iOS, exact git head, configuration, installed version/build and outcomes. Debug installation is a pre-distribution regression check; it does not certify the eventual signed Release/TestFlight binary. Preserve any unsaved local résumé work before replacing the app; no uninstall is required for this pass.

1. Connect and unlock the iPhone, trust the Mac if asked, enable Developer Mode, and confirm Xcode sees it. Open this worktree's `ResumeBuilder IOS APP.xcodeproj` directly. Before merge, deliberately select `release/1.5.4-33` and verify the PR head; do not rebuild the stale canonical main checkout. After a release merge, follow the normal main-equals-origin/main check in the QA checklist. Clean Build Folder, choose the app scheme and physical phone, then Run. Confirm build settings are 1.5.4 (33).
2. Start signed out. Pick the file and job. Tap Check: verify OpenAI disclosure and Privacy Policy link. Tap Not now: return to Home with no scan/result started. Tap Check again: disclosure appears again. Swipe it down: same outcome; the next Check asks again.
3. Agree: guest check completes and displays its result. Terminate and relaunch without signing out; repeat under the same resolved guest identity: consent persists, no prompt. If anonymous identity changed during the original prompt, the documented P2 can cause a second prompt; record that separately from a persistence failure.
4. Sign in to the real account and tailor with the same résumé and job. New account consent appears. Agree, verify fresh upload and successful diagnosis/optimization with no Resume not found. Optional evidence: correlate `resume_upload_started`/success with `optimization_started` under the signed-in identity, without recording tokens or résumé text.
5. Terminate/relaunch signed in: repeat an AI action and verify consent persists. Open an existing optimization and use chat/refine to confirm normal consent-gated entry points remain usable. Sign out: next guest check asks again and works after Agree. Decline is not stored as acceptance.
6. Switch to Hebrew in Home. Check disclosure, full-screen progress, diagnosis and main navigation: RTL order, readable text, reachable controls, no clipping. Complete preview/export, open the exported PDF in Files, inspect Hebrew text and page layout. Switch back to English for any subsequent locale-sensitive unit tests.
7. Record cold launch stability, template preview/application, and one export cancel/retry if not covered by the current release QA. Report each unchecked item explicitly; stop on a new serious defect. Do not label the full legacy QA checklist passed from these narrower checks.

## Release continuation after phone QA

Confirm the current PR head/base, hosted review and checks, then apply the founder's release merge decision under the repository gate. This report does not waive device QA or supply a separate named product-merge approval. Do not ask again for the already approved #202 placement exception.

After merge and QA, select Any iOS Device, Release archive action, correct team and bundle. Product > Archive, then Organizer > Validate App. Verify archived Info.plist is 1.5.4 (33), production API `https://www.resumelybuilderai.com`, distribution signature/profile, `get-task-allow=false`, Sign in with Apple entitlement, and no unintended internal documents or debug fixtures in the payload. Check ASC for an existing build 33 before any upload; never reuse an uploaded build number. Local inventory is insufficient to mark these steps passed.

Upload/TestFlight/App Store submission require their separate explicit distribution authorization. After an authorized upload, verify processing and install the exact TestFlight build for final core-flow smoke. App Store screenshots/creative asset work from #201 remains a separate recorded checklist; do not resubmit the already submitted standalone creative asset.

Suggested release notes: “We now ask before sending your résumé and job description to OpenAI. We also fixed a résumé upload issue when switching from guest mode to your account.” Do not claim either fix is already live.
