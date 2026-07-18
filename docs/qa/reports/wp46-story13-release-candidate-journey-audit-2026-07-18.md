# WP-46 Story 13 Release-Candidate Journey Audit

**Audit date:** 2026-07-18  
**Candidate:** `main` at `ca643294726f2546c6a01b7a98821cc11d8e1c09`  
**Version:** 1.4.2 (12)  
**Runtime:** Xcode 26.5, iOS 26.5 only

## Current verdict

**Manual gate pending.** The candidate is code-, test-, build-, localization-, and clean-launch green. It is not yet release-certified because the authenticated 20-checkpoint journey, physical preview/export/share, physical Hebrew/RTL PDF, file picker, relaunch recovery, and second-job return loop require direct UI interaction. No App Store Connect or TestFlight action is authorized by this audit.

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
- **Current:** pending founder physical interaction. Do not submit to ASC from this state.
