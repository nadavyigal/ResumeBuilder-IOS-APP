# Resumely Post-Live D7 Readout - 2026-06-17

## Status

Partial / blocked. Launch analytics are confirmed healthy, but a true D7 activation readout is not ready today.

## Evidence Used

- Trusted COO Review + live PostHog QA packet from 2026-06-17 for PostHog project 270848.
- iOS repo `tasks/progress.md` after PR #65 was merged to `main`.
- Browser attempt to open D7 Activation dashboard 1720819 on 2026-06-17.

## Confirmed

| Area | Current evidence | Interpretation |
|---|---:|---|
| iOS analytics | `$lib=resumely-ios-urlsession`, 190 events / 18 users over 7 days, last event 2026-06-17 | iOS instrumentation is firing and healthy enough for launch monitoring. |
| Backend analytics | `$lib=posthog-node`, 123 events / 2 users over 7 days | Backend capture path is firing. |
| Web analytics | `$lib=web`, 24 events / 1 user over 7 days; Vercel production env has `NEXT_PUBLIC_POSTHOG_KEY` and `NEXT_PUBLIC_POSTHOG_HOST` | Web is firing but low-traffic, not misconfigured. |
| iOS north-star dashboard | D7 Activation dashboard 1720819 exists per packet and prior repo status | Keep as the iOS north-star dashboard. |

## Not Ready / Unknown

| KPI | Status | Why |
|---|---|---|
| D7 activation rate | Unknown | The dashboard requires PostHog authentication in this session, and the first complete D7 post-live window is not confirmed complete on 2026-06-17. |
| D7 retention | Unknown | Requires cohort data from PostHog dashboard or API. |
| Funnel drop-off by step | Unknown | Requires dashboard 1720819 or equivalent PostHog query access. |
| App Store downloads / conversion / revenue | Unknown | Requires App Store Connect, RevenueCat, or equivalent source; not inferred from PostHog events. |

## Source Access Result

Direct browser navigation to:

`https://us.posthog.com/project/270848/dashboard/1720819`

redirected to:

`https://us.posthog.com/login?next=/project/270848/dashboard/1720819`

No authenticated PostHog tab was available in the browser session, and no PostHog personal API token was present in the shell environment. Therefore no dashboard values were read directly in this packet.

## Timing Gate

Do not treat 2026-06-17 as a complete D7 readout. If live availability started on 2026-06-14, the earliest first D7 read is 2026-06-21. If the trusted "App Store live" evidence date is the start date, the earliest first D7 read is 2026-06-24. Use the actual Ready for Sale date from App Store Connect if available.

## Dashboard Hygiene

| Dashboard | ID | Classification | Action |
|---|---:|---|---|
| ResumeBuilder iOS - D7 Activation | 1720819 | North star | Keep and use for D7 readout. |
| Activation Funnel | 1345375 | Archive candidate | Review in PostHog after login; archive only if it duplicates or conflicts with 1720819. |
| Week 1 Launch Metrics | 1285341 | Web/legacy candidate | Review in PostHog after login; local web config indicates it is built around web ATS/sign-up events, not the iOS D7 funnel. |
| My App Dashboard | 932305 | Stale archive candidate | Review in PostHog after login; packet says last refreshed 2026-02-18. |

No dashboards were deleted or edited.

## Monetization Implication

Keep monetization/paywall decisions blocked. The launch gate is closed, but the D7 activation gate is not. The next decision should wait for dashboard 1720819 values from the first complete D7 window.

## Next Packet

Run "Post-Live D7 Readout - Source Read" on or after the first complete D7 window with one of:

- an authenticated PostHog browser session;
- a PostHog personal/project API token with read access to project 270848;
- exported dashboard values from dashboard 1720819.

