# PR Summary — [PR Title]

**Branch:** `[branch-name]`
**Date:** YYYY-MM-DD
**Type:** feat | fix | chore | refactor | test
**Story:** [Story title from dev-story-template]

---

## What Changed
_2–4 bullet points. What was built or fixed and why._

- [Changed X in Y to enable Z]
- [Added A to fix B]
- [Removed C because D]

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `[path]` | Created | _What it is_ |
| `[path]` | Modified | _What changed_ |
| `[path]` | Deleted | _Why removed_ |

## Tests
- Tests run: ✅ All pass | ❌ Failures: [details]
- New tests added: [Yes — [file]] | No
- Test command:
  ```bash
  xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17' test
  ```

## QA
- Simulator smoke test: ✅ Done (iPhone 17 + iPhone SE) | ❌ Not done
- iOS QA checklist: ✅ Passed | ❌ Not run | ⚠️ Partial — [notes]

## Known Issues / Follow-ups
- _Any known remaining issues or follow-up stories_

## How to Test
1. _Step 1_
2. _Step 2_
3. _Expected result_
