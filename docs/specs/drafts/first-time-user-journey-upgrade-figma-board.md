# Figma Board Blueprint — Resumely First-Time Journey Upgrade

**Board title:** Resumely iOS — First-Time Journey Upgrade
**Source:** `docs/audits/first-time-user-journey-audit.md`
**Status:** Created in FigJam with generated journey/roadmap content and the 20-screen evidence contact sheet
**FigJam:** https://www.figma.com/board/CzeP8zhgeDi5qA5hb97Pzt/Resumely-iOS-%E2%80%94-First-Time-Journey-Upgrade?node-id=1-2&t=owAnanLWhh9UcdUN-0
**Evidence sheet:** `docs/audits/first-time-user-journey-figma-contact-sheet.jpg`

## Board Structure

Create a FigJam board with five horizontal sections from left to right.

### 1. Audit verdict

- Title and date.
- Overall score: 4/10.
- Strongest advantage: guest-first, job-specific insight.
- Biggest trust risk: precise scores paired with malformed or fact-changing advice.
- North-star journey: Choose résumé → Add job → Guest diagnosis → Account → Safe review → Preview → Save/export → Another job.

### 2. Current journey evidence

Arrange all 20 screenshots in chronological order, grouped into five columns:

| Column | Screens | Health summary |
|---|---|---|
| Entry | 01–04 | Strong start; hidden validation rule |
| Guest value | 05–08 | Early value; content/auth trust gaps |
| Repetition | 09–11 | Analyze and Fit repeated; credibility drops |
| Review/completion | 12–18 | Regressive advice; blank/locked critical failure |
| Return/localization | 19–20 | Saved work absent; Hebrew incomplete |

Use green, amber, red, and dark-red status tags for Good, Mixed, Poor, and Critical. Add one short evidence note below each screenshot, using the audit’s “General health” sentence.

### 3. Failure map

Connect the current journey with red arrows at four failure clusters:

1. **Input mismatch:** non-empty CTA → backend 100-word rejection.
2. **Continuity reset:** guest diagnosis → signup → Analyze again → Check Fit again.
3. **Trust collapse:** bad keyword evidence → lower projected score → factual changes default on.
4. **Completion collapse:** Apply → blank screen → locked tabs ↔ Account says completed → saved list empty.

For each cluster, add: observed evidence, likely implementation cause, user emotion, and abandonment consequence.

### 4. Proposed journey

Plot eight large dark-mode mobile-stage cards:

1. Résumé ready.
2. Job validated inline.
3. Guest diagnosis with source evidence.
4. Account creation that preserves context.
5. Review fixes with Accept/Edit/Skip and fact warnings.
6. Apply success with one deterministic transition.
7. Optimized preview with save/export status.
8. Optimize another job using the saved résumé.

Under each stage, show the product rule and canonical analytics event. Mark `optimized_preview_rendered` as the activation moment.

### 5. Delivery roadmap

Create three swimlanes:

- **Release A — Trustworthy completion:** Stories 1–6; P0; exit with valid export and relaunch recovery.
- **Release B — Continuous evidence-backed journey:** Stories 7–10; P1; exit with one post-signup confirmation and canonical activation.
- **Release C — Reach and retention:** Stories 11–13; P2; exit with accessibility/localization, second-job loop, and rerun audit.

Add a separate “Not now” box: monetization, paid acquisition, full résumé builder, broad visual rebrand, and new dependencies.

## Visual Style

- Match the app’s dark-mode visual language: near-black canvas sections, white headings, violet/blue accent, teal success, amber caution, red failure.
- Use screenshots at their original aspect ratio; never crop away navigation or error evidence.
- Keep annotations concise and readable at 100% zoom.
- Use solid connectors for observed transitions and dashed connectors for proposed transitions.
- Add a small legend for evidence, inference, product decision, P0/P1/P2, and health colors.

## Screenshot Directory

`docs/audits/first-time-user-journey-evidence/`

The 20 accepted files are numbered `01` through `20` and must appear in that order.
