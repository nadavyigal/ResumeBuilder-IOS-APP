# Current iOS Architecture — ResumeBuilder iOS

**Last updated:** 2026-05-13

---

## Tech Stack

| Item | Value |
|------|-------|
| Language | Swift 6.0 (strict concurrency enabled) |
| UI framework | SwiftUI (no UIKit) |
| iOS target | iOS 17.0+ |
| Architecture | MVVM |
| State management | Swift Observation (`@Observable`, `@MainActor`) |
| Persistence | `ModelContainer.swift` (SwiftData or custom — see file) |
| Auth | Sign in with Apple + custom JWT + `KeychainStore` |
| Payments | StoreKit 2 |
| Networking | `URLSession` via custom `APIClient` |
| PDF preview | `WKWebView` (`ResumePreviewWebView.swift`) |
| SPM packages | None — pure system frameworks |
| Xcode required | Xcode 16+ |

---

## Layer Map

```
ResumeBuilder_IOS_APPApp.swift   ← @main entry point
    └── ContentView.swift
        └── AppState (@Observable, bootstraps session)
            └── RootView.swift (auth gate: onboarding vs. main)
                └── MainTabViewV2.swift
                    ├── Score tab   → ScoreView (Features/V2/Score/)
                    ├── Tailor tab  → TailorView (Features/Tailor/)
                    ├── Design tab  → RedesignResumeView (Features/V2/Design/)
                    ├── Track tab   → ApplicationsListView (Features/Track/)
                    └── Profile tab → ProfileView (Features/V2/Profile/)
```

---

## Key Files by Layer

### App Layer
| File | Purpose |
|------|---------|
| `App/AppState.swift` | Global observable state: session, credits, deep links |
| `App/MainTabViewV2.swift` | 5-tab container; VMs instantiated here as `@State` |
| `App/RootView.swift` | Auth gate — shows Onboarding or MainTabViewV2 |
| `App/DeepLinkRouter.swift` | Parses incoming URLs for shared job links |

### Features (active — V2)
| Path | Screens |
|------|---------|
| `Features/V2/Score/` | ScoreView, ScoreResultView, ATSBreakdownView, IssuesSummaryView, QuickWinsSection |
| `Features/V2/Improve/` | ImproveView, OptimizedResumeView, OptimizationDesignSheet |
| `Features/V2/Design/` | RedesignResumeView |
| `Features/V2/Chat/` | ChatView, PendingChangeCard |
| `Features/V2/Expert/` | ExpertModesView, ExpertReportView |
| `Features/V2/History/` | HistoryView, ModificationHistoryView, OptimizationReviewView |
| `Features/V2/Preview/` | ResumePreviewExportView, ResumePreviewWebView |
| `Features/V2/Scan/` | ScanResumeView |
| `Features/V2/Home/` | HomeView |
| `Features/V2/Profile/` | ProfileViewV2 |
| `Features/Tailor/` | TailorView, TailorViewModel, OptimizingView |
| `Features/Track/` | ApplicationsListView, ApplicationDetailView, ApplicationCompareView |
| `Features/Onboarding/` | OnboardingView, ImportResumeView |

**Important:** `Features/` (top-level, non-V2) is legacy. All new screens go in `Features/V2/`.

### ViewModels
All ViewModels use `@Observable @MainActor`. They live in `ViewModels/` (shared) or alongside their feature screen.

Key VMs: `ScoreViewModel`, `TailorViewModel`, `DesignViewModel`, `OptimizedResumeViewModel`, `ImproveViewModel`, `ResumePreviewViewModel`, `ResumeManagementViewModel`, `ProfileViewModel`, `HomeViewModel`, `ScanViewModel`.

### Services
| File | Purpose |
|------|---------|
| `Services/ResumeUploadService.swift` | Upload PDF to backend |
| `Services/ResumeOptimizationService.swift` | Call `/api/optimize`, parse sections |
| `Services/ResumeDesignService.swift` | Fetch templates, apply design |
| `Services/ResumeAnalysisService.swift` | ATS score and analysis |
| `Services/ResumeExportService.swift` | Download and share optimized PDF |
| `Services/RecentExportsService.swift` | Local cache of recent export records |
| `Services/OptimizationHistoryService.swift` | Fetch optimization history |
| `Services/MockResumeServices.swift` | Test mocks for all services |

### Models
All models are `Codable` + `Sendable` structs.

| File | Key type |
|------|---------|
| `Models/ResumeDocument.swift` | `ResumeDocument` — uploaded file metadata |
| `Models/ResumeAnalysis.swift` | ATS analysis result |
| `Models/OptimizedResumeSection.swift` | Resume section after optimization |
| `Models/DesignTemplate.swift` | Template metadata |
| `Models/ResumeExport.swift` | Export record |

### Core
| Path | Purpose |
|------|---------|
| `Core/API/Endpoints.swift` | `Endpoint` enum — all API route definitions |
| `Core/API/ApplicationTrackingService.swift` | Job application CRUD |
| `Core/Auth/AuthService.swift` | JWT session management |
| `Core/Auth/SignInWithAppleCoordinator.swift` | Apple sign-in coordinator |
| `Core/Auth/KeychainStore.swift` | Secure token storage |
| `Core/Payments/StoreKitManager.swift` | IAP products + purchase flow |
| `Core/Payments/ReceiptVerifier.swift` | Server-side receipt verification |
| `Core/Storage/ModelContainer.swift` | Local persistence container |
| `Core/Push/PushService.swift` | Push notification registration |
| `Core/DesignSystem/Theme.swift` | Global theme values |
| `Core/DesignSystem/Tokens/` | AppColors, AppSpacing, AppTypography, AppShadows, AppRadii, AppGradients |
| `Core/DesignSystem/Components/` | Reusable UI components (ATSDial, ResumlyTabBar, GradientButton, MetricCard, etc.) |

---

## API Pattern

```
Endpoint enum (Endpoints.swift)
    → APIClient (on AppState)
        → Service (e.g. ResumeOptimizationService)
            → ViewModel (e.g. TailorViewModel)
                → View (e.g. TailorView)
```

The `APIClient` attaches the JWT from `AppState.session` to requests. The base URL comes from `API_BASE_URL` in Info.plist — it is never hardcoded.

---

## Auth Flow

```
App launch → AppState.bootstrapAndRefreshSession()
    → AuthService.shared.restoreSession() (reads Keychain)
    → If no session: RootView shows OnboardingView
    → If session: RootView shows MainTabViewV2
Sign in with Apple → SignInWithAppleCoordinator → AuthService → JWT stored in Keychain
```

---

## Tests

Located in `ResumeBuilder IOS APPTests/`:
- `OptimizedResumeViewModelTests.swift`
- `ImproveViewModelTests.swift`
- `ResumeOptimizationParsingTests.swift`
- `ResumeOptimizationServiceSwiftTestingTests.swift`

Uses `MockResumeServices.swift` for dependency injection. No live API calls in tests.

Run tests:
```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

---

## Design System

All tokens are in `Core/DesignSystem/Tokens/`. Use them for all new UI:
- Colors: `AppColors.*`
- Spacing: `AppSpacing.*`
- Typography: `AppTypography.*`
- Shadows: `AppShadows.*`
- Radii: `AppRadii.*`
- Gradients: `AppGradients.*`

The app runs in **dark mode only** (`.preferredColorScheme(.dark)` in the root).
