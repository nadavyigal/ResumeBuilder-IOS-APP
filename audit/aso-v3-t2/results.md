# T2 screenshot results, 31 Oct 2026

State: READY FOR APPROVAL for 12 local PNGs. Confirm the ASC draft version before upload. No ASC change, commit, push, merge, message, purchase or publication performed.

## Result

Four panels in three device sizes. All 12 final PNGs viewed in the three release-*-review.jpg sheets. All are PASS for local visual and pixel checks. The manifest marks all 15 original marketing images REMOVE from the upload set. Those original files remain on disk for recovery. Only en-US exists.

The new panels show actual Home, Match Check, Add only if true, and Resume Diagnosis views. Home is the normal surface. Other views use existing DEBUG smoke harnesses and are labelled as example data. Full source captures are retained. The iPad captures use the actual adaptive iPad layout, not phone crops. The Resumely avatar and name appear on each final image. Home is framed above the unmeasured recruiter timing line. No ATS, interview, job guarantee or unmeasured app-speed promise is made in the final marketing copy. The old PDF and expert panels were removed.

## Current verification

| Check | Result | Evidence |
|---|---|---|
| Read-only pricing source Xcode simulator build | PASS | release-source-rebuild.log, BUILD SUCCEEDED |
| Installed build on iPhone 17 and iPad Pro 13-inch (M5) | 1.6.0 (36), matching executable hashes | captured-builds.json |
| Fresh actual app captures | 8/8 text checks passed | capture-release-fresh.log, capture-record.json |
| Browser renderer | Three four-panel grids captured, split at exact panel boundaries | render-release-verified.log |
| Final PNG count, dimensions, opacity | 12/12, exact size, RGB | release-outputs.json, pixel-validation.log |
| Canvas background | Four blue corners per PNG, no white strip | pixel-validation.log |
| Visual review | 12/12 PASS | three release-*-review.jpg sheets |
| Source capture visual review | Eight fresh captures viewed | iphone-fresh-captures.jpg, ipad-fresh-captures.jpg |
| Python syntax, zsh syntax, git diff whitespace | PASS | py_compile, zsh -n, git diff --check |
| Swift browser renderer compilation | PASS | renderer ran successfully after compilation |

The source version advanced during the track. Earlier installed metadata was 1.5.6 (35). Both simulators were refreshed to the fresh 1.6.0 (36) build and all eight captures were redone. The originally requested ASC target was 1.5.7. Do not upload to an assumed target. The current pricing worktree has T1 changes. This track did not edit it.

The paywall was reviewed against pricing-v2-s3 references, its adaptive simulator layout and current ExportPaywallSheet source. Its sample-price capture is audit evidence only. No paywall prices or paid PDF promises appear in the upload candidates. No StoreKit transaction was attempted.

## Earlier generator and probe evidence retained

Nine unresolved PR 225 threads were read, including the latest Steward summary. pr225.json confirms no further thread page. review-threads.md preserves full text. The source-confirmed generator issues were corrected. The preview stays on HOLD independently.

- Encoder and probe compiled. The 630-frame synthetic encoder smoke passed after an initial 60-second timeout. These are diagnostic frames, not replacement preview footage.
- Missing movie, empty frame set, corrupt f0000.png and injected Chrome failure exited 1. The probe did not hang on the missing asset.
- Existing preview: 21 seconds, avc1 886x1920, 30 fps, 3299 kbps; AAC stereo, 48 kHz; tracks enabled. Stills at 0, 2, 5, 18 and 20 seconds were viewed. Opening and ending have no app screen. HOLD.
- Chrome CLI screenshot shutdown was slow during this continuation. The final renderer uses one isolated browser session and explicit readiness/error checks. Its initial WebSocket message limit rejected a screenshot. The message limit was raised and the successful final run is recorded separately. No failed run was treated as passing.

## Not done

- No ASC state verification, upload, preview removal, version creation, build attachment or submission.
- No confirmation that the original 1.5.7 draft should receive 1.6.0 UI.
- No full browser preview-frame recapture or replacement video. The held preview was not regenerated.
- No full app unit-test or purchase suite rerun. No iOS app source was changed by this track. The current source build and actual capture checks passed.
- A final finishWriting failure was not injected. Its fail-closed guard was compiled and source-reviewed, with successful encoding and invalid-input checks retained.

## Files changed

- scripts/aso-v3: render.sh, encode.swift, probe.swift, capture-frames.js, panel.html, preview.html; new capture-release.py, render-release.py, render-release.swift, release-panel.html, release-grid.html, RELEASE-SCREENSHOTS.md and eight release-captures PNGs.
- dist/app-store-screenshots/app-store-v3: upload-manifest.md and 12 PNGs in the three release-* folders.
- audit/aso-v3-t2: capture/build/browser/pixel records, final review sheets, approval packet and verification logs. Ignored DerivedData is local only.
- tasks/todo.md, tasks/progress.md, tasks/session-log.md and tasks/lessons.md.

Taste Check: Clear blue/yellow headlines, recognisable Resumely branding, and real phone and iPad layouts.
