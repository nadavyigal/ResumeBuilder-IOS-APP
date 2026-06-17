# Resumely Post-Live D7 Readout - 2026-06-17

## Status

Live source verified through the connected PostHog plugin. This is a post-live Day 0 / D7-pre-read, not a complete D7 outcome readout.

Use 2026-06-17 as the App Store-live anchor based on founder/user evidence unless App Store Connect later provides a more precise Ready-for-Sale timestamp. The first complete D7 window from that anchor ends on 2026-06-24.

## Evidence Used

- Connected PostHog plugin against project 270848 ("ResumeBuilder AI") on 2026-06-17.
- D7 Activation dashboard 1720819 read directly through the PostHog plugin.
- Live HogQL reads over `events` filtered by `properties.$lib = 'resumely-ios-urlsession'`.
- iOS repo `tasks/progress.md` after PR #65 was merged to `main`.
- Web Vercel production env check from the prior release-QA packet.

## Confirmed

| Area | Current evidence | Interpretation |
|---|---:|---|
| iOS analytics | 188 events / 18 users over trailing 7 days; first event 2026-06-10T12:37:44.611Z; last event 2026-06-17T03:06:44.021Z | iOS instrumentation is firing and healthy enough for launch monitoring. |
| Post-live anchor traffic | Since 2026-06-17T00:00:00Z: 2 `app_launched` events / 2 users; 2 `guest_mode_started` events / 2 users | Launch-day traffic is visible in PostHog. |
| Backend analytics | Prior verified packet: `$lib=posthog-node`, 123 events / 2 users over 7 days | Backend capture path is firing. |
| Web analytics | Prior verified packet: `$lib=web`, 24 events / 1 user over 7 days; Vercel production env has `NEXT_PUBLIC_POSTHOG_KEY` and `NEXT_PUBLIC_POSTHOG_HOST` | Web is firing but low-traffic, not misconfigured. |
| iOS north-star dashboard | Dashboard 1720819 resolves through the PostHog plugin, is pinned, and has tags `d7`, `ios`, `resumebuilder` | Keep as the iOS north-star dashboard. |

## Trailing 7-Day iOS Event Read

Filter: `properties.$lib = 'resumely-ios-urlsession'`

| Event | Events | Users | Last seen |
|---|---:|---:|---|
| `app_launched` | 57 | 14 | 2026-06-17T03:06:44.021Z |
| `resume_uploaded` | 19 | 8 | 2026-06-16T20:08:54.392Z |
| `job_added` | 16 | 7 | 2026-06-16T20:09:01.893Z |
| `optimization_started` | 13 | 3 | 2026-06-16T13:49:15.630Z |
| `export_success` | 11 | 3 | 2026-06-15T18:20:30.612Z |
| `optimization_completed` | 10 | 3 | 2026-06-16T13:50:10.629Z |
| `sign_in_completed` | 5 | 4 | 2026-06-15T14:43:22.090Z |
| `export_failed` | 2 | 1 | 2026-06-11T10:47:05.412Z |

## Daily iOS Activity

| Day | App launches | Active users | Total events |
|---|---:|---:|---:|
| 2026-06-10 | 2 | 2 | 9 |
| 2026-06-11 | 11 | 3 | 37 |
| 2026-06-12 | 12 | 4 | 27 |
| 2026-06-13 | 1 | 1 | 9 |
| 2026-06-14 | 7 | 8 | 23 |
| 2026-06-15 | 7 | 4 | 37 |
| 2026-06-16 | 15 | 8 | 42 |
| 2026-06-17 | 2 | 2 | 4 |

## D7 Dashboard Health

Dashboard 1720819 ("ResumeBuilder iOS - D7 Activation") contains 8 tiles:

- iOS Activation Funnel
- iOS Daily Active Users
- iOS Export Conversion
- iOS Diagnosis to Improve
- iOS Submit Package Saves
- iOS Free ATS Score Buckets
- iOS Auth Mix
- iOS Export Failures

The dashboard is configured as the correct north star. However, the live event taxonomy has not yet observed several newer PR #60 event names used by tiles: `free_ats_completed`, `diagnosis_viewed`, `ats_improve_tapped`, `export_pdf_tapped`, and `submit_package_saved`. Treat those tiles as waiting for real post-PR user paths, not broken instrumentation, until the app generates the corresponding flows in production.

## Not Ready / Unknown

| KPI | Status | Why |
|---|---|---|
| D7 activation rate | Not mature | The source is now accessible, but 2026-06-17 is the App Store-live anchor, so a complete D7 window is not available until 2026-06-24. |
| D7 retention | Not mature | Requires a completed launch cohort window. |
| Funnel drop-off by step | Partial | Step event counts are visible, but true ordered D7 activation should be read from dashboard 1720819 after the D7 window completes. |
| App Store downloads / conversion / revenue | Unknown | Requires App Store Connect, RevenueCat, or equivalent source; do not infer from PostHog events. |

## Dashboard Hygiene

| Dashboard | ID | Live metadata | Classification | Action |
|---|---:|---|---|---|
| ResumeBuilder iOS - D7 Activation | 1720819 | Pinned; created 2026-06-16; tags `d7`, `ios`, `resumebuilder`; plugin last accessed 2026-06-17 | North star | Keep and use for D7 readout. |
| Activation Funnel | 1345375 | Pinned; created 2026-03-09; never viewed/accessed in live metadata; Sprint RS-104 description | Archive candidate | Review after D7, archive only if it duplicates or conflicts with 1720819. |
| Week 1 Launch Metrics | 1285341 | Pinned; created 2026-02-17; last viewed 2026-02-24; last accessed 2026-03-09 | Legacy/web launch candidate | Review after D7; likely not the iOS north-star dashboard. |
| My App Dashboard | 932305 | Pinned; created 2025-12-22; last refresh 2026-02-18; last viewed/accessed 2026-03-10 | Stale archive candidate | Review after D7; no deletion in this packet. |

No dashboards were deleted or edited.

## Monetization Implication

Keep monetization/paywall decisions blocked. The launch gate is closed and analytics are source-verified, but the D7 activation gate is not mature until the first complete D7 window.

## Next Packet

Run "Post-Live D7 Readout - Complete D7 Window" on or after 2026-06-24:

- read dashboard 1720819 through the PostHog plugin;
- compare ordered activation funnel completion against trailing event counts;
- check whether PR #60 events have appeared in taxonomy;
- decide whether stale dashboards should be archived, with explicit founder approval before any dashboard mutation.
