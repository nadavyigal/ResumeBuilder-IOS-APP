# Resumely screenshot approval packet

State: READY FOR APPROVAL. Local asset preparation only. No commit, push, merge, ASC change, submission or publication performed.

## Release decision required

Original requested target: iOS 1.5.7 draft, en-US.
The pricing worktree now builds 1.6.0 (36). Both capture simulators were refreshed to that exact build and their executable hashes match. Evidence: captured-builds.json and release-source-rebuild.log.
Confirm which draft should receive this UI before uploading. Do not assume the 29 Oct 1.5.7 upload report describes today's live ASC state. If 1.5.7 is retained as the target, first confirm its intended release UI matches these 1.6.0 captures. Otherwise use a separately confirmed 1.6.0 draft. Do not create a version or attach a build without approval.

## Exact screenshot action

Action: replace the draft en-US screenshots with four individual PNGs per approved device slot, 12 files total, using only PASS rows in upload-manifest.md.
Device slots: medium Dynamic Island iPhone at 1206x2622; large Face ID iPhone at 1242x2688; iPad 13-inch at 2064x2752. Match current ASC labels by pixel dimensions.
Order in every slot: 01-tailor.png, 02-missing.png, 03-edits.png, 04-review.png.
Evidence: upload-manifest.md, release-outputs.json with SHA-256, three final review sheets, source capture records, build and pixel-validation logs. The review-sheet JPGs are not upload assets.
Risk: wrong version, wrong device slot, wrong locale, or release UI changes after capture. Stop if the version is not editable or the intended build differs visually.
Recovery: before removal, archive current draft screenshots, device assignments and order. Restore those assets if upload processing or review fails. Do not change the live version.
Expected result: four processed screenshots in each of the three approved en-US wells, saved in the confirmed draft. Saving and upload processing do not submit for review or make assets available to users.

### ASC steps after version and asset approval

1. Open My Apps, Resumely, the explicitly confirmed iOS draft version, English (U.S.). Record its status and selected build. Do not rename the app or change metadata.
2. Open App Previews and Screenshots, Media Manager or the Asset Library picker shown by ASC. Record the current assets and order before removing anything.
3. In each matching screenshot well, replace the old screenshot set with the four approved PNGs in the listed order. Use the release-* folders only. Do not upload compare.png, JPG review sheets, full raw simulator captures, or any movie.
4. Wait for processing. Compare the four thumbnails, dimensions, locale and order with the manifest and review sheets. Check every required device well.
5. Save. Reopen the draft to verify persistence. Do not submit for review, attach a build, or change the live version.

## Separate App Preview removal action

HOLD. The video is not part of screenshot approval and must not delay screenshot approval.
Reported target: Resumely iOS 1.5.7 draft, en-US, first App Preview slots for iPhone 6.3-inch and 6.5-inch. Confirm those slots live before changing anything.
Action after explicit removal approval: archive current slot assignments and poster frames; remove only resumely-app-preview-886x1920.mov from those two reported wells if present; save and verify. Leave screenshots alone for this action. Do not remove movies from another version without explicit scope approval.
Evidence: 29 Oct author upload report, current movie probe and stills at 0, 2, 5, 18 and 20 seconds. Opening 0 to 3 seconds and ending 17.5 to 21 seconds contain no app screen. Apple 2.3.4 requires app screen-capture footage.
Risk: loss of marketing video from this draft. No live-version change is expected.
Recovery: retained local movie under app-store-v3/app-preview. Restore only following separate compliant-content approval.
Expected result: reported held previews absent from the 1.5.7 draft after save. No submission. This does not establish that preview slots in a later draft are empty.
