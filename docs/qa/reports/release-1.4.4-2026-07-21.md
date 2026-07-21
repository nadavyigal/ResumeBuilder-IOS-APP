# Release Record — Resumely 1.4.4 (14)

**Date:** 2026-07-21
**Status:** **STAGED, NOT SUBMITTED.** Code landed on `main`; version bumped; automated gate passed. **No archive uploaded and nothing submitted to App Review.**
**Supersedes:** 1.4.3 (13), live since 2026-07-19T21:47:02Z.

---

## What this release carries

The seven-story UI/copy pass (PR #114, merge commit `026021c`):

1. **Match-language and claims repair** — the product's self-defined metric is no longer presented as an employer ATS result. ~40 user-facing strings renamed (Free Match Check, Resumely Match Score, Match insights, Improve match, Match Deep Report, ATS-friendly, simple to parse) across 24 files.
2. **Correct App Store and legal links** — the share line no longer claims "scored N% on ATS"; the internal `vercel.app` deploy URL and the `id000000000` placeholder are replaced with the real listing (`id6776752349`, verified against Apple's lookup API); Terms of Use and Privacy Policy are linked from sign-in, locale-aware and derived from `API_BASE_URL`.
3. **Correct sign-up/sign-in routing** — `OnboardingViewModel.startInSignUp` makes "Create free account" open sign-up and both "Sign in" entries open sign-in.
4. **Honest locked states** — the locked-tab mock preview that displayed a fabricated 68/100 score and fake report lines is removed. The honest unlock checklist, recovery state, and single CTA remain.
5. **Complete Hebrew localization** — catalog is 900/900 with zero fallbacks.
6. **Tab-bar, RTL, accessibility, and UI polish** — the floating tab bar's clearance is reserved once centrally via `safeAreaInset` (previously only 2 of 5 tabs reserved space); 18 hardcoded `chevron.right`/`arrow.right` symbols replaced with auto-mirroring `.forward` variants; the language switcher gets a full 44pt target and per-button VoiceOver names.

Analytics event names, API fields, and internal ATS identifiers are unchanged.

---

## Release notes (for App Store Connect — English)

```
• Clearer language. What we used to call an "ATS score" is now the Resumely
  Match Score, so it's clear this is our estimate of how well your resume fits
  a job — not a score from an employer's hiring system.
• Honest locked screens. Locked tabs no longer show a sample score. They now
  say plainly what unlocks and what it takes to get there.
• Correct links. Sharing now points to the real Resumely App Store listing,
  and Terms of Use and Privacy Policy are linked directly from sign-in.
• Fixed sign-up vs sign-in. "Create free account" now opens sign-up instead of
  the sign-in form.
• Full Hebrew. Every screen is now translated.
• Polish. Content no longer hides behind the tab bar, arrows point the right
  way in right-to-left layouts, and the language switcher is easier to tap.
```

**Hebrew release notes: NOT WRITTEN.** These were machine-drafted in earlier passes but are not included here because they have not been reviewed by a Hebrew speaker. The founder should either write the `he` locale notes or ship English-only notes for this release.

---

## Automated gate — results

| Gate | Result |
|------|--------|
| Full test suite | **PASS** — 205 XCTest, 1 intentional skip, 0 failures, plus 5 swift-testing. `** TEST SUCCEEDED **` |
| Clean Debug build | **PASS** (compiled as part of the test run) |
| Release archive build | **PASS** — `** ARCHIVE SUCCEEDED **` |
| Distribution export | **PASS** — `** EXPORT SUCCEEDED **`, upload-ready IPA produced |
| Localization parity | **PASS** — Hebrew 900/900, zero empty values |
| Placeholder parity | **PASS with pre-existing exceptions** — 4 keys where Hebrew omits an English plural-suffix `%@`, byte-identical to shipped `main`. Not introduced here; safe (Hebrew references fewer args than supplied). 16 keys sit at `needs_translation` state but all carry Hebrew values — also identical to `main`. |
| Secret / privacy inspection | **PASS** — no secrets in diff; GitGuardian check SUCCESS on PR #114 |
| `git diff --check` | **PASS** — clean |
| Analytics/API contract | **PASS** — `Core/Analytics/` and `Core/API/` have zero diff lines |

**Test environment note:** the first test run reported 5 failures. All were locale artifacts — the shared iPhone 17 simulator carried persisted app-level Hebrew language state from a prior smoke, so `NSLocalizedString` returned Hebrew against English assertions. The simulator was erased and the run repeated with `-testLanguage en -testRegion US`; 0 failures. No code defect.

**Code review note:** the CodeRabbit status on PR #114 is FAILURE with description "Review rate limited" — a quota condition. **No automated review was actually performed on this PR.** The diff was reviewed manually instead (full source diff read; pbxproj change confirmed limited to adding `CopyClaimsTests.swift`, with no signing or build-setting changes).

---

## Physical-device gate — NOT RUN

**Every item below was skipped. Build 14 has never run on real hardware.**

Both devices report Offline in `xcrun xctrace list devices`:
- `Nadav.Yigal's iPhone (26.5.2)` — `00008110-00192DDA2143801E`
- `iPhone (77) (18.6)` — `00008110-000871E21187801E`

Not executed: fresh install, resume selection/upload, job input and diagnosis, sign-in transition, apply/optimization, visible preview, export and share, terminate/relaunch recovery, second-job optimize, English and Hebrew/RTL review including PDF/export output, and on-device confirmation of 1.4.4 (14).

This matters more than usual for this release: Story 6 changed tab-bar clearance globally via `safeAreaInset` and swapped 18 directional glyphs. Those are exactly the changes a simulator render smoke is weakest at catching and a physical RTL pass is strongest at catching.

---

## Archive and export — SUCCEEDED

A signed, upload-ready App Store build exists locally. **It has not been uploaded.**

- Archive: `** ARCHIVE SUCCEEDED **`, Release configuration, `generic/platform=iOS`
- Export: `** EXPORT SUCCEEDED **` with `method: app-store-connect`
- IPA: 4.3 MB, `ResumeBuilder IOS APP.ipa`

Verified in the exported IPA:

| Property | Value |
|----------|-------|
| `CFBundleShortVersionString` | **1.4.4** |
| `CFBundleVersion` | **14** |
| `CFBundleIdentifier` | `Resumebuilder-IOS.ResumeBuilder-IOS-APP` |
| Signing authority | **Apple Distribution: Nadav Yigal (8VC4R5M425)** |
| `get-task-allow` | `false` (correct for distribution) |
| `beta-reports-active` | `true` (TestFlight-enabled) |
| `com.apple.developer.applesignin` | present |
| `API_BASE_URL` | `https://www.resumelybuilderai.com` (production, not localhost) |
| `ITSAppUsesNonExemptEncryption` | `false` |

**Artifacts are in the session scratchpad, which is temporary.** They are not committed and will not survive cleanup. The founder should re-archive from `main` in Xcode rather than rely on these paths:

```
.../scratchpad/Resumely-1.4.4-14.xcarchive
.../scratchpad/export-1.4.4-14/ResumeBuilder IOS APP.ipa
```

Note the `.xcarchive` itself is Development-signed (`get-task-allow` true) — that is normal; the distribution re-sign happens at export, which is what produced the correctly-signed IPA above.

## Version identity

- `MARKETING_VERSION` 1.4.3 → **1.4.4** (both Debug and Release config blocks)
- `CURRENT_PROJECT_VERSION` 13 → **14** (both blocks)

**Build number 14 is NOT confirmed unused in App Store Connect.** It was chosen from local evidence only: git history shows builds 6, 7, 11, 13, and Apple's public lookup API confirms the live version is 1.4.3. Neither source can see builds that were uploaded to ASC but never released (rejected, expired, or superseded). If ASC rejects 14 as taken, bump to the next free integer — no other change is needed.

---

## Blockers to submission

1. **No App Store Connect upload credential on this machine.** No API key in `~/.appstoreconnect/private_keys/`, no `notarytool`/`altool` keychain profile, no upload automation in `scripts/`. The documented process (`.agent-os/workflows/testflight-review.md` step 3) is the Xcode Organizer GUI, which cannot be driven headlessly.
2. **No physical device**, so the required release journey could not be run.

Signing itself is **not** a blocker: `Apple Distribution: Nadav Yigal (8VC4R5M425)` is present and valid, automatic signing is configured, and export compliance is pre-declared in `Config/Info.plist` (`ITSAppUsesNonExemptEncryption = false`), so ASC will not prompt for it.

## Founder actions required

1. Connect an iPhone and run the physical release journey against build 14. **Do not skip this** — see the note above on why Story 6's changes need it.
2. In Xcode: Product → Archive → Validate App → Distribute App → App Store Connect.
3. In ASC: attach build 14 to version 1.4.4, paste the release notes above, submit for App Review.
4. Keep the established release mode — do **not** choose immediate manual release to customers if ASC offers it as a separate step.
