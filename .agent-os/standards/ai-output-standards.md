# AI Output Standards — ResumeBuilder iOS

> Standards for how AI suggestions are presented to users in the app.

---

## Show Diffs, Not Replacements

AI suggestions should be shown as **proposed changes** the user can review, not as auto-applied rewrites.

- Show "before" and "after" for each section that changes
- Use `BulletDiffRow` component for bullet-level diffs
- Allow the user to accept, reject, or edit each change
- Never silently overwrite the user's original content

---

## Confidence and Score

Where possible, show the user why a change improves their resume:
- Display ATS score before and after (shown via `ATSDial`)
- Show which keywords were added and why (from job description matching)
- If a section score improved, indicate that clearly

---

## Progress During AI Calls

During optimization or AI analysis calls:
- Show a progress indicator immediately (do not wait for the response)
- Use `OptimizingView` for the tailor flow — it communicates "work is happening"
- Never show a blank screen during an API call longer than 0.5 seconds
- Provide a cancel option for long-running calls if feasible

---

## Errors and Fallbacks

If the AI call fails:
- Show a human-readable message: "We couldn't optimize your resume. Please try again."
- Never show a raw API error string to the user
- Always offer a retry action
- If the optimization partially succeeded, show what was completed rather than nothing

---

## User Control

The user should always feel in control of their resume:
- No AI change is permanent until the user explicitly applies it
- The user can always return to their original upload
- "Apply" is always a deliberate action, never automatic

---

## Chat AI (ChatView)

The chat feature (`Features/V2/Chat/`) allows users to refine their resume via conversation:
- Pending changes from chat appear in `PendingChangeCard` components
- User must explicitly approve pending changes before they are written to the resume
- Chat responses should be concise — not essays
- If the AI doesn't understand, it should ask for clarification, not guess

---

## Expert Modes (ExpertModesView)

Expert workflow outputs (deep analysis, specific improvement strategies) should:
- Be clearly labeled as "Expert Analysis" — not confused with core ATS scoring
- Show structured sections (Strengths, Gaps, Recommendations) — not free-form text
- Be exported or saved for the user's reference
