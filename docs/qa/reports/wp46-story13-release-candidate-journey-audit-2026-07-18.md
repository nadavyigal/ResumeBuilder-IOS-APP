# WP-46 Story 13 Release-Candidate Journey Audit

**Audit date:** 2026-07-18  
**Candidate:** `main` at `ca643294726f2546c6a01b7a98821cc11d8e1c09`  
**Version:** 1.4.2 (12)  
**Runtime:** Xcode 26.5, iOS 26.5 only

## Current verdict

**Physical gate PASS (2026-07-19), with two defects found and fixed during the run.** The founder ran the physical checklist below on Nadav.Yigal's iPhone (iPhone 13). Two real, previously-unverified defects surfaced — both are exactly what this gate exists to catch, since neither was reachable by simulator/automated evidence. Both are fixed, deployed, and reverified live on-device. See "Physical gate result — 2026-07-19" below for the defect record and an honest per-row confirmation status.

## Physical gate result — 2026-07-19

**Defect 1 — saved-résumé download silently no-op'd on a stale token.** `SavedResumePickerSheet`'s row tap and the Story 12 automatic second-job reuse both grabbed `appState.session?.accessToken` directly with no retry and, on failure, set an error `@State` that was never rendered — so a tap did nothing, no error, no feedback. Fixed in `ResumeBuilder IOS APP` commits `9e9337d` (picker) and `ce79d3b` (preview export, same pattern) on this branch: both now retry via `AppState.callWithFreshToken` and render a visible error banner on failure.

**Defect 2 — saved-résumé download used the wrong id, unrelated to auth.** After Defect 1's fix, downloads still failed 100% of the time (confirmed live via a temporary debug print, both on a several-hours-old résumé and a same-session one). Root cause: `downloadToCache` called `/api/download/{id}` with the `saved_resumes` row id, but that endpoint regenerates a PDF from an `optimizations` row by id — a completely different resource. The backend's `saved_resumes.optimization_id` column has always held the correct id but was never returned by the `/api/v1/resumes` list, save, or rename responses, so no client could ever construct a working download. This means saved-résumé reuse likely never worked in production before this fix, for any user, predating Stories 12/13.
- Backend fix: `new-ResumeBuilder-ai-` PR #116, merged to `main`, deployed to production (`www.resumelybuilderai.com`) 2026-07-19 — adds `optimization_id` to all three response shapes, additive/no schema change.
- iOS fix: commit `c02089e` on this branch — adds `SavedResume.optimizationId` and switches `downloadToCache` to use it.
- Reverified live on-device after both deployed: saved-résumé download and the Story 12 "Optimize for another job" auto-reuse both succeed end-to-end, confirmed by the founder.

**Per-row confirmation status** (checklist below, plus the Story 8 leftover item):

| Row | Status |
|---|---|
| 1. Signing prompt + Run | Confirmed — run repeatedly across this session's rebuild cycles |
| 2. Home opens, Files picker selects a résumé | Confirmed |
| 3. résumé → job → guest diagnosis → sign in → Fit → review → Apply | Confirmed — reached Optimization Review multiple times |
| 4. No placeholder / unsafe default / regressive default / blank Apply destination / locked-tab contradiction | **Not explicitly re-checked this session** — nothing bad was reported, but the founder was not asked to specifically inspect each condition |
| 5. Optimized preview, export/share, save to Files, reopen, verify selectable text | Preview and export/share confirmed working; the specific reopen-and-verify-selectable-text step was not separately confirmed |
| 6. Terminate/relaunch recovers same optimization + saved state | Confirmed — exercised repeatedly via rebuild/relaunch cycles this session, state recovered cleanly each time |
| 7. Hebrew/RTL preview + export, mixed-language alignment | **Not run this session** |
| 8. "Optimize for another job" reuses saved résumé, prior output accessible, Home focuses empty job input | Confirmed working after both fixes deployed |
| Story 8 leftover: Home → Fit opens the carried job directly (not a blank re-entry form) | **Not separately confirmed this session** — Fit was exercised via the upload flow, not a direct Home → Fit tap |

**Founder decision:** proceed with merge and version bump on the strength of the above — the golden path, both new-in-Story-12 flows, and relaunch recovery are confirmed; rows 4, 7, and the Story 8 item remain open, lower-risk items for a follow-up pass rather than blockers.

## Automated evidence

- Dedicated iPhone 17 simulator `EAC6E600-FFC4-465A-8C7B-3BC26EE28C2F` was shut down, erased, freshly booted on iOS 26.5, and waited through first-boot migration to a terminal ready state.
- The exact candidate Debug app installed and launched on that erased simulator. Fresh Home rendered after the normal launch wait with no stale account, résumé, job, or optimization state.
- Full candidate suite passed: 197 XCTest tests with 1 intentional live-fixture skip, plus 5 Swift Testing tests, 0 failures. Total: 202 tests.
- Story 12's final generic-device Release build was produced from tree `3b5becdb433f989fab406ec7c40df6633e521b9d`, which is byte-for-byte the tree merged as candidate `ca64329`; Xcode store validation succeeded with code signing disabled.
- Physical iPhone 13 `00008110-00192DDA2143801E` is connected, available, and selected by Xcode. Device compilation and linking succeeded. Command-line signing reached the Apple Development identity and provisioning profile, then macOS Keychain denied the signature with `errSecInternalComponent`. The project was opened in Xcode so the founder can authorize signing and Run on-device.
- Hebrew catalog missing count is 0. The compiled touched-string regression and placeholder-parity checks are green from Stories 11–12.

