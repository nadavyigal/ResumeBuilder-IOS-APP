# Mobile UX Standards — ResumeBuilder iOS

## Core Principles

1. **One primary action per screen.** If the user has to choose between 3+ equally prominent actions, redesign.
2. **Step-by-step, not all-at-once.** Resume flows should feel guided, not like a web form dump.
3. **Never blank.** Every screen must have loading, empty, and error states.
4. **Confidence, not anxiety.** The app should make users feel like their resume is getting better, not overwhelmed by problems.
5. **Small iPhone first.** Design and test for iPhone SE (375pt wide) before expanding.

---

## Screen Layout

- Use `ScreenBackground` from `Core/DesignSystem/Components/` for consistent background
- Respect safe areas — never clip content behind notch or home indicator
- Tab bar is always at the bottom — do not overlap content with it
- Content should scroll when it might not fit (use `ScrollView` generously)

---

## Cards and Section Display

Resume sections should display as cards:
- Use `ResumeSectionCard` component from `Core/DesignSystem/Components/`
- Each card shows: section title, content preview, action (edit, apply, reject)
- Cards should have consistent padding (`AppSpacing.md`) and corner radius (`AppRadii.card`)

---

## Typography Hierarchy

| Role | Token |
|------|-------|
| Screen title | `AppTypography.h1` or `.h2` |
| Section header | `AppTypography.h3` |
| Body text | `AppTypography.body` |
| Caption / meta | `AppTypography.caption` |
| Button label | `AppTypography.button` |

Never use hardcoded font sizes (`Font.system(size: 16)`).

---

## Touch Targets

- Minimum tap target: 44×44 pt (Apple HIG requirement)
- Primary CTAs should span full width or near-full width
- Avoid tiny icon-only buttons without labels for primary actions

---

## Loading States

Always show a loading indicator during async operations:
- Use `ProgressView()` or the `GradientButton` loading state
- Show the indicator immediately — do not wait 1 second before showing it
- Use skeleton screens for content-heavy screens (cards with gray placeholders)

---

## Error States

- Show a human-readable error message — not a raw error code or technical string
- Always offer a retry action for network errors
- Never leave the user on a blank screen after an error

---

## Empty States

- Always show an empty state when a list or screen has no content
- The empty state should explain what is missing AND what the user should do
- Example: "No resume uploaded yet. Tap below to get started." + CTA button

---

## Navigation

- Use `NavigationStack` for drill-down navigation
- Use sheets (`.sheet`) for bottom-up flows (confirmations, pickers, previews)
- Use `.navigationBarTitleDisplayMode(.inline)` for nested screens
- Back button should always be accessible and functional

---

## Feedback

- Haptic feedback for important actions (successful optimization, export complete)
- Use `UIImpactFeedbackGenerator` (`.medium` for confirmations, `.success` for completions)
- Toast/alert for errors should auto-dismiss after 4 seconds

---

## Accessibility

- All images and icons must have `accessibilityLabel`
- Interactive elements must have `accessibilityHint` if the action is not obvious
- Support Dynamic Type — use `.font(AppTypography.body)` which scales automatically
- Minimum contrast ratio 4.5:1 for body text against background
