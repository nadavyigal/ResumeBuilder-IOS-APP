# Resumely App Store asset publish checklist (October 2026)

Founder steps in App Store Connect. Claude prepared the files.

## Status (updated 2026-10-20)

| Part | State | Source |
|---|---|---|
| A. Screenshots (rb-aso-002) | **Not done.** Waits for the next editable version (1.5.4 or later). | n/a |
| B. Creative asset upload | **Done** 2026-10-20: `Header and search, Oct 2026`, ID `16c00019-3ed0-88dd-8028-aab55aafa4f4`. | Claude session, App Store Connect in Chrome |
| C. Preview | **Not done.** No editable version had the placements free that day. Must happen before part E. | n/a |
| D.1 Submit the next version | **Not done.** | n/a |
| D.2 Submit the creative asset standalone | **Done** 2026-10-20 11:34, "1 Item Submitted", Apple says up to 48 hours. | Claude session, founder's yes |
| E. Publish the creative asset | **Not done.** Needs Apple's approval, part C, and the founder's yes. | n/a |

Do not upload or submit the universal asset (`Header and search, Oct 2026`) again. The only exception is the crop fallback in part C step 5, which uploads the two dedicated files as new assets. Pick up at part A when the next version exists, and run part C on it.
App: **Resume AI - CV Builder** (Apple ID 6776752349). Locale for every step: **English (U.S.)**.

Specs read from Apple on 2026-10-19:
[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications),
[Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications),
[Manage your App Store assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets),
[Submit assets from Asset Library](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-assets-from-asset-library).
Button names below are from those pages. The live App Store Connect screens were not opened, so a label may differ slightly.

## What you are publishing

| Experiment | What | Files | Goes live |
|---|---|---|---|
| rb-aso-002 | 5 new screenshots, replacing the 10 June ones (they claim an "ATS score") | `dist/app-store-screenshots/app-store-v2/` | With the next version you submit (1.5.4 or later) |
| rb-aso-003 | New creative asset: product page header and search results | `dist/app-store-creative-assets/` | Standalone, after its own review |

Which version to edit: screenshots can change only while a version is editable (Prepare for Submission,
Rejected, Developer Rejected, Metadata Rejected, Invalid Binary). Updated 2026-10-20:

- **1.5.2** is live (Ready for Distribution). Do not edit it.
- **1.5.3 (32)** is already submitted for review without these screenshots (reported 2026-10-20). Do not remove it from review for this.
- Use the **next version**, the one marked **Prepare for Submission** (1.5.4 or later). If none exists yet, click
  **+** next to **iOS App** in the sidebar and enter the next version number. Do part A on that version before you
  submit it. If 1.5.3 is rejected and comes back editable, you may use 1.5.3 instead.

## Which files go where

Apple's rule today: at least one **iPhone with Dynamic Island (medium display)** screenshot, and an
**iPad 13-inch** one because Resumely runs on iPad (device family 1,2). The old 1242x2688 set is only a
fallback that Apple scales down for that slot, so this pack adds a native 1206x2622 set.

