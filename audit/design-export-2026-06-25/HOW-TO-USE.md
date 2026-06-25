# How to run the external Claude design session

This folder is a self-contained handoff. Take it into a Claude.ai chat/project with design capability, iterate, then bring the results back here for SwiftUI implementation.

## Steps

1. **Start a new Claude.ai chat** (or project) — use one with image/design generation.
2. **Paste `DESIGN-BRIEF.md`** as the first message (the full product + problem + per-screen brief).
3. **Attach the 6 screenshots** from `../product-design-resumebuilder-ios-2026-06-16/` (see list below).
4. **Attach or paste `DESIGN-TOKENS.md`** so the output stays on-brand and implementable.
5. **Kick off** with something like:
   > "You're redesigning a native iOS (SwiftUI) app. Read the brief and tokens. Bold reimagining is welcome but it must stay native iOS, dark-brand-recognizable, and respect Dynamic Type / RTL / VoiceOver. Start with Screen A (Home) and Screen B (Upload) — they're the activation bottleneck. For each screen give me: a hi-fi mockup, a short rationale, implementation notes (layout/spacing/tokens/components/motion), and any new copy. Flag anything needing new backend."
6. **Iterate** screen by screen. Push for the activation-critical two first.

## The 6 screenshots (what each is)

| File | Screen | What to fix |
|---|---|---|
| `01-home-entry.jpg` | Home / first run | Tab bar overlaps step 3; make upload the obvious next action |
| `02-upload-file-picker-empty-recents.jpg` | Upload → Files picker, empty | No app-level guidance; biggest drop-off; consider non-file routes |
| `03-optimized-empty-state.jpg` | Optimized tab (locked) | Undersells reward; generic CTA |
| `04-design-locked-state.jpg` | Design tab (locked) | No preview of templates/value |
| `05-expert-locked-state.jpg` | Expert tab (locked) | No preview of expert workflows |
| `06-me-mixed-language-rtl-state.jpg` | Me / account (guest) | Mixed EN/HE/RTL — trust hit |

## Bringing it back

Save what you get back into `returns/` in this folder — ideally:

- `returns/<screen>-mockup.<png|jpg>` — the image(s)
- `returns/<screen>-notes.md` — rationale + implementation notes + copy

…or just paste the designs + notes back into the Claude Code session here. Then implementation proceeds **one screen at a time, Home + Upload first**, each as its own branch/PR with the existing review + test gates.

## Guardrails to repeat to the external session

- Native iOS / SwiftUI only — no web patterns, no new UI frameworks.
- Dark-brand-recognizable; reuse the tokens unless a change is called out.
- First-run **upload → first result** must get *easier*, not just prettier.
- Respect Dynamic Type, Hebrew RTL, VoiceOver, reduced motion.
- Flag anything needing new backend data/endpoints.
