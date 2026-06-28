# Resumely iOS — Design Tokens (current system)

Extracted from `Core/DesignSystem/Tokens/AppColors.swift` and `Core/DesignSystem/Theme.swift`.
Designs should reuse these so returned work translates straight into SwiftUI. If you evolve a token, say so explicitly.

## Color

| Role | Token | Value |
|---|---|---|
| Background (top/bottom) | `backgroundTop` / `backgroundBottom` | `#050814` (near-black navy) |
| Background (mid / cards) | `backgroundMid` / `bgCard` | `#0D1224` |
| Glass surface fill | `glassTint` | white @ 6% opacity |
| Glass surface stroke | `glassStroke` | white @ 8% opacity |
| **Brand gradient** | start → mid → end | **`#6C63FF` (violet) → `#4EA8FF` (sky) → `#40E0D0` (cyan)** |
| Accent — violet | `accentViolet` | `#6C63FF` |
| Accent — sky (primary accent) | `accentSky` / `Theme.accent` | `#4EA8FF` |
| Accent — cyan/teal | `accentCyan` / `accentTeal` | `#40E0D0` |
| Text primary | `textPrimary` | white (100%) |
| Text secondary | `textSecondary` | white @ 60% |
| Text tertiary | `textTertiary` | white @ 35% |

**Signature treatment:** dark navy base with a top **radial glow** (an accent color at ~13% opacity, radius ~380) behind content; soft "glass" cards (6% white fill, 8% white stroke); primary actions use the violet→cyan brand gradient.

> Accessibility note from the audit: `textSecondary`/`textTertiary` (white @ 60% / 35%) on the dark cards may be **marginal contrast** — verify WCAG AA for any body/helper text in the new designs.

## Geometry

| Token | Value |
|---|---|
| Card corner radius | 16 |
| Button corner radius | 14 |
| Badge corner radius | 10 |
| Page padding (horizontal) | 20 |
| Card padding | 16 |
| Section gap | 24 |
| **Tab-bar clearance** (bottom safe space content must leave) | **100** |

> The `100pt` tab-bar clearance is exactly what the audit flagged as being violated on Home (content sitting behind the custom tab bar). Honor it.

## Typography

System font (SF). The current app leans on heavy/black rounded weights for headers (e.g. large rounded titles) and regular system weights for body. No custom font is bundled — assume **SF Pro** with `.rounded` design for display/headers. If you propose a different type system, flag it as a token change.

## Components in play (for reference)

- Custom bottom tab bar: `Core/DesignSystem/Components/ResumlyTabBar.swift` (glowing active tab).
- Step cards on Home (`stepCard`), section cards (`ResumeSectionCard.swift`).
- Background helper: `resumelyBackground(glow:)` applies the navy base + optional top radial glow.