## Original 20-checkpoint delta

“Automated” means the state is covered by the exact candidate's tests/build or fresh-launch evidence. “Manual” means direct UI observation is still required before the row can become Pass or Fail.

| # | Original checkpoint | Candidate change | Evidence now | Status |
|---:|---|---|---|---|
| 1 | Fresh Home | Same focused promise; accessibility and RTL fixes applied | Erased iPhone 17 launch rendered cleanly | Pass |
| 2 | Résumé selected and job requested | Job input scroll/focus and file guidance retained | File-picker and selected-file UI need taps | Manual |
| 3 | Job description ready | Shared URL/100-word policy and inline guidance | Boundary tests green | Manual |
| 4 | Server validation failure | Friendly local validation replaces technical 400 copy | Validation policy and tracking tests green | Manual |
| 5 | Analysis processing | Existing recruiter-style loading state retained | Build/test only | Manual |
| 6 | First diagnosis and score | Placeholder safety, continuity, and evidence extraction added | Safety/decoder/continuity tests green | Manual |
| 7 | Sign-in gate after value | Guest diagnosis persists through auth | Continuity tests green | Manual |
| 8 | Account creation | Visible labels, VoiceOver names, focus chain, Apple/email paths | Compiled localization and accessibility review green | Manual |
| 9 | Analyze again after signup | Carried diagnosis offers user-initiated Continue to optimize | Transition tests green | Manual |
| 10 | Redundant fit confirmation | Carried Fit runs once automatically; job remains editable | Fit continuation tests green | Manual |
| 11 | Fit result credibility | Fit merged into continuous diagnosis path | Service/view-model tests green | Manual |
| 12 | Review predicts regression | Regressive/factual changes default off and require confirmation | Safety policy tests green | Manual |
| 13 | Education removes evidence | Accept/Skip plus verbatim evidence; unsafe facts remain gated | Evidence/safety tests green | Manual |
| 14 | Blank after Apply | Stable review destination and deterministic Apply-to-preview route | Navigation/model-lifetime tests green | Manual |
| 15 | Optimized remains locked | AppState is the single recovered optimization source | Reconciliation tests green | Manual |
| 16 | Design remains locked | Same AppState optimization ID drives Design | Golden-path cross-tab test green | Manual |
| 17 | Expert remains locked | Same AppState optimization ID drives Expert | Golden-path cross-tab test green | Manual |
| 18 | Account contradicts tabs | Account and tabs use the same reconciled optimization | Reconciliation tests green | Manual |
| 19 | Saved résumés empty | Preview-owned save persists server response by optimization ID | Save/relaunch tests green | Manual |
| 20 | Hebrew Home mixed language | Catalog missing count 0; RTL chrome artifacts removed | Hebrew simulator QA green | Manual |

## Added completion and retention checkpoints

| Check | Required observation | Status |
|---|---|---|
| Optimized preview | Real generated résumé appears, contains applied changes, and does not render blank | Manual |
| Export and share | Share sheet opens; Save to Files succeeds; PDF opens with all sections and selectable text | Manual |
| Relaunch recovery | Terminate/relaunch restores the same optimization and saved state | Manual |
| Hebrew / RTL PDF | Preview and exported PDF preserve RTL and mixed Hebrew/English alignment | Manual |
| File picker | Files picker opens and a PDF/DOCX can be selected without a dead-end | Manual |
| Second-job loop | “Optimize for another job” reuses the saved optimized résumé, preserves prior output, and focuses an empty job input | Manual |

## Physical iPhone checklist

Run from the already-open Xcode project with destination **Nadav.Yigal’s iPhone**:

1. Approve the macOS Keychain signing prompt and press Run.
2. Confirm Home opens and the Files picker can select a résumé.
3. Complete résumé → job → guest diagnosis → sign in → Fit → review → Apply.
4. Confirm no placeholder, unsafe default factual change, regressive default selection, blank Apply destination, or locked-tab contradiction appears.
5. Open the optimized preview, export/share, save the PDF to Files, reopen it, and verify selectable text plus all sections.
6. Terminate and Run again; confirm the same optimization and saved résumé recover.
7. Switch to Hebrew; confirm Home and the generated preview are RTL-clean, then export again and inspect mixed Hebrew/English alignment.
8. Tap “Optimize for another job”; confirm the saved optimized résumé is reused, the prior output remains accessible, and Home focuses an empty job input with the résumé context banner.

## Trust and monetization decision

Monetization remains **deferred/off**. Story 10 established the clean-cohort sample gate, but the new canonical activation events have no released clean cohort yet. No pricing, paywall, or purchase decision is justified until this physical journey passes and the clean cohort reaches the documented minimum sample.

## Release decision rule

- **Pass:** every manual row above is observed, exported PDF checks pass, and no critical/high trust or completion defect is found.
- **Fail:** any blank completion state, contradictory optimization state, fabricated/unsafe recommendation default, missing saved output, unusable export, broken RTL PDF, or broken second-job recovery is observed.
- **Current (2026-07-19):** PASS by founder decision — see "Physical gate result — 2026-07-19" above. Golden path, relaunch recovery, and both Story 12 flows (auto-reuse, manual picker) are confirmed after fixing and deploying the two defects found during this run. Rows 4, 7, and the Story 8 leftover item were not independently re-checked this session and remain open as lower-risk follow-up, not blockers. Merge and version bump are authorized; archive/signing/ASC submission is a separate, not-yet-done step.
