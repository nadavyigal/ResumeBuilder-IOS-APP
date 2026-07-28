# Release A 1.4.2 (12) Production Measurement Readiness — 2026-07-16

## Decision

**Measurement-ready: No.** Exact-version traffic is reaching PostHog, but no clean post-App-Store-release person is present. There is therefore no mature clean D7 cohort and no trustworthy first-launch-to-export journey yet.

This is an event-presence and measurement-readiness audit, not an activation readout. It does **not** show that Release A improved or harmed activation.

## Scope and source

- Product: Resumely iOS, Release A `marketing_version = 1.4.2`, `build_number = 12`.
- PostHog project: `270848`, **ResumeBuilder AI**, timezone UTC.
- Operational dashboard: [Resumely — Activation + Export Diagnostic](https://us.posthog.com/project/270848/dashboard/1801425).
- Public App Store release anchor: `2026-07-15T18:06:44Z`, from Apple's public [Lookup API](https://itunes.apple.com/lookup?bundleId=Resumebuilder-IOS.ResumeBuilder-IOS-APP&country=us), which returned version `1.4.2` for the app's checked-in bundle ID.
- Exact production cohort query window: `2026-07-15T18:06:44Z` through `2026-07-16T05:14:36.644024Z`, inclusive.
- Wider exact-version event-presence window, including pre-release/internal traffic: `2026-07-15T00:00:00Z` through the same query end.
- First matching exact-version event: `2026-07-15T08:19:08.777000Z`.
- Last matching exact-version event: `2026-07-15T18:15:04.038000Z`.
- Release A code definitions cited below are from pushed branch `origin/codex/first-time-journey-release-a` at `6532c645998ee6edf7f7cfbcee0be543508b0b22`.

Repository provenance caveat: that pushed commit still resolves to `1.4.1 (11)` in the project file. The submitted archive was produced after a local version/build change that is not present in the pushed commit. PostHog independently confirms events carrying `1.4.2` and `12`, but the repository cannot reconstruct the exact archive metadata from a committed tree.

## Metric contract

The release decision metric is **founder-excluded first launch → `export_success` within D7**:

- Denominator: unique clean people whose first `app_launched` event for app `resumely_ios`, marketing version `1.4.2`, and build `12` falls inside the acquisition window.
- Numerator: denominator people with an `export_success` strictly after that first launch and no later than `first_launch + 7 days`.
- Unit: unique PostHog person after alias/person merging, not event rows.
- Maturity: a denominator user is eligible for a D7 decision only after their full seven-day conversion window has elapsed.

### Exact exclusions

A person is excluded from every step if any exact-version/build row or current person record matches any of:

- event `is_internal_tester = true`, robust to Boolean/string representation;
- person `is_internal_tester = true` or `qa_account = true`;
- the dashboard-defined founder address or its founder/QA alias patterns;
- a QA email pattern containing `+qa` or `-qa-`;
- PostHog virtual traffic classified as bot, automation, or AI agent;
- a person ID beginning `067544b5`, `761e5b1b`, `a6441489`, or `712cf425`.

The four prefixes remain necessary for historical founder/QA/bot coverage. The explicit internal-tester and person-property rules are also necessary because the operational iOS SQL card currently excludes only those prefixes.

PostHog's event schema advertised virtual bot/traffic properties, but no exact-version row contained them and the SQL runner emitted a global-taxonomy warning for those names. The virtual-bot rule is retained defensively; verified historical bot/automation removal in this window therefore rests on the known-prefix contract.

## Exact-version arrival and exclusion audit

Traffic tagged `1.4.2 (12)` **is reaching PostHog**. Clean public-production traffic is **not yet confirmed**: the only person passing the exclusion contract occurred before the public release timestamp.

| Measure | Result |
|---|---:|
| Exact-version event rows | 82 |
| Raw people | 5 |
| Raw distinct IDs | 5 |
| People flagged internal tester | 4 |
| People matching a known prefix | 2 |
| People matching founder-address rules | 1 |
| People matching QA person property | 0 |
| People classified virtual bot/automation | 0 |
| Total excluded people, after overlap | 4 |
| Clean people | 1 |
| Clean event rows | 3 |

The wider table above includes pre-release traffic. Restricting to the public production window changes the result to:

| Post-release measure | Result |
|---|---:|
| Raw people | 1 |
| Raw event rows | 5 |
| Excluded people | 1 |
| Excluded event rows | 5 |
| Clean production people | 0 |
| Clean production event rows | 0 |

The five post-release rows were one excluded person's `app_launched`, `resume_upload_cta_seen`, `optimized_viewed`, `saved_resume_prompt_viewed`, and `export_cta_seen` events.

Tagging coverage is complete for the exact-version stream:

| Property check | Result |
|---|---:|
| Rows with `is_internal_tester` | 82 / 82 |
| `is_internal_tester = true` rows | 74 |
| `is_internal_tester = false` rows | 8 |
| `$lib = resumely-ios-urlsession` | 82 / 82 |
| `app = resumely_ios` | 82 / 82 |

The one wider-window clean person produced only `app_launched`, `guest_mode_started`, and `resume_upload_cta_seen`, all before public release. No clean post-release person produced any event in this audit window.

## Current numerator and denominator

| Read | Denominator | Numerator | Conversion |
|---|---:|---:|---:|
| Accrued clean post-release first launches, not maturity-gated | 0 | 0 | Undefined |
| Mature D7 cohort at query time | 0 | 0 | Undefined |

The first possible release-level D7 boundary is `2026-07-22T18:06:44Z`, seven days after public release. Because no eligible clean post-release launch exists yet, the first actual user-level maturity date is unknown; it will be seven days after the first eligible launch. A numerator of 0 against a mature denominator of 0 is **not** 0% activation.

## Release A journey event audit

Every expected step below is tied to its current Release A definition and capture point. Raw counts cover the wider exact-version window and therefore include pre-release and excluded activity. Clean counts cover the post-public-release production window and apply the person-level exclusion contract above.

| Journey stage | Canonical event | Current code definition / capture | Raw people (rows) | Clean people (rows) | Status |
|---|---|---|---:|---:|---|
| First seen / launch | `app_launched` | `Core/Analytics/AnalyticsService.swift:66,115`; captured after bootstrap in `ResumeBuilder_IOS_APPApp.swift:18` | 3 (5) | 0 (0) | Present raw; no clean production denominator |
| Resume selected | `resume_file_selected` | `AnalyticsService.swift:103,150`; captured after picker result in `Features/Tailor/TailorViewModel.swift:76` | 0 (0) | 0 (0) | Missing exact-version evidence |
| Server upload completed | `resume_upload_succeeded` | `AnalyticsService.swift:107,154`; captured after successful upload in `TailorViewModel.swift:143` | 0 (0) | 0 (0) | Missing exact-version evidence |
| Legacy upload marker | `resume_uploaded` | `AnalyticsService.swift:68,117`; captured both from Home selection (`Features/V2/Home/HomeTabView.swift:204`) and after upload (`TailorViewModel.swift:150`) | 0 (0) | 0 (0) | Do not use as the 1.4.2 server-upload step |
| Job input accepted | `job_added` | `AnalyticsService.swift:69,118`; Home first requires `JobInputPolicy.Evaluation.isReady` at `HomeTabView.swift:288-298`, then captures at `HomeTabView.swift:311-318` | 0 (0) | 0 (0) | Missing exact-version evidence |
| Optimization started | `optimization_started` | `AnalyticsService.swift:73,122`; captured immediately before optimize in `TailorViewModel.swift:198` | 2 (6) | 0 (0) | Present only in excluded traffic |
| Diagnosis consumed | `diagnosis_viewed` | `AnalyticsService.swift:84,133`; captured from `Features/V2/Diagnosis/ResumeDiagnosisView.swift:38-40` | 0 (0) | 0 (0) | Missing exact-version evidence |
| Optimization completed | `optimization_completed` | `AnalyticsService.swift:74,123`; direct completion at `TailorViewModel.swift:221`, review apply/recovery at `Features/V2/History/OptimizationReviewView.swift:195,226` | 2 (5) | 0 (0) | Present only in excluded traffic; duplicated correlations |
| Optimized surface opened | `optimized_viewed` | `AnalyticsService.swift:76,125`; captured when the Optimized surface becomes active at `Features/V2/Improve/OptimizedResumeView.swift:1174-1177` | 2 (4) | 0 (0) | Present only in excluded traffic; not proof of visible output |
| Optimized preview visibly rendered | `optimized_preview_rendered` | `AnalyticsService.swift:77,126`; requires non-empty rendered HTML plus visible applied changes at `OptimizedResumeView.swift:162-167` | 0 (0) | 0 (0) | Missing from all exact-version traffic |
| Save prompt visible | `saved_resume_prompt_viewed` | `AnalyticsService.swift:78,127`; captured at `OptimizedResumeView.swift:778-781` | 2 (4) | 0 (0) | Present only in excluded traffic |
| Save terminal | `save_success` / `save_failed` | `AnalyticsService.swift:79-80,128-129`; captured at `ViewModels/OptimizedResumeViewModel.swift:133,136` | 2 (4) / 2 (2) | 0 / 0 | Present only in excluded traffic |
| Export started | `export_started` | `AnalyticsService.swift:81,130`; captured before export in `Core/Export/ResumeExportAction.swift:19` and preview toolbar at `Features/V2/Preview/ResumePreviewWebView.swift:226` | 0 (0) | 0 (0) | Missing exact-version evidence |
| Export terminal | `export_success` / `export_failed` | `AnalyticsService.swift:82-83,131-132`; captured at `ResumeExportAction.swift:39,44` and `ResumePreviewWebView.swift:236,249,253` | 0 / 0 | 0 / 0 | Missing exact-version evidence |

### Missing and duplicated events affecting trust

1. **Visible preview is not yet measurable in production.** `optimized_preview_rendered` has zero rows in the entire exact-version stream, while `optimized_viewed` is present for two excluded people and save activity is present for two excluded people. These aggregates do not prove the same people traversed both stages, and event absence alone does not prove the UI failed, but the required consumed-value step cannot currently be validated.
2. **`optimization_completed` is duplicated by correlation.** Five rows collapse to three unique person + `optimization_id` pairs; two pairs each have one repeated completion row. A people-based funnel is protected from row inflation, but event-count reporting is not. The D7 query must deduplicate, and the later instrumentation story should determine why the same correlation completes more than once.
3. **`resume_uploaded` has two meanings in current code.** Home emits it when a filename becomes selected, and Tailor emits it again after upload. A trustworthy new funnel must use `resume_file_selected` for local selection and `resume_upload_succeeded` for server completion. The operational dashboard retains `resume_uploaded` only as its historical denominator.
4. **No clean post-release evidence exists at any funnel stage.** The single post-release person was excluded, so even the production entry denominator is empty.

No duplicate PostHog event UUIDs were found in the exact-version stream. The completion issue above consists of separate event UUIDs sharing the same semantic person/optimization correlation.

## Guest-to-auth identity continuity

Guest-to-auth identity continuity **can be measured without reading, interpreting, or changing Story 7 code**.

Release A already:

- persists a stable `anonymous_session_id` in `Core/Analytics/AnalyticsService.swift:258,412,423-437`;
- emits `$create_alias` from the previous guest ID to the authenticated user and then identifies the user in `AnalyticsService.swift:305-325`;
- retains `anonymous_session_id`, app, version, build, and internal-tester metadata in the alias payload through `AnalyticsService.swift:373-386,403-414`.

Historical production confirms the alias mechanism has been observed: one alias on 1.3 (8), two on 1.4 (10), and three on 1.4.1 (11), each with one distinct anonymous session per alias. The exact 1.4.2 window has zero `$create_alias`, `$identify`, `sign_in_completed`, or `signup_completed` rows, so Release A identity continuity is measurable in principle but not yet evidenced for build 12.

This identity contract can show whether pre-auth and post-auth events merge to one person. It cannot establish that résumé selection, job input, or diagnosis state survived authentication; that behavioral continuity is Story 7 product scope and remains untouched here.

## PII and property inspection

### Live exact-version events

All 82 exact-version events were inspected by enumerating top-level and nested `$set` property **keys only**, then aggregating custom value lengths and email/URL signatures without returning raw values.

Observed custom properties were limited to:

- fixed metadata and flags: app/version/build/platform, anonymous session, internal/auth status;
- opaque correlation IDs: resume, job-description, review, and optimization IDs;
- fixed categories/booleans: source, verdict, match score, error code, cover-letter presence.

Results:

- email-like custom values: 0;
- URL-like custom values: 0;
- custom values 200 characters or longer: 0;
- keys for résumé text, job text, job description content, email, URL, generated output, or generated content: 0;
- nested `$set` keys: operating-system and PostHog GeoIP enrichment only.

PostHog also adds `$ip` and GeoIP fields at ingestion. Those are platform enrichment, not résumé text, job text, email, URL, or generated content.

### Source contract

Event payloads in `AnalyticsService.swift:157-217` contain only fixed categories, booleans, scores, error categories, file type/size bucket, and opaque IDs. The transport merges stable base properties at `AnalyticsService.swift:333-343,403-414`. The existing debug assertion rejects exact forbidden keys at `AnalyticsService.swift:484-486`.

The live inspection is the stronger evidence for this release because the source deny-list is exact-key based and is not, by itself, a complete general content detector.

## Operational dashboard versus mature ordered D7

The operational dashboard was force-refreshed read-only during this audit. Its cards are useful for broad health and historical diagnostics, not for the 1.4.2 decision metric.

The trailing-60-day iOS card reported:

| Presence metric | People |
|---|---:|
| Launched app | 84 |
| Upload CTA tapped | 17 |
| File picker opened | 16 |
| File selected | 7 |
| Resume uploaded | 13 |
| Job added | 9 |
| Optimization completed | 7 |
| Export success | 1 |

These are unordered per-person event-presence totals. The card:

- uses a trailing 60-day window rather than a closed 1.4.2 acquisition cohort;
- has no marketing-version or build filter;
- uses `resume_uploaded`, whose current semantics are ambiguous;
- excludes the four known prefixes but does not apply the new event-level `is_internal_tester` contract;
- does not require export within seven days of first launch.

Therefore `1 / 84` is **not** the Release A activation rate and must not be compared with the mature D7 result.

The dashboard's separate 60-day export diagnostic reported 11 people with optimization completion and 2 with export success. It is also unordered, version-agnostic, and uses a different library/filter contract, so it is operational context only.

## Cohort reset: 1.4.1 → 1.4.2

1. **Event-presence check now — complete.** Exact 1.4.2 (12) events are arriving, tagging is complete, exclusions work, and live payload inspection found no prohibited content. No clean post-release entrant exists yet.
2. **Earliest useful directional reread — 2026-07-22.** Re-read after `2026-07-22T18:06:44Z`, the first release-level D7 boundary. If no clean entrant arrived near release, this remains an event-presence checkpoint; a user-level D7 read becomes valid only seven days after the first eligible clean launch.
3. **Mature D7 decision read — only after cohort closure + seven days.** If the acquisition cohort is closed at the end of 2026-07-22 UTC, the first fully mature cohort decision read is after the end of 2026-07-29 UTC. If enrollment remains open, move the decision date so every included entrant has seven complete days.
4. **No lift claim.** Event presence, a non-empty stream, internal QA completions, and operational dashboard totals do not establish an activation improvement.

## Reproducible query definition

The final D7 query should aggregate one row per person, compute the first exact-version `app_launched`, compute the first later `export_success`, exclude the person globally if any exclusion rule matches, then count only launchers whose seven-day window has matured.

```sql
WITH per_person AS (
  SELECT
    person_id,
    minIf(timestamp, event = 'app_launched') AS first_launch_utc,
    minIf(timestamp, event = 'export_success') AS first_export_utc,
    max(coalesce(lower(toString(properties.is_internal_tester)) = 'true', false)) AS internal_flag,
    max(coalesce(lower(toString(properties['$virt_is_bot'])) = 'true'
      OR lower(toString(properties['$virt_traffic_type'])) IN ('bot', 'automation', 'ai agent'), false)) AS virtual_bot_flag,
    max(coalesce(lower(toString(person.properties.qa_account)) = 'true'
      OR lower(toString(person.properties.is_internal_tester)) = 'true', false)) AS qa_property_flag,
    max(coalesce(
      lower(toString(person.properties.email)) = '<dashboard founder address>'
      OR match(lower(toString(person.properties.email)), '.*[+]qa.*@.*')
      OR match(lower(toString(person.properties.email)), '.*-qa-.*@.*')
      OR match(lower(toString(person.properties.email)), '<dashboard founder alias pattern>'), false)) AS founder_qa_email_flag,
    startsWith(toString(person_id), '067544b5')
      OR startsWith(toString(person_id), '761e5b1b')
      OR startsWith(toString(person_id), 'a6441489')
      OR startsWith(toString(person_id), '712cf425') AS known_prefix_flag
  FROM events
  WHERE timestamp >= toDateTime('2026-07-15 18:06:44', 'UTC')
    AND timestamp <= toDateTime64('2026-07-16 05:14:36.644024', 6, 'UTC')
    AND properties.app = 'resumely_ios'
    AND toString(properties.marketing_version) = '1.4.2'
    AND toString(properties.build_number) = '12'
  GROUP BY person_id
), eligible AS (
  SELECT *,
    NOT (internal_flag OR virtual_bot_flag OR qa_property_flag
      OR founder_qa_email_flag OR known_prefix_flag) AS clean
  FROM per_person
  WHERE first_launch_utc > toDateTime(0)
)
SELECT
  countIf(clean AND first_launch_utc <= now() - INTERVAL 7 DAY) AS mature_d7_denominator,
  countIf(clean AND first_launch_utc <= now() - INTERVAL 7 DAY
    AND first_export_utc > first_launch_utc
    AND first_export_utc <= first_launch_utc + INTERVAL 7 DAY) AS mature_d7_numerator
FROM eligible
```

The literal founder address and alias pattern are intentionally omitted from this repository report. Use the values already saved in dashboard `1801425` when executing the private query.

## Final handoff

- **Measurement-ready:** No.
- **Missing evidence:** no clean post-release entrant or mature clean D7 denominator; no production path at any stage; no exact-version resume selection/upload, job acceptance, diagnosis, visible-preview, export-start, or export-terminal evidence; no build-12 guest-to-auth transition; and no committed source tree containing the submitted `1.4.2 (12)` metadata.
- **Earliest valid reread date:** 2026-07-22, after `18:06:44Z`, as a directional/event-presence checkpoint. The first mature eligible-user read remains seven days after the first clean post-release launch.
- **Later instrumentation story required:** Yes — Release B Story 10 remains required to make `optimized_preview_rendered` production-verifiable, separate selection from upload canonically in the documented funnel, and resolve/dedupe repeated `optimization_completed` correlations. Story 7 was not inspected or changed, and Stories 8–10 were not begun.
