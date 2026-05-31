# ResumeBuilder iOS — Assets Needed

| Asset | Channel | Status | Priority | Notes |
|---|---|---|---|---|
| App Store listing audit + rewrite (English) | ASO | needed | high | Primary acquisition surface |
| App Store screenshots (English, all device sizes) | ASO | needed | high | First screenshot is the hero — make it count |
| App preview video (English) | ASO | needed | medium | Big ASO conversion lift if done well |
| App Store listing (Hebrew authored) | ASO | needed | medium | Subtitle, keywords, description, screenshots |
| `ats-resume-builder` landing with App Store CTA | Web feeder | needed | high | Mobile-detect, App Store on iOS |
| `ai-resume-tailoring` landing with App Store CTA | Web feeder | needed | high | Same |
| Comparison page: `vs-teal` | Web feeder | needed | medium | App Store CTA |
| Comparison page: `vs-rezi` | Web feeder | needed | medium | App Store CTA |
| Free ATS scoring tool MVP (web) | Free tool | needed | high | Result page hands off to App Store |
| Free ATS tool lead-magnet PDF | Free tool | needed | medium | "Fix the top 10 ATS rejections" |
| Directory submission pack v1 (English + Hebrew) | Directories | needed | high | Include both web URL and App Store URL |
| Welcome email (post-install) | Email | needed | high | Trigger on app first-open + account |
| Didn't-start-in-24h email | Email | needed | high | Activation push |
| Activation hit (first export) email | Email | needed | medium | Celebrate + reinforce |
| 14-day return email | Email | needed | medium | Re-engagement |
| App onboarding conversion review | CRO | needed | high | Highest leverage surface for activation |
| Web → App Store landing conversion review | CRO | needed | high | Mobile install rate |
| Programmatic SEO template (role example) with App Store CTA | Programmatic SEO | needed | medium | Tier B — after ASO + landings prove |
| Hebrew authored landing (mobile-first) | Hebrew | needed | medium | Separate experience |
| Web → App Store `at=` + `ct=` attribution wiring (web repo) | Attribution | needed | high | Required to measure web feeder channels; not yet wired |
| **Free ATS tool result page: App Store CTA on iOS** (web repo) | Free tool | **CONFIRMED MISSING** | **blocker** | **Founder confirmed 2026-05-28: result page shows web signup CTA only on mobile. Must add App Store link with `ct=ats-tool-result` before the web feeder channel can contribute iOS installs.** |
| ~~App Store IAP pricing config~~ | ~~ASO / Monetization~~ | resolved | n/a | Free at launch — IAP deferred to pricing stage (confirmed 2026-05-28) |
| ~~App name decision~~ | ~~ASO~~ | resolved | n/a | **Resumely** confirmed 2026-05-28 — ASO copy now unblocked |
| ~~iapVerify cross-platform restore~~ | ~~Engineering~~ | resolved | n/a | N/A at free launch — revisit when pricing stage begins |
| PostHog iOS SDK init + core event instrumentation | Analytics | needed | high | No analytics wired on iOS; blind post-install |
| Push notification platform integration (Braze / OneSignal / direct APNS) | Lifecycle | needed | medium | PushService.swift scaffolded; needs backend + delivery service |
| Hebrew iOS app strings / RTL layout (in-app) | Hebrew | needed | low | Progress.md flags as risk; not needed for App Store submit but affects Hebrew market claim |
