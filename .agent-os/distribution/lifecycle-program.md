# ResumeBuilder — Lifecycle Program

Use `distribution-os/workflows/08-lifecycle-email.md` to design new stages.

## Stages In Order

1. Welcome (account created)
2. Welcome 2 (didn't start a resume in 24h)
3. Activation hit (first export)
4. Activation missed (started but didn't export)
5. 7-day digest with job-tailoring tip
6. 14-day reactivation
7. Monthly job-seeker tip (low frequency, opt-in)
8. Pre-paid offer / credit-system reminder
9. Cancellation save

## Channels Per Stage

- Email: always
- In-app banner: stages 2, 4
- No push notifications (web-first product)

## Status Per Stage (Audited 2026-05-27)

- Welcome (account created): not started — no email platform wired
- Welcome 2 (didn't start in 24h): not started
- Activation hit (first export): not started
- Activation missed (started, didn't export): not started
- 7-day digest: not started
- 14-day reactivation: not started
- Monthly job-seeker tip: not started
- Pre-paid offer / credit reminder: not started — IAP not yet live
- Cancellation save: not started — subscriptions not applicable yet (credit model, one-time IAP)

Push notifications: PushService.swift exists and requests UNUserNotificationCenter authorization.
No external messaging platform (Klaviyo, Braze, OneSignal, FCM) is wired.
Email is not wired at the iOS layer — any email lifecycle would come from web backend post-signup.

Note: The lifecycle from the web GTM (5-email sequence) targets web signups. A parallel iOS post-install sequence is needed but not started.

## Measurement

- Open rate, click rate, downstream action per stage
- Effect on `resumebuilder.activation.first_resume_exported`, `resumebuilder.retention.returned_within_14_days`, `resumebuilder.revenue.paid_conversion_rate`
