# Workflow: Story Implementation

> Use this when implementing an approved development story.
> One story at a time — implement, verify, report, then ask before the next.

---

## Steps

### 1. Load Context
Read:
- `tasks/lessons.md` — constraints, rules, past mistakes
- `tasks/todo.md` — current story details and checklist
- Approved spec in `docs/specs/` — what exactly to build

### 2. Confirm Scope
Before writing any code:
- List the exact files you will change
- Confirm all new screens go in `Features/V2/`
- Confirm no new dependencies
- Confirm the story is small enough to finish in one session
- If scope is larger than expected, stop and re-scope

### 3. Write the Implementation Plan
Add to `tasks/todo.md`:
- Exact files to create/modify
- Step-by-step implementation checklist
- How you will test it

### 4. Implement

Follow these rules while coding:
- `@Observable @MainActor` for all new ViewModels
- `Sendable` for all new model types
- `Endpoint` enum for all API calls
- Design tokens from `Core/DesignSystem/Tokens/` for all new UI
- Loading, empty, and error states for all new screens
- No unrelated changes (scope gate: >3 unexpected files → stop and surface)

### 5. Xcode Build Check
```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```
Build must succeed with no errors before proceeding.

### 6. Run Tests
```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```
All tests must pass. If a test breaks, fix it before continuing.

### 7. Simulator Smoke Test
On iPhone 17 simulator AND iPhone SE simulator:
- Launch the app
- Navigate to the changed screen
- Verify the feature works end-to-end
- Verify no crash
- Verify loading/empty/error states work

### 8. Update Task Memory
- Mark checklist items done in `tasks/todo.md`
- Update `tasks/progress.md` with the completed story
- Update `tasks/session-log.md`
- Add a lesson to `tasks/lessons.md` if any mistake was caught

### 9. Report
State: what was built, what was tested, any open issues, what is next.

---

## Quality Gate Before "Done"
- [ ] Xcode build: no errors
- [ ] All tests: pass
- [ ] Simulator smoke test: complete
- [ ] `tasks/todo.md`: updated
- [ ] `tasks/progress.md`: updated
- [ ] Lesson added if applicable
