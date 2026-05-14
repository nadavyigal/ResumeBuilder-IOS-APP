# Testing Standards — ResumeBuilder iOS

---

## When Tests Are Required

- Every new Service must have at least one test covering the happy path
- Every new ViewModel with complex logic must have at least one test
- Bug fixes must include a test that would have caught the bug
- Parsing changes (API response decoding) must be tested with at least 2 payload shapes

---

## Test Location

All tests live in `ResumeBuilder IOS APPTests/`. Follow existing naming:
- `[ViewModel]Tests.swift` for ViewModel tests
- `[Service]Tests.swift` for Service tests
- `[Feature]ParsingTests.swift` for decode/parsing tests

---

## No Live API Calls in Tests

Tests must never call the live API. Use `MockResumeServices.swift` or create inline mocks.

```swift
// Correct — use mock
let mockService = MockResumeOptimizationService(result: .success(mockResponse))
let vm = TailorViewModel(service: mockService)

// Wrong — hits real API
let vm = TailorViewModel() // uses real service
```

---

## Test Frameworks

The project uses both XCTest and Swift Testing. Follow the pattern of the existing test file:
- `ImproveViewModelTests.swift` — XCTest pattern
- `ResumeOptimizationServiceSwiftTestingTests.swift` — Swift Testing pattern

For new tests, prefer **Swift Testing** (`@Test`, `#expect`) for new test files.

---

## Running Tests

```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

For CI with unusual derived data paths:
```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "/tmp/RB_ios_derivedData" \
  test
```

---

## Test Quality

- Tests should be deterministic — same input, same output, every time
- Tests should be fast — under 1 second each
- Tests should have descriptive names: `testOptimizeSuccessUpdatesViewModelSections()`
- Tests should test one thing at a time
- Avoid `sleep()` in tests — use async/await properly

---

## Before Marking a Story Done

- [ ] All new tests pass
- [ ] All existing tests still pass (no regressions)
- [ ] Build succeeds with tests enabled