| App Store Connect section (older label) | Folder | Size |
|---|---|---|
| iPhone with Dynamic Island (medium display) (iPhone 6.3") | `app-store-v2/iphone-6.3-1206x2622/` | 1206x2622 |
| iPhone with Face ID (large display) (iPhone 6.5") | `app-store-v2/iphone-6.5-1242x2688/` | 1242x2688 |
| iPhone with Dynamic Island (large display) (iPhone 6.9") | none: leave empty, Apple scales from the 6.5" set | |
| iPad 13" display | `app-store-v2/ipad-13/` | 2064x2752 |

Upload order in every section, left to right:

1. `01-tailor.png`
2. `02-blockers.png`
3. `03-ai-edits.png`
4. `04-templates.png`
5. `05-expert.png`

## A. Swap the screenshots (rb-aso-002)

1. Open App Store Connect, click **Apps**, then **Resume AI - CV Builder**.
2. In the sidebar under **iOS App**, click the version marked **Prepare for Submission** (1.5.4 or later, see above).
3. Top right language menu: confirm **English (U.S.)**.
4. Under **Product Page Information**, click the **App Previews and Screenshots** tab.
5. On the right, click **View All Sizes in Media Manager**.
6. Delete the old screenshots. In each iPhone and iPad section that has images (expect 10 per section),
   hold the pointer over each one and click the **Delete (–)** button until the section is empty.
   Do this for every iPhone size that shows its own images, including 6.9" if it has any, and iPad 13".
   Deleting also removes the scaled copies in smaller sizes; that is expected.
7. Go back to the version page, **App Previews and Screenshots** tab.
8. Select the **iPhone** device tab, Dynamic Island (medium display) / 6.3" well. In Finder, select the 5
   files in `iphone-6.3-1206x2622/` in order and drag them into the well.
9. Same for the Face ID (large display) / 6.5" well with `iphone-6.5-1242x2688/`.
   If the screen shows only one iPhone well, use the 6.3" set there and add the 6.5" set from
   **View All Sizes in Media Manager**.
10. Select the **iPad** device tab, 13" well, drag the 5 files from `ipad-13/`.
11. Check each well reads 01 to 05 left to right. Drag a thumbnail to fix the order if needed.
12. Click **Save** (top right).
13. Hebrew check, do not edit: switch the language menu to **Hebrew**. If the Hebrew page still shows
    the June screenshots with "ATS score", note it for a separate Hebrew story. Switch back to English.

## B. Upload the creative asset to the Asset Library (rb-aso-003)

Upload it on its own so it has its own publish date and its own before/after read.
Do **not** leave it on any version page (part C removes it after the preview).

**Done 2026-10-20 (Claude, in Chrome):** uploaded `resumely-universal-5244x2950.png`, named
`Header and search, Oct 2026`, asset ID `16c00019-3ed0-88dd-8028-aab55aafa4f4`. Works With lists both
**Search Results** and **Product Page Header**. Status at upload: Prepare for Submission. It was then submitted standalone (next note).
Preview was not possible that day: 1.5.3 is Waiting for Review (its Header well is locked, no Browse Assets),
and live 1.5.2 only offers **approved** assets. So the preview happens either on the next editable version
(part C). Part E does not replace it: run part C on an editable version before publishing.

**Submitted 2026-10-20 11:34 (Claude, founder's yes):** standalone submission from the Asset Library with only this
asset in it, reviewed against the latest iOS version. Apple: up to 48 hours. So part D.2 is done for the
creative asset. **Part C (the preview) is still open.** Next: after approval, run part C on the next editable version,
then part E, and **only with the founder's yes**.

Steps 1 to 5 below are kept for reference. They are done; do not repeat them.

1. In the app sidebar, click **Asset Library**.
2. Click the **add (+)** button, then **Upload Creative Assets**.
3. Choose `dist/app-store-creative-assets/resumely-universal-5244x2950.png`, then click **Upload** (bottom right).
4. Click the uploaded asset. In **Name**, type `Header and search, Oct 2026`. Click **Save**.
5. Check the **Works With** section lists both **Product Page Header** and **Search Results**.
   If it lists only one, delete the asset (**Delete Asset** at the bottom of the detail page) and upload the two
   dedicated files instead: `resumely-header-3840x1646.png` and `resumely-search-3840x2560.png`.

## C. Preview check (before any submit)

Preview lives on the version page, so put the asset on **both** placements of the next version, look, then
remove it from **both** again. Apple: "After your version is approved and released, the creative assets on your
product page header and in search results also go live on the App Store." Leaving either placement filled would
ship the asset with the screenshots on the same day and mix the rb-aso-002 and rb-aso-003 reads.

1. Open the next version (the one you used in part A), **Product Page Information**, **Header and Search Results** tab.
2. Click **Header**. Click **Browse Assets**, choose `Header and search, Oct 2026`, click **Save**.
3. Click **Search Results**.
   - Universal file (the default): tick **Use header asset in search results**. Apple offers this only for universal assets.
   - Dedicated files (fallback from part B step 5): click **Browse Assets**, choose `resumely-search-3840x2560.png`, click **Save**.
4. Click **Preview**. Check each view and tick it here:
   - [ ] iPhone, product page header, light mode
   - [ ] iPhone, product page header, dark mode
   - [ ] iPhone, search results, light and dark
   - [ ] iPad portrait, header and search
   - [ ] iPad landscape, header and search
   In every view: the two headline lines and the line under them are fully visible and not covered by the
   app icon, name or Get button, and the phones are not cut through the middle of the text.
5. If a crop cuts the words, close Preview and remove the asset from both placements (step 6). Then use the two
   dedicated files. They are **not in the Asset Library yet** (only the universal file was uploaded), and
   **Browse Assets** lists only assets that are already there:
   1. Upload both with part B steps 1 to 4: `resumely-header-3840x1646.png` named `Header, Oct 2026`, and
      `resumely-search-3840x2560.png` named `Search, Oct 2026`. Check each one's **Works With** lists its placement.
   2. Submit both standalone with part D.2 (tick both in the Asset Library), and wait for Apple's approval
      (up to 48 hours). The live **Publish** path in part E can only use approved assets.
   3. Repeat steps 2 to 4 here with them: **Header** gets `Header, Oct 2026`; for **Search Results** leave
      **Use header asset in search results** unticked and choose `Search, Oct 2026`.
   Log in the rb-aso-003 row that the dedicated pair was used, with its approval date.
6. Remove it from both placements. Apple's steps: click **Header**, click **Delete**; then click **Search Results**,
   click **Delete** (if you ticked **Use header asset in search results**, untick it first). The asset stays in
   the Asset Library.
7. Check both wells are empty: **Header** and **Search Results** each show an empty well, and
   **Use header asset in search results** is unticked. Only then go on to part D.

## D. Submit

1. **The next version with the new screenshots:** on that version's page click **Add for Review**, then **Submit for Review**.
2. **Creative asset, standalone:** **Asset Library**, click **Edit** (top right), tick
   `Header and search, Oct 2026`, click **Add for Review** (top right), choose **create a new submission**,
   platform **iOS**, then **Submit for Review** in the Draft Submission pane.
   If App Store Connect says a submission is already in progress, wait until that version is approved, then repeat.

## E. Publish the creative asset after approval

Recommended timing: **28 days after the screenshots go live**, so the rb-aso-002 read is clean.
If you would rather not wait, publish it as soon as it is approved and log both rows with one shared
read (the two changes then cannot be told apart).

0. **First run part C** on an editable version (the one in Prepare for Submission): assign the approved asset to
   both placements, Preview every view, then delete both and check both wells are empty. Do not publish from the
   live version until part C's boxes are ticked. If no version is editable yet, wait for one; do not skip the preview.
1. Click the version that is **Ready for Distribution** (live).
2. **Product Page Information**, **Header and Search Results** tab, click **Header**.
3. Click **Browse Assets**, choose the approved asset, click **Next**, then **Publish**.
4. Click **Search Results**. Universal file: tick **Use header asset in search results**, then **Publish**.
   Dedicated files: click **Browse Assets**, choose `resumely-search-3840x2560.png`, click **Next**, then **Publish**.
5. Check both placements on the live page: open the App Store on an iOS 27 device, search "Resume AI", and open the product page.
6. Note today's date: it is the rb-aso-003 publish date.

The asset shows only to people on iOS 27 or iPadOS 27 and later. Older devices keep the screenshots in search.

## F. Record in the experiment log

File: `Agentic OS/distribution-os/experiment-log.md`, **Active** table. Replace the rb-aso-002 row and add
rb-aso-003. Fill `YYYY-MM-DD` with the day the change appeared on the live App Store page.

```markdown
| rb-aso-002 | ResumeBuilder iOS | ASO | Replacing the 10 June screenshots (they claim an "ATS score") with the 5-slot G1b set (no ATS, real app labels, native 1206x2622 iPhone size) will raise listing conversion | Impressions → product page views, and impressions → first-time downloads, 28 days before vs 28 days after the publish date (App Store Connect App Analytics, all territories) | 20 | published with VERSION on YYYY-MM-DD, measuring. Baseline window: YYYY-MM-DD minus 28 days to the day before publish | YYYY-MM-DD | YYYY-MM-DD + 28 days |
| rb-aso-003 | ResumeBuilder iOS | ASO | A brand-led creative asset ("See what the job asks for. Fix what's missing.") in the product page header and search results will raise conversion for iOS 27 users, where it replaces the screenshots in search | Impressions → product page views, and impressions → first-time downloads, 28 days before vs 28 days after the publish date (App Store Connect App Analytics; filter to iOS 27 if the filter exists) | unscored | approved and published standalone on YYYY-MM-DD, measuring. Confound: iOS 27 adoption still growing in the window | YYYY-MM-DD | YYYY-MM-DD + 28 days |
```

For each read, write these six numbers in the row's status cell when the 28 days end:
impressions, product page views, first-time downloads, for the 28 days before and the 28 days after.
The two rates are page views ÷ impressions and downloads ÷ impressions.

## Dated reminder, not work now

**By 2027-03-01:** iPhone Duo screenshots become required in April 2027 for any app built with the
iOS 27.1 SDK or later. Sizes: outer display 1398x2034 (portrait) or 2034x1398, inner display 2007x2853
(portrait) or 2853x2007. Add them before the first Resumely build on the iOS 27.1 SDK. The generator already
takes a device and folder (`IPHONE_ID`, `IPHONE_DIR`), so it needs an iPhone Duo simulator and a size entry
in `scripts/normalize-app-store-screenshots.py` and `scripts/validate-app-store-screenshots.sh`.

## Claim rules these files follow

- No "ATS" on any image (`CopyClaimsTests.testMarketingSlotsNeverSayATS`, EXD-012).
- No price, no "free", no score promise, no ranking (guideline 2.3.14; StoreKit gate EXD-035 is closed).
  `scripts/render-app-store-creative-assets.sh` refuses to render if the creative copy has any of these words.
- All names, companies and numbers in the screenshots are fictional.
