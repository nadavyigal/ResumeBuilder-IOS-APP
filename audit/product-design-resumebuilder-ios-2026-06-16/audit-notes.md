# Product Design Audit: ResumeBuilder iOS

Date: 2026-06-16
Device: iPhone 17 Pro simulator, iOS 26.5
Mode: Combined UX and accessibility audit from fresh screenshots
Scope: First-run resume-improvement journey across Home, upload entry, empty/locked tabs, and Me/account state.

## Evidence

1. `01-home-entry.jpg` - Home entry with upload, job entry, and Free ATS Check.
2. `02-upload-file-picker-empty-recents.jpg` - Files picker opened from Upload Resume, empty Recents state.
3. `03-optimized-empty-state.jpg` - Optimized tab before any optimization exists.
4. `04-design-locked-state.jpg` - Design tab before optimization.
5. `05-expert-locked-state.jpg` - Expert tab before optimization.
6. `06-me-mixed-language-rtl-state.jpg` - Me tab in guest state with mixed English/Hebrew/RTL content.

## Numbered Flow Health

1. Home entry - Mostly healthy, visually polished, but bottom navigation overlaps the lower Free ATS Check step on this viewport.
2. Upload picker - Risky. The app correctly opens Files, but an empty Recents state gives no app-level recovery guidance or sample expectations.
3. Optimized empty state - Healthy but thin. Clear message and return action, though it repeats the tab navigation instead of showing progress expectations.
4. Design locked state - Clear but low-motivation. It explains the gate, but does not preview the value of templates/design.
5. Expert locked state - Clear but low-motivation. It says how to unlock, but not what expert workflows will do for the user.
6. Me/account state - Needs attention. Strong trust/security intent, but mixed language and RTL/LTR behavior create a confidence hit.

## Strengths

- The first screen has a strong product promise: "Upload, match to a job, and get your first diagnosis in under 2 minutes."
- The step-based Home layout makes the intended sequence easy to understand: upload resume, add job, check ATS.
- The dark visual system feels coherent across the core surfaces: glowing active tab, soft cards, and icon-led empty states.
- Empty states are not dead ends; Optimized, Design, and Expert all provide a "Go to Home" recovery action.
- The Me tab includes useful trust copy about privacy and resume data.

## UX Risks

1. Bottom navigation crowds primary content on Home.
   Evidence: `01-home-entry.jpg`. The persistent tab bar covers or visually competes with the "Free ATS Check" card. The user can infer a third step exists, but the actionable portion is partly hidden at rest.

2. Upload starts with an empty system state and no app-level help.
   Evidence: `02-upload-file-picker-empty-recents.jpg`. Files opens to "No Recents." A new user with a resume stored in Downloads, iCloud, Gmail, or another app gets no ResumeBuilder-specific hint about where to browse or what valid files look like.

3. Locked tabs explain the dependency but undersell the reward.
   Evidence: `03-optimized-empty-state.jpg`, `04-design-locked-state.jpg`, `05-expert-locked-state.jpg`. Each screen says to optimize on Home, but none show a preview of the eventual resume, template choices, ATS fixes, cover letter, or submit package.

4. Multiple "Go to Home" buttons add repeated navigation without new guidance.
   Evidence: `03`, `04`, `05`. The button is usable, but it duplicates the Home tab. More helpful copy would tell the user exactly which missing input is required.

5. Localization state appears inconsistent.
   Evidence: `06-me-mixed-language-rtl-state.jpg`. Me shows English strings ("Guest mode", "Sign in to save optimizations and export PDFs") beside Hebrew labels and an RTL tab order. This can make the app feel unfinished, especially in a trust-sensitive resume product.

## Accessibility Risks

1. Possible content obstruction by the custom tab bar.
   Evidence: `01-home-entry.jpg`. The bottom card sits behind or too close to the tab bar. This is especially risky for Dynamic Type, zoomed display, and smaller iPhones.

2. Some tappable controls have icon-only or generic labels in the runtime snapshot.
   Evidence: simulator accessibility snapshots during capture. The Files/Me language area included a tab target with no visible label in the snapshot. This needs VoiceOver verification on device.

3. Mixed RTL/LTR content may produce confusing reading order.
   Evidence: `06`. Hebrew section labels and English body copy appear together. The screenshot alone cannot prove VoiceOver order, but it is a likely assistive-tech risk.

4. Low-contrast secondary text may be marginal in dark mode.
   Evidence: `01`, `06`. Several helper lines use muted gray on dark navy/purple cards. A contrast pass is needed before claiming WCAG compliance.

## Evidence Limits

- I could not complete a real optimize flow because this run did not select a real PDF or authenticate against live backend services.
- The upload picker screenshot is accepted evidence for the upload entry, but not for successful file selection, PDF validation, diagnosis loading, or optimization completion.
- Screenshot-only review cannot verify VoiceOver order, Dynamic Type reflow, reduced motion, keyboard focus, backend error handling, or PDF export quality.
- The simulator accessibility bridge became unreliable on the localized Me screen, so the localization finding is based on visible screenshots plus the captured runtime text, not a completed language-toggle interaction.

## Recommendations

1. Add bottom safe-area padding or scroll affordance on Home so "Free ATS Check" is fully visible above the tab bar.
2. Add a short pre-picker hint near Upload Resume: supported file type, where to find files, and what happens after selection.
3. Make locked tabs more motivating: show one compact preview row for the future output and replace generic "Go to Home" with "Upload resume on Home" or "Add resume + job on Home."
4. Fix the Me tab localization state so language selection, tab order, and copy are consistently English or consistently Hebrew/RTL.
5. Run a follow-up authenticated audit for optimize -> diagnosis -> improve -> export/submit package, because that is the actual value moment.
