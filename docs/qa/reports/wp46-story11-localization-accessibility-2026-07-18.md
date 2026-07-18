# WP-46 Story 11 — Localization and accessibility check

Date: 2026-07-18  
Scope: first-session Home, upload/recovery, job input, signup, review, optimized-result navigation, and shared tab bar.

## Automated gates

- Hebrew catalog completeness: `jq` reports **0** entries without a non-empty `he` value, down from the red baseline of **99**.
- Format safety: the source and Hebrew strings have equal `%lld` placeholder counts, including positional placeholders for the two-value score string.
- Compiled catalog coverage: `FirstSessionJourneyTests.testTouchedJourneyStringsCompileWithHebrewLocalization` checks the touched FTUX strings through the app's compiled `he.lproj` bundle, not the source JSON alone.
- Debug compile: iPhone 17 / iOS 26.5 simulator build passes.
- `git diff --check`: passes.

## Documented interaction check

| Area | Evidence | Result |
|---|---|---|
| Hebrew and RTL app chrome | Clean Hebrew launch on dedicated iPhone 17 / iOS 26.5 simulator. Header, description, progress path, language switcher, and tab bar render RTL without English fallback. | Pass |
| Signup labels | Email and Password are persistent visible `Text` labels outside their placeholders. The fields expose one localized VoiceOver name each; the visible duplicate labels are accessibility-hidden. | Pass |
| VoiceOver order and names | Signup follows hero → Apple/email choice → Email → Password → submit → account-mode toggle. Home job link and pasted-description editor have explicit localized names. Recovery containers no longer combine and swallow their Retry / Choose another file buttons. The tab bar exposes localized labels, descriptive values, and selected traits. | Pass |
| Dynamic Type | Shared app typography now uses semantic text styles. Home switches its three-step path from a compressed horizontal strip to full-width rows at accessibility sizes. The compact HE/EN language codes remain 44-point controls with full localized VoiceOver names. Simulator check at Accessibility XXXL confirms reflow and vertical scrolling without truncated step names. | Pass |
| Reduce Motion | Home entrance, scrolling, tab switching, recovery banner, and signup-mode transition bypass animation when Reduce Motion is enabled; existing loading and celebration surfaces already honor the setting. | Pass |
| Keyboard avoidance | Signup uses a focused Email → Password submit chain and interactive keyboard dismissal. Home and Tailor job-input scroll views dismiss interactively, and their fields remain inside scrolling containers. | Pass |
| Contrast | Against `#050814`, measured ratios are: primary 19.98:1, secondary 10.28:1, tertiary 5.31:1, accent sky 7.96:1, accent cyan 12.17:1, warning 14.22:1. All touched text tokens meet WCAG AA normal-text contrast. | Pass |

Hebrew simulator QA also caught detached gradient presentation layers from tab matched geometry and the upload icon's repeating scale animation. Both decorative animation mechanisms were removed; the final iPhone 17 and SE captures render the selected tab and upload icon in place.

## Separate physical-device gate

RTL app chrome is verified here. The generated résumé preview, exported PDF directionality, share sheet, and text-layer behavior remain a separate Story 13 physical-iPhone gate because WebKit/PDF output must be checked from the real device and generated document. Story 11 does not claim that gate early.

Local simulator evidence captured during this check:

- `/tmp/story11-hebrew-axxxl-top.png`
- `/tmp/story11-final2-iphone17-he.png`
- `/tmp/story11-final2-se-he.png`
