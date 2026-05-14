# Template Quality Standards — ResumeBuilder iOS

---

## Template Identity

- Every template must have a real name (not "Template 1", "Classic", "Modern")
- Names should be evocative of the template's personality: "Slate", "Meridian", "Ember", etc.
- Templates must be visually distinct from each other — different typography, layout, or color palette

---

## Thumbnail Quality

- Template thumbnails must render from real template HTML/CSS (not a static image)
- Thumbnails should be generated at a standard size and cached
- No broken image placeholders in the template gallery
- Thumbnails should load within 2 seconds

---

## Template Rendering Requirements

- All resume sections must render: Summary, Experience, Education, Skills
- Section headers must be visually distinct from body text
- Experience entries must show: company, title, dates, bullet points
- Bullet points must be indented and marked (bullet symbol or dash)
- Contact info (name, email, phone) must appear at the top

---

## Design Quality

- Templates should look appropriate for professional job applications
- Avoid overly colorful or decorative designs (colored photo boxes, heavy gradients)
- Typography must be legible at normal PDF viewing size
- Line height should be comfortable (1.4–1.6× font size)
- Margins should be 0.75–1 inch on all sides

---

## Performance

- Switching templates should update the preview in < 2 seconds
- Template gallery should scroll at 60fps (no dropped frames)
- Template CSS/HTML should not block WebView rendering

---

## Compatibility

- Templates must render correctly in WKWebView (iOS system browser engine)
- Avoid CSS features that WKWebView does not support (check against iOS 17 compatibility)
- PDF export from template must produce a correctly formatted single or two-page document
- Test each template with a short resume AND a long resume (2 pages)
- Test each template on iPhone SE viewport (375pt)
