# PDF Export Standards — ResumeBuilder iOS

---

## Pipeline

The current PDF export pipeline:
1. Backend generates resume HTML/CSS using the selected template
2. iOS downloads the HTML or pre-rendered PDF via `ResumeExportService`
3. `ResumePreviewWebView` (WKWebView) renders the HTML for preview
4. Export uses the downloaded PDF file via `UIActivityViewController` (share sheet)

Do not change this pipeline without an approved spec.

---

## Preview Requirements

- `ResumePreviewWebView` must load content within 3 seconds on Wi-Fi
- No blank screen during load — show a progress indicator while loading
- The preview must match what the user will receive in the exported PDF
- Pinch-to-zoom should work in the preview

---

## WKWebView Constraints

WKWebView has a sandboxed environment. Be aware:
- Custom fonts loaded via `@font-face` may fail if the font file is not accessible
- `file://` URLs are restricted — use `loadHTMLString` or `load(URLRequest)` via HTTPS
- JavaScript execution is allowed but should be minimal
- Some CSS properties (especially `position: fixed`) behave differently in print vs. screen

---

## Export Quality

- Exported PDF must be selectable text (not a rasterized image)
- PDF page count: 1 page for most resumes, 2 pages maximum
- File size: < 5 MB for a 1-page resume
- PDF filename format: `resume-[name]-[date].pdf` or similar (not a UUID)

---

## Share Sheet

- Always use `UIActivityViewController` for sharing
- The share sheet must appear within 2 seconds of tapping the export button
- Support at minimum: AirDrop, Files, Mail, Messages

---

## Physical Device Testing (Required Before TestFlight)

WKWebView rendering on real hardware differs from the simulator in:
- Font rendering (anti-aliasing, weight)
- Memory limits (large HTML may crash on older devices)
- Network speed (simulate slow network)

**Rule: Test PDF preview and export on a physical iPhone before any TestFlight upload.**

---

## Error Handling

| Scenario | Expected behavior |
|----------|------------------|
| Download fails | Error message + retry button |
| WebView fails to load | Error message + retry button |
| File too large | Warning before download |
| No network | Graceful error — not a crash |
