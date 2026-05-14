# Template Quality Checklist — ResumeBuilder iOS

> Run after any change to the template system, design service, or template rendering.

---

## Template Gallery

- [ ] Template gallery loads within 3 seconds
- [ ] All templates show a thumbnail (no broken image placeholders)
- [ ] Template names are real and descriptive (not "Template 1", "Template 2")
- [ ] At least 3 templates are available
- [ ] Templates are visually distinct from each other (not all the same with minor color changes)

---

## Template Selection

- [ ] Tapping a template shows a preview before applying
- [ ] Selected template is visually highlighted
- [ ] "Apply" action works without crash
- [ ] After applying, the preview updates to reflect the new template

---

## Template Rendering

- [ ] All resume sections render in the template (experience, education, skills, summary)
- [ ] Section headers are styled correctly per the template
- [ ] Fonts are consistent with the template design
- [ ] Colors match the template design (not default browser colors)
- [ ] No text overflow or layout collapse

---

## Professional Quality

- [ ] Templates look professional and recruiter-appropriate
- [ ] Templates are not too colorful or gimmicky for a resume
- [ ] Templates work for both 1-page and 2-page resumes
- [ ] White space is used effectively (not too dense or too sparse)
- [ ] Typography hierarchy is clear (name > section header > body)

---

## Performance

- [ ] Switching templates does not take more than 2 seconds
- [ ] No memory spike when loading multiple templates
- [ ] Gallery scrolls smoothly without dropped frames

---

## Edge Cases

- [ ] Template renders correctly for a very short resume (minimal content)
- [ ] Template renders correctly for a long resume (2 pages)
- [ ] Template with Hebrew content renders correctly (if applicable)
- [ ] Template renders on iPhone SE without layout collapse
