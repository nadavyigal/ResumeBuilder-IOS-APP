# PostHog Gate A Baseline - 2026-06-18

Objective: verify that Resumely iOS Gate A analytics are reaching PostHog before the 2026-06-21 D7 deadline.

Project: PostHog project 270848 ("ResumeBuilder AI")
Dashboard: https://us.posthog.com/project/270848/dashboard/1720819
Filter: `properties['$lib'] = 'resumely-ios-urlsession'`
Checked: 2026-06-18 06:50 UTC

## Deadline-Day Evidence

Fresh iOS events observed since 2026-06-18 00:00:00 UTC:

| Event | Latest timestamp UTC |
| --- | --- |
| resume_uploaded | 2026-06-18T04:23:20.236000Z |
| optimization_started | 2026-06-18T04:23:19.432000Z |
| diagnosis_viewed | 2026-06-18T04:21:06.400000Z |
| optimization_completed | 2026-06-18T04:21:05.250000Z |
| job_added | 2026-06-18T04:19:30.955000Z |
| app_launched | 2026-06-18T04:17:53.843000Z |

## Seven-Day Gate A Counts

| Event | Events | Users | Latest timestamp UTC |
| --- | ---: | ---: | --- |
| resume_uploaded | 27 | 9 | 2026-06-18T04:23:20.236000Z |
| optimization_started | 16 | 3 | 2026-06-18T04:23:19.432000Z |
| diagnosis_viewed | 2 | 1 | 2026-06-18T04:21:06.400000Z |
| optimization_completed | 11 | 3 | 2026-06-18T04:21:05.250000Z |
| job_added | 19 | 7 | 2026-06-18T04:19:30.955000Z |
| app_launched | 62 | 15 | 2026-06-18T04:17:53.843000Z |
| guest_mode_started | 44 | 13 | 2026-06-17T23:14:19.439000Z |
| ats_improve_tapped | 2 | 1 | 2026-06-17T12:31:18.758000Z |

## Remaining Gaps

- `export_pdf_tapped`, `submit_package_saved`, and `free_ats_completed` were not present in the PostHog project taxonomy at query time.
- The local iPhone 17 simulator Debug build succeeded and the built app contained `POSTHOG_API_KEY` plus `POSTHOG_HOST`, but `simctl bootstatus` reached a terminal failure and `simctl install/launch` hung, so this run did not produce a new simulator-driven Live Events screenshot.
- App Store Connect upload for version 1.0 build 4 reached Apple, but Apple rejected the upload because bundle version `4` had already been uploaded. Review submission still needs App Store Connect UI/API confirmation.

## Queries

```sql
SELECT event, count() AS events, count(DISTINCT person_id) AS users, max(timestamp) AS last_seen
FROM events
WHERE timestamp >= now() - INTERVAL 7 DAY
  AND properties['$lib'] = 'resumely-ios-urlsession'
  AND event IN ('app_launched','guest_mode_started','resume_uploaded','job_added','optimization_started','optimization_completed','diagnosis_viewed','ats_improve_tapped','export_pdf_tapped','submit_package_saved','free_ats_completed')
GROUP BY event
ORDER BY last_seen DESC
LIMIT 50
```

```sql
SELECT event, timestamp, properties['$lib'] AS lib, properties['platform'] AS platform, properties['$os'] AS os
FROM events
WHERE timestamp >= '2026-06-18 00:00:00'
  AND properties['$lib'] = 'resumely-ios-urlsession'
  AND event IN ('app_launched','guest_mode_started','resume_uploaded','job_added','optimization_started','optimization_completed','diagnosis_viewed','ats_improve_tapped')
ORDER BY timestamp DESC
LIMIT 30
```
