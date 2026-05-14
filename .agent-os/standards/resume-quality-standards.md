# Resume Quality Standards — ResumeBuilder iOS

> Standards for evaluating AI-generated resume content.
> Apply these when reviewing output from the optimization API.

---

## No Hallucination — This Is Non-Negotiable

The AI must never invent:
- Job titles the user did not have
- Companies the user did not work at
- Dates the user did not provide
- Skills the user did not list
- Degrees or certifications the user did not earn
- Metrics or numbers that are not grounded in the original resume

If the AI cannot improve a section without inventing content, it should improve tone/structure only.

---

## Action Verbs

Every experience bullet should start with a strong past-tense action verb:

**Good:** Led, Built, Designed, Delivered, Reduced, Increased, Implemented, Launched, Managed, Optimized

**Bad:** Was responsible for, Helped with, Assisted in, Worked on, Participated in

---

## Measurable Results

Bullets with numbers are better than bullets without:
- "Reduced deployment time by 40% by implementing CI/CD pipeline" > "Improved deployment process"
- "Led team of 8 engineers across 3 countries" > "Led a team of engineers"

If the original resume has numbers, they must be preserved. Do not invent numbers.

---

## Summary Section

- 2–4 sentences maximum
- States: who the person is + what they do + what makes them strong
- Should be tailored to the target job description (when available)
- No clichés: "results-driven", "passionate", "dynamic", "go-getter"

---

## Skills Section

- List only skills the user mentioned in the original resume
- Group by category if more than 8 skills (Technical, Languages, Tools)
- ATS keywords from the job description may be added IF the user demonstrably has that skill

---

## ATS Optimization

- Top 5–7 keywords from the job description should appear in the resume
- Keywords must appear in context (not in a "keywords" section that ATS systems flag)
- Keyword density should feel natural — not stuffed

---

## Section Completeness

After optimization, verify all sections that existed in the original are still present:
- Summary / Objective
- Work Experience
- Education
- Skills
- (Optional: Certifications, Projects, Languages, Publications)

No section may be dropped unless the user explicitly requests it.

---

## Tone

- Professional but human — not robotic or overly formal
- Consistent tense: past tense for past roles, present tense for current role
- Third person for skills/summary ("Experienced engineer..." not "I am an engineer...")
- No exclamation marks in resume content

---

## Before / After Comparison

The app should make the improvement visible:
- Show score improvement (ATS score before → after)
- Show what changed section by section
- Never overwrite the original without showing the diff
