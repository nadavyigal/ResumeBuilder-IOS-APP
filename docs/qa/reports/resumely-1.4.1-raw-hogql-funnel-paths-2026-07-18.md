# Resumely 1.4.1 Privacy-Safe Ordered Paths - 2026-07-18

Canonical UTC window: `2026-07-11T00:00:00Z` through `2026-07-18T11:38:35.338292Z`.

No clean person remains after the contract's person-level exclusions, so no clean ordered path can be published. No identifiers, emails, resume content, job text, tokens, or full person IDs are stored here.

## Aggregate audit evidence only

| Raw event population | People | Clean people |
|---|---:|---:|
| `app_launched` | 12 | 0 |
| `resume_upload_cta_seen` | 12 | 0 |
| `resume_upload_cta_tapped` | 5 | 0 |
| `resume_file_picker_opened` | 5 | 0 |
| `resume_file_selected` | 3 | 0 |
| `resume_file_picker_cancelled` | 2 | 0 |
| `resume_uploaded` | 3 | 0 |
| `resume_upload_succeeded` (diagnostic only) | 3 | 0 |
| `job_added` | 3 | 0 |
| `optimization_started` | 3 | 0 |
| `optimization_completed` | 2 | 0 |
| `optimized_viewed` | 4 | 0 |
| `export_cta_seen` | 4 | 0 |

The ordered raw audit finds five first picker openers: three selected within one hour, two cancelled before selection, and none did neither. These are excluded-only observations and are not evidence of user behavior or a product bottleneck.

The linked autopsy contains the cohort audit, exact HogQL, coverage, and July 25 re-read condition: `resumely-1.4.1-raw-hogql-funnel-autopsy-2026-07-18.md`.
