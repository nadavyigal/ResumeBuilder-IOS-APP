# ResumeBuilder — Metrics

Update during the weekly cycle.

## Analytics Wiring Audit (2026-05-27)

| Metric | Tracking status | Source |
|---|---|---|
| App installs | unknown | App Store Connect (not yet exported) |
| Push notification opt-in | not tracked | PushService.swift requests auth; no backend logging found |
| First resume uploaded | not tracked | No PostHog or analytics init found in iOS source |
| ATS score viewed | not tracked | Same |
| First optimization run | not tracked | Same |
| First resume exported | not tracked | Same |
| Credits purchased (IAP) | not tracked | StoreKit parked; no purchase event logging |
| User returned in 14 days | not tracked | No session analytics |
| Email open / click | unknown | No email platform wired to iOS |

PostHog: **not initialized** — no `PHGPostHogConfiguration` or `posthog` import found in iOS source.
Attribution tags (`at=`, `ct=`): **not wired** — web CTAs do not pass campaign tokens to App Store links.

## Current Snapshot (week of YYYY-MM-DD)

| Metric | This week | Prior week | Delta | Note |
|---|---|---|---|---|
| `resumebuilder.acquisition.organic_search_impressions` | | | | |
| `resumebuilder.acquisition.organic_search_clicks` | | | | |
| `resumebuilder.acquisition.indexed_pages` | | | | |
| `resumebuilder.acquisition.signups` | | | | |
| `resumebuilder.acquisition.directory_referrals` | | | | |
| `resumebuilder.activation.first_resume_started` | | | | |
| `resumebuilder.activation.first_resume_exported` | | | | |
| `resumebuilder.activation.signup_to_export_median` | | | | |
| `resumebuilder.retention.returned_within_14_days` | | | | |
| `resumebuilder.revenue.paid_conversion_rate` | | | | |
| `resumebuilder.revenue.mrr` | | | | |

## Top SEO Queries

| Query | Clicks | Impressions | Position |
|---|---|---|---|
| | | | |

## Top Pages (organic)

| Page | Clicks | Impressions |
|---|---|---|
| | | |

## Anomalies This Week

- (none) / list
