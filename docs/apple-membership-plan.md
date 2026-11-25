# Apple Developer membership: what to use, 2026-11-21

Study and plan only. No code, entitlement, App Store Connect or Xcode Cloud changes were made.

**Decisions from Nadav, 2026-11-21** (these override anything below that disagrees):
- RunSmart 1.2.6 is live on the App Store since 2026-11-20, not TestFlight-only.
- RunSmart is getting Hebrew. Hebrew users can't use Apple models, so the on-device debrief is a small opt-in experiment, not a priority.
- Almost all Resumely users are Hebrew (Israel). **Apple models are dropped for Resumely.**
- Beta Club = App Store users with a server-granted free-for-life invite code. TestFlight is only for pilot coaches. No external TestFlight group for Beta Club.
- PCC entitlement: yes, request it (free, no code). Nadav sends the request.
- Order of work: PR 4 and PR 5 (Xcode Cloud archives) first, then PRs 1-3. Draft PRs only, no merge, no App Store Connect or Xcode Cloud changes without Nadav's OK.
- Small Business Program: accepted 2026-11-13 (Apple email). PCC is open to Nadav's request.
- Still open: GitHub billing, OpenAI spend (Nadav will send). No Apple email shows the PCC request was sent.
Repos read: Resumely iOS (`main` @ fbe2e40), RunSmart iOS (`main` @ b901258), Resumely web (`main` @ 3a32aea), RunSmart web (branch `chore/weekly-log-cleanup`, not `main`).

**Bottom line.** The membership saves real money in one place only: CI minutes, and only if GitHub bills you for them. The free Apple LLM is real but the saving on your current calls is cents. Its value is offline, faster, private replies on RunSmart. Hebrew is not supported by Apple Intelligence, which limits it for Resumely.

---

## 1. Article claims vs Apple's docs

