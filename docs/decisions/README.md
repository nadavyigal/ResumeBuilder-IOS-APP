# Architecture & Product Decisions

> Log of key decisions made for the ResumeBuilder iOS app.
> Add a new entry whenever a non-obvious architectural or product decision is made.

## Decision Format

**Date:** YYYY-MM-DD
**Decision:** _What was decided_
**Alternatives considered:** _What else was considered_
**Reason:** _Why this choice was made_

---

## Decisions

### SwiftUI — Not UIKit

**Date:** 2025 (project start)
**Decision:** Build entirely in SwiftUI. No UIKit views.
**Alternatives considered:** UIKit, hybrid approach
**Reason:** iOS 17+ target allows full SwiftUI. Modern, declarative, better for rapid iteration. WKWebView is wrapped where needed.

---

### @Observable — Not ObservableObject / Combine

**Date:** 2025 (project start)
**Decision:** Use Swift Observation (`@Observable`, `@MainActor`) for all ViewModels and AppState.
**Alternatives considered:** `ObservableObject` + `@Published` (Combine)
**Reason:** Swift Observation is the modern replacement for Combine on iOS 17+. It has better performance (only re-renders what observed), cleaner syntax, and is compatible with Swift 6 strict concurrency.

---

### Features/V2/ Migration

**Date:** 2026 (during consolidation)
**Decision:** All new screens and feature work go in `Features/V2/`. Legacy screens in `Features/` are left in place until migrated.
**Alternatives considered:** Rename in place, migrate all at once
**Reason:** Avoids a big-bang migration while still establishing a clear direction. V2 folder signals "this is the current standard."

---

### Dark Mode Only

**Date:** 2025
**Decision:** App launches in dark mode only via `.preferredColorScheme(.dark)`.
**Alternatives considered:** Adaptive (light + dark), light only
**Reason:** Design system and brand aesthetic are calibrated for dark. Supporting both modes doubles the design QA surface. Can be revisited post-launch.

---

### Endpoint Enum API Pattern

**Date:** 2025
**Decision:** All API calls go through the `Endpoint` enum in `Core/API/Endpoints.swift` → `APIClient`. No raw URL strings in feature code.
**Alternatives considered:** Feature-level URL strings, separate per-service base URLs
**Reason:** Centralizes API surface, makes environment switching clean (API_BASE_URL from Info.plist), enables easy auditing of all endpoints.

---

### No SPM Dependencies

**Date:** 2025
**Decision:** Project uses only Apple system frameworks. No Swift Package Manager dependencies.
**Alternatives considered:** Alamofire (networking), Kingfisher (images), etc.
**Reason:** Minimizes binary size, signing complexity, and supply-chain risk. System frameworks (URLSession, WKWebView, StoreKit) handle all requirements.

---

### Sign in with Apple — Primary Auth

**Date:** 2025
**Decision:** Sign in with Apple is the primary (and only) sign-in method.
**Alternatives considered:** Email/password, Google Sign-In, Supabase Auth
**Reason:** Required for App Store approval if social auth is offered. Provides best UX on iOS (native prompt, no form). Minimizes PII stored.

---

### Credits Model for Monetization

**Date:** 2025
**Decision:** Users purchase credits via IAP; credits are consumed per optimization run.
**Alternatives considered:** Subscription, freemium with hard limits
**Reason:** Pay-per-use aligns cost with value for users who optimize occasionally. Simpler to explain than a subscription. Can layer subscription on top later.
