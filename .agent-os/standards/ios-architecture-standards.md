# iOS Architecture Standards — ResumeBuilder iOS

## Layer Rules

| Layer | Lives in | Responsibility | Rules |
|-------|----------|---------------|-------|
| App | `App/` | Entry, state, routing | AppState is the single source of truth for session + credits |
| Features | `Features/V2/` | Screen-level views | Thin, delegate logic to VM |
| ViewModels | `ViewModels/` or alongside screen | Business logic | `@Observable @MainActor`, one VM per screen or feature area |
| Services | `Services/` | API + data | Stateless or actor-isolated; no UIKit/SwiftUI imports |
| Models | `Models/` | Data structures | `Codable`, `Sendable`, value types (structs) |
| Core | `Core/` | Shared infrastructure | DesignSystem, Auth, Payments, API, Push, Storage |

---

## Do Not Cross Layer Boundaries Incorrectly

- Views do not call Services directly — they go through ViewModels
- Services do not know about Views — they return data, not UI state
- Models do not have business logic — they are data containers
- ViewModels do not import UIKit (use SwiftUI types where needed)

---

## AppState Is Not a Global Store

`AppState` holds only:
- `session: AuthSession?` — the current user session
- `creditsBalance: Int` — current credits
- `pendingSharedJobURL: URL?` — deep link state
- `apiClient: APIClient` — shared networking client

Do not put feature-specific state in AppState. Feature state lives in the feature's ViewModel.

---

## Service Pattern

Services are value types or actors. They do not hold UI state:

```swift
struct ResumeOptimizationService {
    func optimize(resumeId: String, jobDescription: String, token: String) async throws -> OptimizeResponse {
        // pure data work
    }
}
```

Services are injected into ViewModels via initializers for testability.

---

## Endpoint Pattern

Every API call uses an `Endpoint` case:

```swift
// In Core/API/Endpoints.swift
case optimize
case optimizationReview(id: String)

// In ViewModel or Service
let response = try await apiClient.request(.optimize, body: body, token: token)
```

Never construct URL strings in features or services.

---

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| View | `[Name]View` | `ScoreView`, `TailorView` |
| ViewModel | `[Name]ViewModel` | `ScoreViewModel`, `TailorViewModel` |
| Service | `[Name]Service` | `ResumeOptimizationService` |
| Model | Noun | `ResumeDocument`, `OptimizedResumeSection` |
| Enum | Noun | `Endpoint`, `ResumlyTab` |
| Protocol | Noun or Adjective | `ResumeOptimizing` |

---

## Test Architecture

- Tests are in `ResumeBuilder IOS APPTests/`
- Tests use `MockResumeServices.swift` — never hit the live API
- One test file per major ViewModel or Service
- Use Swift Testing (`@Test`, `#expect`) or XCTest
- Tests run with: `xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17' test`

---

## Feature Flag Pattern

There is no feature flag system currently. If a feature needs to be hidden:
- Use a `#if DEBUG` block for debug-only UI
- Do not ship half-finished UI to TestFlight — complete or remove