| Claim | Status | Source |
|---|---|---|
| Xcode Cloud 25 h/month included | Verified | [membership page](https://developer.apple.com/programs/whats-included/), [news](https://developer.apple.com/news/?id=ik9z4ll6) |
| Extra hours: 100 h $49.99, 250 h $99.99 | Verified (also 1,000 h $399.99) | [Xcode Cloud](https://developer.apple.com/xcode-cloud/) |
| Unused hours don't roll over; GitHub macOS $0.062/min | Unverified | not checked on an Apple or GitHub page |
| CloudKit allowance grows with users | Corrected: page now says "up to 1PB of free storage for each app" | membership page |
| WeatherKit 500K calls/month | Verified | membership page |
| Managed Background Assets 200 GB | Verified | membership page |
| TestFlight 100 internal / 10,000 external / 90 days | Not checked this session (not on membership page) | |
| MapKit JS 250K views + 25K calls per day | Unverified (forum posts only) | |
| On-device Foundation Models: free, no limits | Partly: no cost stated; needs iOS 26 + Apple Intelligence device + supported language. Context size is read at runtime (`SystemLanguageModel.contextSize`); "4K" not confirmed for the 2026 model | [docs](https://developer.apple.com/documentation/foundationmodels) |
| PCC: Small Business Program + under 2M first-time downloads + entitlement | Verified | [PCC page](https://developer.apple.com/private-cloud-compute/) |
| PCC: $0 token bill | Verified "no cloud API cost", but Apple adds "expanded access ... for a fee in the future" | PCC page |
| PCC: 6 months to migrate if you exceed | Verified | PCC page |
| PCC: per-user daily limit | Verified (`QuotaUsage` is a per-user budget). No number given | PCC docs |
| PCC: iCloud+ raises the limit | Unverified | |
| PCC: 32K context | Unverified in docs (cited from a WWDC26 session). Read `contextSize` at runtime | |
| PCC model API needs iOS 27 | Verified (`PrivateCloudComputeLanguageModel` introduced in iOS 27.0) | docs |
| Hebrew support | **Not supported.** Apple Intelligence lists 16 languages, Hebrew is not one | [feature availability](https://www.apple.com/ios/feature-availability/) |

---

## 2. Audit of today's setup

### 2.1 AI calls

| App | Purpose | Model | Runs on | Prompt size (est.) | Web parity | Quality-critical |
|---|---|---|---|---|---|---|
| Resumely | CV tailoring (main engine) | gpt-4o, 4,000 max output | Vercel `/api/optimize`, `/api/upload-resume` (`src/lib/prompts/resume-optimizer.ts:138`) | ~2K system + 1.5-3K CV + 1-2K JD + up to 4K out = 6-11K | Yes | Yes |
| Resumely | Match Score (semantic part) | text-embedding-3-small | Vercel `/api/ats/score` (`src/lib/ats/utils/embeddings.ts:90`) | 1-3K | Yes | Yes |
| Resumely | Section refine | gpt-4o-mini | Vercel `/api/v1/refine-section` (`route.ts:55`) | ~1-2K | Yes | Medium |
| Resumely | ATS quick wins / amendments | gpt-4o-mini, 2,000 max | Vercel (`src/lib/ats/quick-wins/generator.ts:133`, `amendment-generator.ts:157`) | ~3-4K | Yes | Medium |
| Resumely | Expert workflows (rewrite, cover letter = gpt-4o; ATS report, summary, quantifier, story bank, screening, outreach = gpt-4o-mini) | mixed | Vercel `src/lib/expert-workflows/prompts/*` | 2-6K | Yes | Yes |
| Resumely | Chat assistant | gpt-4 / gpt-4-1106-preview | Vercel `src/lib/chat-manager/*` | unknown | Yes | Medium |
| Resumely | Design recommender | gpt-4 | Vercel `src/lib/design-manager/design-recommender.ts:42` | small | Yes | Low |
| RunSmart | **Post-run debrief** | gpt-4.1-mini (env `OPENAI_MODEL`), 180 max output | Supabase edge `coach_message` intent `run_debrief` (`supabase/functions/coach_message/index.ts:46`), called from `SupabaseRunSmartServices.swift:1334` with a 12 s timeout and a deterministic fallback | ~250 system + ~300-600 run JSON + 180 out = under 1.1K | Result is saved to `run_debriefs`, so web can read it | Medium |
| RunSmart | Coach chat, flex week | gpt-4.1-mini, 220-260 max | Supabase edge `coach_message` | 1-3K | Shared with Coach Mode | Medium |
| RunSmart | Run report | gpt-4o-mini (env `RUN_REPORT_MODEL`) | Vercel `v0/app/api/run-report/route.ts:308` | unknown, larger | Yes | Medium |
| RunSmart | AI voice cue | gpt-4o-mini (60 tokens) + OpenAI **tts-1** | Vercel `v0/app/api/coach/voice-cue/route.ts:91,115` | tiny; TTS is most of the cost (code comment) | No | Low |
| RunSmart | Training plan | gpt-4o | Vercel `v0/app/api/generate-plan/route.ts:128` | large | Yes | Yes |

Neither iOS app calls a model from the device today. All keys stay server-side. Monthly OpenAI spend: **unknown**.

### 2.2 CI/CD
- **Resumely iOS:** no CI. Manual `xcodebuild archive` + `-exportArchive` upload from the Mac (`docs/qa/2026-11-05-testflight-37-phone-run.md:13`). Tests run locally (770 XCTest).
- **RunSmart iOS:** GitHub Actions `pr-checks.yml` runs build + unit tests on `macos-26` for non-draft PRs that touch iOS files. **Measured: 99 iOS jobs, 1,822 macOS minutes (30.4 h) in the last 30 days, about 18 min each.** Uploads use `fastlane beta` from the Mac (`fastlane/Fastfile:49`), internal testers only.
- GitHub plan and bill: **unknown** (the API needs a scope I don't have). At the article's $0.062/min, 1,822 min would be about $113/month before any free allowance. Unverified.

### 2.3 Data
- RunSmart: `runs`, `workouts`, `plans`, `profiles`, `conversations`, Garmin tables, routes, `run_debriefs` in Supabase. Web and Coach Mode read them. Stays in Supabase.
- Resumely: resumes, optimizations, credits, applications all go through the web API. Stays in Supabase.
- Purely personal, iOS-only data that could live in CloudKit: very little. Run cue settings are already in `UserDefaults`.

### 2.4 Weather, maps, location (RunSmart)
- No weather API anywhere (iOS or web). Cost $0.
- iOS maps: native MapKit (`LiveRunMapPage.swift`, `RouteCreatorView.swift`). Free.
- Web maps: raw `tile.openstreetmap.org` tiles. Free, but OSM's tile policy discourages heavy app use. MapKit JS is an option later.

### 2.5 TestFlight
- Resumely: internal "Founder QA" group, build 40 (1.6.1) on 2026-11-12.
- RunSmart: internal only (`distribute_external: false`), for pilot coaches. 1.2.6 (46) is live on the App Store since 2026-11-20. Beta Club runs on App Store invite codes, not TestFlight.

### 2.6 Minimum iOS and Apple Intelligence reach
- Both apps: iOS 17.0. On-device model needs iOS 26, PCC needs iOS 27, so every call sits behind `if #available`.
- Share of users who can run it: **unknown, check in PostHog.** Paste-ready HogQL (upper bound: ignores language and whether Apple Intelligence is switched on; iPhone identifier 16 and up = iPhone 15 Pro and later):

```sql
SELECT
  count() AS ios_users,
  round(100 * countIf(model_major >= 16 AND os_major >= 26) / count(), 1) AS pct_on_device_ready,
  round(100 * countIf(model_major >= 16 AND os_major >= 27) / count(), 1) AS pct_pcc_ready
FROM (
  SELECT person_id,
    toInt64OrZero(splitByChar(',', replaceOne(argMax(properties.$device_model, timestamp), 'iPhone', ''))[1]) AS model_major,
    toInt64OrZero(splitByChar('.', argMax(properties.$os_version, timestamp))[1]) AS os_major
  FROM events
  WHERE timestamp > now() - INTERVAL 30 DAY AND properties.$os = 'iOS'
  GROUP BY person_id
)
```

---

## 3. Fit map

| Item | Use today? | RunSmart candidate | Resumely candidate | Replaces | Real saving | Risks / limits | Verdict |
|---|---|---|---|---|---|---|---|
| On-device Foundation Models | No | Post-run debrief (tiny prompt, already has fallback and `source` field); voice cue text | Dropped (users are Hebrew) | gpt-4.1-mini / gpt-4o-mini calls | Cents per month at current volume | iOS 26+, Apple Intelligence devices, no Hebrew, quality unknown | **Small opt-in experiment: RunSmart debrief** |
| PCC (Apple server model) | No | Coach chat replies, run report | Dropped (users are Hebrew) | gpt-4o-mini calls | Small; gpt-4o-mini is already cheap | iOS 27+, entitlement needed, per-user quota, no web, future fees, no Hebrew | **Later**: apply now, build after the debrief result |
| Xcode Cloud | No | Archive on `main` → TestFlight (replaces local `fastlane beta`) | Archive on `main` → TestFlight + tests on PR (Resumely has no CI) | GitHub macOS minutes, Mac time | Only if GitHub bills the macOS minutes; RunSmart PR tests alone (30 h) exceed 25 h | 25 h shared by both apps; secrets setup | **Adopt now for archives; keep RunSmart PR tests on GitHub** |
| WeatherKit | No | Weather on run summary, heat note before a run | None | Nothing (new feature) | $0 | Attribution rules; must not promise health outcomes | **Later** (feature, not saving) |
| CloudKit | No | None | None | Nothing | $0 | Web and coach need Supabase data | **Skip**: all data is shared with web or server |
| Managed Background Assets | No | Audio packs for cues | Template assets | Nothing | $0 | Extra build work | **Skip** for now |
| TestFlight | Yes, internal only | Pilot coaches only (Beta Club is App Store users) | Internal QA | Nothing | $0 | First external build needs Beta App Review | **Keep as is** |
| MapKit JS | No | Replace raw OSM tiles on web | None | OSM tiles | $0 | Quota unverified | **Later** |
| Push, Sign in with Apple, App Attest | Not audited | | | | Not savings | | n/a |

---

## 4. Verdict per item
1. **On-device Foundation Models: small opt-in experiment** in RunSmart for the debrief, English users on eligible devices only. Dropped for Resumely.
2. **PCC: later, RunSmart only.** Request the entitlement now (free), build only after the debrief result. Never the only path.
3. **Xcode Cloud: adopt now for archives** (both apps, about 3-7 h/month). Keep RunSmart PR tests on GitHub until you see the GitHub bill.
4. **TestFlight: keep as is.** Beta Club runs on App Store invite codes; TestFlight stays for pilot coaches.
5. **WeatherKit: later,** as a product feature.
6. **MapKit JS: later,** if OSM tile use grows on RunSmart web.
7. **CloudKit: skip.** Everything is shared with web or the coach.
8. **Background Assets: skip.**

---

## 5. First experiment: RunSmart debrief on device

### Architecture
- Integration point: `fetchRunDebrief(for:)` at `IOS RunSmart app/Services/Supabase/SupabaseRunSmartServices.swift:1334`. Keep `persistDebrief` (`:1631`) so the result still lands in `run_debriefs` and web sees it.
- Order: injury check → on-device (if flag on and model ready) → cloud `coach_message` → deterministic fallback.
- **Safety:** the edge function short-circuits on `injurySignal` with a fixed rest message (`index.ts:53`). Correction 2026-11-21: iOS never sends `injurySignal` for the debrief (`RunDebriefRequestDTO` has no such field), so that branch never fires from iOS today. The on-device path gets the same inputs as the cloud path; if an injury input is added later, check it before any generator runs.
- New file `IOS RunSmart app/Services/Coach/OnDeviceDebriefGenerator.swift`:

```swift
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct OnDeviceDebrief {
    @Guide(description: "Short headline about the run, at most 40 characters")
    var headline: String
    @Guide(description: "Two or three plain sentences about how the run went, using only the given data, at most 300 characters")
    var debrief: String
    @Guide(description: "One sentence on what to do tomorrow, at most 160 characters")
    var tomorrow: String
}

@available(iOS 26.0, *)
struct OnDeviceDebriefGenerator {
    static var isReady: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale()
    }

    func generate(instructions: String, runSummary: String) async throws -> OnDeviceDebrief {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: runSummary, generating: OnDeviceDebrief.self)
        return response.content
    }
}
#endif
```

- Opt-in: off by default for everyone. A user turns it on (English locale, model ready) or the founder turns it on for a test account. Hebrew users never see it.
- New `source` value `on_device`. Check first that `run_debriefs.source` and the web reader accept it.

### Prompt inside the budget
- Instructions: reuse `RUN_DEBRIEF_SYSTEM_PROMPT` (988 chars, about 250 tokens) plus the coaching-tone line. Keep under 400 tokens.
- Run data: compact text, not raw JSON. Distance, moving time, average pace, splits (max 10), planned workout type, last 3 runs one line each. No GPS points. Keep under 600 tokens.
- Output: about 200 tokens via `@Generable`. Total under 1.2K, well inside any on-device window. Log `contextSize` once per device to learn the real number.
- Wording: no health or performance promises; same rule as the cloud prompt.

### Quality comparison (about 10 real runs)
- A debug-only compare mode runs both paths on the same run and logs both texts side by side (founder device).
- Founder rates each pair blind, 1-5, on: matches the data, tone fits RunSmart, safe wording, useful "tomorrow" line.
- Pass: on-device is not worse on "matches the data" and "safe wording", and within 0.5 on average overall.

### Latency and battery
- Latency: time from call to result, both paths. Cloud has a 12 s timeout today.
- Battery: one generation after the run, not during it. Measure with Xcode's energy gauge on 3 runs. Unknown until measured.

### PostHog
Event `run_debrief_generated` with `source` (on_device / cloud / fallback), `latency_ms`, `on_device_ready`, `unavailable_reason`, `locale`, `context_size`, `error_type`. Follow the pattern in `IOS RunSmart app/Services/Analytics/AnalyticsEvents.swift`.

---

## 6. PCC application path
**Eligibility checklist**
- [x] Enrolled in App Store Small Business Program: requested 2026-10-21, accepted 2026-11-13 (Apple email: commission now 15%).
- [ ] Under 2M first-time downloads (check App Store Connect analytics). Open question to confirm with Apple: whether the 2M limit counts all apps together or each app on its own. Apple's wording ("any of their apps", "any app") doesn't settle it.
- [ ] Entitlement request sent: https://developer.apple.com/contact/request/private-cloud-compute/
- [ ] Apps gate PCC calls on iOS 27 and Apple Intelligence availability.

**What to prepare:** one paragraph per app on the use case (RunSmart: coach chat replies; Resumely: English bullet rewrites and tips), expected daily requests (from PostHog), the fallback design, and a privacy-policy line saying some requests go to Apple Private Cloud Compute.

**If not accepted:** nothing breaks. Keep OpenAI for server work, keep on-device for small tasks, reapply when eligible. **If accepted:** still keep the cloud path, because of the per-user quota, the 6-month migration rule and Apple's note about future fees.

---

## 7. Xcode Cloud plan
Workflows:
1. **Resumely "Archive main"**: on push to `main`, archive Release, upload to TestFlight internal group. `ci_scripts/ci_post_clone.sh` writes `Secrets.xcconfig` from Xcode Cloud environment secrets (template: `Secrets.xcconfig.template`).
2. **RunSmart "Archive main"**: same. No secrets step needed: `RunSmartConfig.xcconfig` already commits the public client keys. `ci_scripts/ci_post_xcodebuild.sh` runs `scripts/verify-release-backend.py` on the archive, like the Fastfile does. Keep `fastlane beta` as a fallback.
3. **Resumely "Test on PR"** (optional): unit tests only, ready-for-review PRs only.

Setup Nadav does in App Store Connect / Xcode (only after OK, nothing done yet):
1. Xcode → Integrate → Create Workflow (or App Store Connect → app → Xcode Cloud). Grant access to the GitHub repo.
2. Start condition: branch changes on `main`. Action: Archive, iOS, scheme `ResumeBuilder IOS APP` / `IOS RunSmart app`, distribution TestFlight (internal only). Post-action: TestFlight Internal Testing, group "Founder QA" (Resumely) or the internal group (RunSmart).
3. Resumely only: Environment → add `POSTHOG_API_KEY`, `SUPABASE_ANON_KEY`, `INTERNAL_TESTER_EMAILS`, `INTERNAL_TESTER_USER_IDS`, each marked Secret (values from your local `Secrets.xcconfig`). `SUPABASE_ANON_KEY` must be the `sb_publishable_` key, never the legacy anon JWT: the script fails the build otherwise.
4. Build numbers: Xcode Cloud numbers its own builds from 1. For iOS, App Store Connect only needs version + build to be unique, so this works for the next version. To keep the numbers you know, set Next Build Number to 41 (Resumely) and 47 (RunSmart) under Xcode Cloud → Settings → Build Number ([Apple doc](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds)).
5. Run the workflow once by hand. Pass = all three:
   - the build reaches TestFlight internal and the app opens on the iPhone;
   - Resumely: the Xcode Cloud log shows "Wrote Secrets.xcconfig with 4 keys" (the script stops the build on a missing, `$`-containing or non-publishable key);
   - Resumely: the archived app really carries the publishable key. Download the archive's app from the Xcode Cloud build artifacts and run, without printing the key:
     `/usr/libexec/PlistBuddy -c "Print :SUPABASE_ANON_KEY" "<App>.app/Info.plist" | grep -q '^sb_publishable_' && echo publishable || echo WRONG`

Hours estimate (guess until measured; archive time 10-15 min per the article):
| Workflow | Runs/month (guess) | Min/run | Hours |
|---|---|---|---|
| Resumely archive | 6 | 15 | 1.5 |
| RunSmart archive | 6 | 15 | 1.5 |
| Resumely tests on PR | 20 | 10 (unmeasured) | 3.3 |
| **Total** | | | **about 6.3 of 25** |
| RunSmart PR tests (if moved) | 99 | 18 (measured on GitHub) | +30, does not fit |

---

## 8. Draft PRs (not opened)
| # | Repo | Scope | Files | Risk | Test |
|---|---|---|---|---|---|
| 1 | RunSmart iOS | Wrap the cloud debrief behind a `RunDebriefGenerating` protocol. No behavior change | new `Services/Coach/RunDebriefGenerating.swift`, `SupabaseRunSmartServices.swift:1334-1400` | Low (Tier 1) | Unit test: fake generator, cloud then fallback order |
| 2 | RunSmart iOS | On-device generator behind the flag, injury short-circuit, locale + availability check | new `Services/Coach/OnDeviceDebriefGenerator.swift`, flag file | Medium (Tier 1) | Unit tests: injury never reaches a generator; not-ready skips to cloud; device test on iPhone 17 |
| 3 | RunSmart iOS | PostHog event + debug-only side-by-side compare mode | `Services/Analytics/AnalyticsEvents.swift`, debrief view | Low (Tier 1) | Event payload unit test |
| 4 | Resumely iOS | Xcode Cloud archive workflow + `ci_scripts/ci_post_clone.sh` | `ci_scripts/`, App Store Connect setup | Medium (Tier 2: secrets) | One manual run reaches TestFlight; app launches |
| 5 | RunSmart iOS | Xcode Cloud archive workflow + backend check | `ci_scripts/` | Medium (Tier 2: release pipeline) | Same as 4 |
| 6 | RunSmart iOS | Spike: WeatherKit on the run summary | new service + capability | Low | Later |

---

## 9. Cost table (real savings only)
| Item | Today | After | Real saving |
|---|---|---|---|
| Apple Developer Program | $99/year | $99/year | 0 |
| RunSmart CI (GitHub macOS) | 1,822 min/month measured; $ unknown | Same (PR tests stay) | 0 now |
| Archives / TestFlight uploads | Mac time, $0 | Xcode Cloud, $0 | 0 $; saves founder time |
| OpenAI: RunSmart debrief | gpt-4.1-mini, ~1K tokens per run; $ unknown | On-device for eligible users | Cents per month (guess) |
| OpenAI: everything else | $ unknown | Same | 0 |
| Supabase | Free tier | Free tier | 0 |
| Weather / maps | $0 | $0 | 0 |

Honest total: close to $0/month now. The article's $4,900/year applies only to things you would otherwise pay for.

---

## 10. Open questions for Nadav
1. Are you enrolled in the App Store Small Business Program? **Answered 2026-11-25: yes, accepted 2026-11-13 (requested 2026-10-21), commission 15%.**
2. What is your monthly OpenAI spend, split by app if possible?
3. What is your GitHub plan, and are macOS minutes billed? (github.com → Settings → Billing)
4. What share of iOS users can run Apple Intelligence? Run the HogQL in 2.6 on both PostHog projects.
5. What share of Resumely users use the app in Hebrew? They can never use the Apple models. **Answered 2026-11-21, see Decisions at the top.**
6. Is Beta Club meant to be TestFlight testers or App Store users with a free plan? **Answered 2026-11-21, see Decisions at the top.**
7. OK to request the PCC entitlement now (free, no code)? **Answered 2026-11-21, see Decisions at the top.**
