# Resume Output Quality Checklist — ResumeBuilder iOS

> Run after any change to the AI optimization flow, prompt, or API.
> Use `.agent-os/templates/resume-output-review-template.md` to document results.
> Test with at least 2 different resume + job description combinations.

---

## Content Accuracy

- [ ] No hallucinated content (no job titles, companies, or dates the user did not have)
- [ ] Original resume sections are preserved (experience, education, skills — not invented)
- [ ] Job description keywords are integrated naturally (not keyword-stuffed)
- [ ] ATS score improvement is plausible given the changes made

---

## Professional Tone

- [ ] Language is professional and confident
- [ ] No informal or colloquial language
- [ ] Consistent tense (past tense for past roles, present for current)
- [ ] No filler phrases ("responsible for", "worked on") — replaced with action verbs

---

## Bullet Point Quality

- [ ] Bullets lead with strong action verbs (Led, Built, Improved, Reduced, Delivered)
- [ ] Bullets include measurable outcomes where possible ("increased by X%", "reduced from X to Y")
- [ ] Bullets are concise (1–2 lines max)
- [ ] No bullets that are vague generalities ("assisted with various tasks")

---

## Length & Structure

- [ ] Summary section is 2–4 sentences (not a paragraph essay)
- [ ] Experience section is not truncated or cut off
- [ ] Skills section is relevant and not a dump of every technology
- [ ] Education section is preserved correctly
- [ ] No sections are missing that were present in the original resume

---

## ATS Keyword Integration

- [ ] Top keywords from the job description appear naturally in the optimized resume
- [ ] Keywords are in context (not just listed)
- [ ] The "before" ATS score vs "after" score shows meaningful improvement (>5 points)

---

## Before / After Visibility

- [ ] The user can clearly see what changed (diff view or section comparison)
- [ ] Changes are understandable without needing to re-read the whole resume
- [ ] The improvement is obvious and feels worth the credit cost

---

## Grammar & Language

- [ ] No grammatical errors
- [ ] No spelling mistakes
- [ ] No mixed languages (Hebrew and English should not appear in the same bullet unless intended)

---

## Edge Cases

- [ ] Resume with no work experience handles gracefully (student / entry level)
- [ ] Very short resume (1 page minimal) does not produce bloated output
- [ ] Job description that is very different from the resume still produces reasonable output (not random content)
- [ ] Long resume (3+ pages) is not truncated
