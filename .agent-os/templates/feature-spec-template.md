# Feature Spec — [Feature Name]

**Date:** YYYY-MM-DD
**Status:** Draft | Approved
**Brief:** `docs/specs/drafts/[feature-slug]-brief.md`

---

## Objective
_One sentence: what this feature does and why._

## User Story
As a [user type], I want to [action] so that [outcome].

## Acceptance Criteria
- [ ] _Criterion 1_
- [ ] _Criterion 2_
- [ ] _Criterion 3_

## API Changes

### New Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/...` | _What it returns_ |

### Modified Endpoints
_List any changes to existing endpoints._

### Request / Response Shapes
```json
{
  "field": "value"
}
```

## iOS Changes

### New Files
| File | Purpose |
|------|---------|
| `Features/V2/[Name]/[Name]View.swift` | _Screen view_ |
| `Features/V2/[Name]/[Name]ViewModel.swift` | _Business logic_ |

### Modified Files
| File | Change |
|------|--------|
| `[path]` | _What changes_ |

### Navigation
_How does the user reach this feature? What navigation changes are needed?_

## Development Stories
1. Story 1: [title] — estimated [S/M/L]
2. Story 2: [title] — estimated [S/M/L]
3. Story 3: [title] — estimated [S/M/L]

## Open Questions
1. _Unresolved question_

## Out of Scope
- _What this spec does NOT include_
