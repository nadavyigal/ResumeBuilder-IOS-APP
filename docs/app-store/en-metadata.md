# English (U.S.) App Store Listing — Resumely iOS

Source of truth for current English App Store copy direction after the 1.2 (7)
submission. App Store Connect edits are manual; do not add fastlane or any new
submission dependency without explicit approval.

## Positioning Rule

Lead with Fit/Match and the complete application package. Keep "ATS" only in
process-descriptive contexts such as ATS-friendly formatting or common parsing
checks. Do not claim an official ATS score, guaranteed passage, or guaranteed
interviews.

## Recommended Title / Name

The app currently appears in App Store Connect as "Resume AI - CV Builder".
Do not change the app name mid-review unless Apple rejects metadata or the
founder explicitly chooses a rename.

Future brand-led option:
```
Resumely: Resume Builder
```

## Subtitle Options (30 chars max)

Recommended for the Fit/Match wedge:
```
AI Resume Tailor & Job Match
```
(28 chars)

Tighter alternate:
```
Job Match Resume Tailor
```
(23 chars)

## Keywords (100 bytes max)

Use only if the title/subtitle do not already contain the same words:
```
cv builder,job application,cover letter,career,scanner,optimizer,interview,linkedin,job seeker
```
(94 chars)

## Promotional Text (170 chars max)

Current 1.2 recommendation:
```
Check your fit before you apply. Resumely shows what is missing, helps tailor your resume, and exports a complete application package from your iPhone.
```
(151 chars)

## Description Opening

Use this as the first visible block if editing the full description in a future
metadata pass:

```text
Check your fit before you apply. Upload your resume, add a job description or link, and Resumely shows what is missing before you spend time tailoring.

Review your Resumely Match Score, apply targeted edits, choose an ATS-friendly design, and export a polished resume, cover letter, and application package from your iPhone.
```

## Claims To Avoid

- "Pass ATS"
- "Beat the bots"
- "Official ATS score"
- "Guaranteed interview"
- "Get hired"
- Any named ATS-vendor compatibility claim without evidence

## Demand-Mining Update (2026-07-11) — DRAFT, pending founder approval

Sourced from `executive-os/research/2026-07-11-demand-mining-right-user-fit.md` (Agentic OS). Two findings, both additive to the existing Positioning Rule above, not a replacement:

1. **Anti-generic-AI angle.** Primary-sourced complaint (TeamBlind): resumes drafted by ChatGPT read as "really obvious it was written by ChatGPT" and use "flowery prose" recruiters push back on. This is a direct, evidence-backed reason to lead with "sounds like you," not just "AI-powered."
2. **Match Score defensibility reinforcement.** A named competitor's ATS score is called "gameable" by users (inflating scores with irrelevant keywords). This is exactly the failure mode the existing "Resumely Match Score" rebrand + non-affiliation explainer already defends against — treat this as evidence the existing positioning is correct, not a reason to change it.

**Draft promotional text variant (170 chars max) — leads with the anti-generic-AI angle, not yet approved:**
```
Tailor your resume to sound like you, not a chatbot. See what's missing for a real job, fix it with Resumely, and export a complete package from your iPhone.
```
(159 chars)

**Draft keyword additions (evaluate against the 100-byte budget with existing list):**
```
sounds like me,human resume,not generic ai
```

**Decision needed:** which promotional text variant to run (current 1.2 recommendation above, or this anti-generic-AI draft) — not yet submitted to App Store Connect.

## Post-1.2 Optimization Gate

Do not scale ASO volume, lifecycle campaigns, paid acquisition, or monetization
experiments until 1.2 is approved/live and the production funnel is readable:

`guest_mode_started -> resume_upload_cta_tapped -> resume_file_selected -> resume_upload_succeeded -> job_added -> fit_check_completed -> optimization_completed -> export_success`
