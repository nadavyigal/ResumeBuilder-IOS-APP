# PDF Export Checklist — ResumeBuilder iOS

> Run before any TestFlight build that includes changes to templates, PDF export, or WKWebView.
> Test on a physical iPhone, not just simulator — WKWebView behavior can differ.

---

## WKWebView Preview Rendering

- [ ] ResumePreviewWebView loads without blank screen
- [ ] Content renders within 3 seconds on Wi-Fi
- [ ] No JavaScript errors in console during preview load
- [ ] All resume sections are visible in the preview
- [ ] Selected template styles are applied (not default/plain HTML)
- [ ] Fonts load correctly (no missing or fallback fonts)
- [ ] No text overflow beyond page margins

---

## Layout Quality

- [ ] Text does not overflow off the right edge
- [ ] Page breaks appear at logical section boundaries
- [ ] Margins are consistent on all sides
- [ ] Section headers are visually distinct from body text
- [ ] Line spacing is comfortable (not too tight or too loose)

---

## iPhone SE Viewport

- [ ] Preview renders correctly on 375pt wide screen (iPhone SE)
- [ ] Pinch-to-zoom works if preview is zoomed
- [ ] No horizontal scrollbar visible

---

## Export / Share

- [ ] "Export PDF" or "Share" button triggers iOS share sheet
- [ ] Share sheet includes: AirDrop, Files, Mail, Messages (standard iOS options)
- [ ] Tapping "Save to Files" saves the PDF to Files app successfully
- [ ] Saved PDF opens correctly in Files app
- [ ] PDF filename is meaningful (not a random UUID)
- [ ] PDF file size is reasonable (< 5 MB for a 1-page resume)

---

## PDF Document Quality

- [ ] Open exported PDF in Preview (Mac) or Files (iOS) — no rendering errors
- [ ] Text is selectable in the PDF (not a rasterized image)
- [ ] All sections present in preview are present in the exported PDF
- [ ] Page count matches expected (1 page for standard resume, 2 max)

---

## Hebrew / RTL (if applicable — currently not in scope)

- [ ] Hebrew text renders right-to-left
- [ ] Mixed Hebrew/English content aligns correctly
- [ ] PDF export preserves RTL direction

---

## Error Handling

- [ ] If download fails, user sees a meaningful error (not a blank screen)
- [ ] Retry is possible after a failed export
- [ ] No crash if network disconnects during download
