# Workflow: Resume Output Review

> Use after any change to the AI optimization flow, prompt, or API.
> Use `.agent-os/templates/resume-output-review-template.md` for the report.

---

## Steps

### 1. Prepare Test Cases
Select at least 2 test combinations:
1. **Standard case:** Mid-level software engineer resume + relevant job description
2. **Edge case:** Entry-level resume (little experience) + demanding job description

For each: save the original resume PDF and job description text for comparison.

### 2. Run the Optimization
In the app (simulator or device):
- Upload the test resume
- Paste the job description
- Run the optimization
- Record the ATS score before and after

### 3. Evaluate Output Quality
For each test case, work through `docs/qa/resume-output-quality-checklist.md`:

**Content accuracy:** No hallucinated content
**Tone:** Professional, action-verb bullets
**Bullet quality:** Measurable results, no filler
**Length:** Summary 2–4 sentences, sections not truncated
**Keywords:** Top job description keywords appear naturally
**Before/after:** Improvement is visible and meaningful

### 4. Check Section Completeness
Verify all original sections are present in the output:
- Summary, Experience, Education, Skills (at minimum)
- No section dropped without cause

### 5. Check AI Suggestion Display
In the app UI:
- Are changes shown as a diff (before/after), not auto-applied?
- Can the user accept or reject individual changes?
- Is the ATS score improvement shown?

### 6. Edge Case Check
- Run with a very short resume (1 job, 1 education) — does it produce reasonable output?
- Run with a job description very different from the resume — does it fail gracefully (not invent content)?

### 7. Write the Report
Use `.agent-os/templates/resume-output-review-template.md`.
Save to `docs/qa/reports/resume-output-[date].md`.

---

## Pass Criteria
- No hallucinated content in any test case
- All original sections preserved
- ATS score improves by > 5 points in standard case
- Professional tone in all output
- Before/after is visible in the UI
