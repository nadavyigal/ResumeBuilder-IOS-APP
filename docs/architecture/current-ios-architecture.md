# Current iOS Architecture: ResumeBuilder iOS

**Last updated:** 2026-11-11 (rewritten from the code; the 2026-05-13 version described a tab shell that no longer exists)

---

## Tech Stack

| Item | Value |
|------|-------|
| Language | Swift 6.0, strict concurrency `complete`, default actor isolation `MainActor` |
| UI framework | SwiftUI |
| iOS target | iOS 17.0+ |
| Architecture | MVVM |
| State management | Swift Observation (`@Observable`, `@MainActor`) |
| Persistence | `UserDefaults` and Keychain only (no SwiftData) |
| Auth | Supabase GoTrue (email + password; Sign in with Apple behind `BackendConfig.isAppleSignInEnabled`), tokens in `KeychainStore` |
| Payments | StoreKit 2 export-credit packs (`Core/Payments/`), server-verified |
| Networking | `URLSession` via `APIClient` + `Endpoint` enum |
| Resume preview / PDF | `WKWebView` (`ResumePreviewWebView.swift`, `HTMLPDFExporter.swift`) |
| SPM packages | None, system frameworks only |
| Xcode project | File-system synchronized groups: any file in the app folder joins the target |

---

## Layer Map

```
ResumeBuilder_IOS_APPApp.swift   ← @main; DEBUG smoke harnesses via --smoke-* launch args
    └── ContentView.swift        ← --marketing-screenshot slots, else RootView
        └── RootView.swift       ← waits for session bootstrap
            └── MainTabViewV2.swift  (custom ResumlyTabBar, tabs kept alive with opacity)
                ├── .tailor    → HomeTabView      (Features/V2/Home/)   uses TailorViewModel
                ├── .optimized → OptimizedResumeTabView (Features/V2/Improve/)
                ├── .design    → DesignTabView    (Features/V2/Design/) uses DesignViewModel
                ├── .expert    → ExpertTabView    (Features/V2/Expert/)
                └── .me        → ProfileView      (Features/Profile/)
```

---

## Folders

| Path | What lives there |
|------|------------------|
| `App/` | `AppState` (session, credits, deep links), `MainTabViewV2`, `RootView`, `DeepLinkRouter` |
| `Features/V2/` | All current screens. New screens go here. |
| `Features/Profile/`, `Features/Track/`, `Features/Onboarding/`, `Features/Score/`, `Features/Tailor/` | Older folders still holding live code (`ProfileView`, `TailorViewModel`, `SavedResumePickerSheet`, application tracking, sign-in) |
| `ViewModels/` | Shared view models (`DesignViewModel`, `OptimizedResumeViewModel`, `ResumePreviewViewModel`, `ResumeLibraryViewModel`) |
| `Services/` | Network services and their protocols; `MockResumeServices.swift` holds preview/test mocks (compiled into Release too) |
| `Core/API/` | `APIClient`, `Endpoints`, `BackendConfig` (feature flags), domain models |
| `Core/Auth/`, `Core/Payments/`, `Core/Analytics/`, `Core/Export/`, `Core/Localization/` | Cross-cutting services |
| `Core/DesignSystem/` | `Theme`, tokens (`AppColors`, `AppSpacing`, `AppRadii`, `AppShadows`, `AppGradients`; `Font.app*` in `AppTypography.swift`), shared components |
| `Ambassador/` | Unwired skeleton (see `docs/audits/2026-11-11-repo-audit.md`) |

Not reachable from the tab shell today but still compiled because tests use them: `ImproveViewModel`, `ScanViewModel`, `ChatView` + `ChatViewModel`, `OptimizationDesignSheet` + `TemplateThumbnail`. The Fit-check screens in `Features/V2/Fit/` are wired into `HomeTabView` but switched off (`isFitCheckEnabled = false` since 2026-07-24).

---

## API Pattern

```
Endpoint enum (Endpoints.swift)
    → APIClient
        → Service (e.g. ResumeOptimizationService)
            → ViewModel (e.g. TailorViewModel)
                → View (e.g. HomeTabView)
```

The base URL comes from `API_BASE_URL` (build setting → `Config/Info.plist`). Keys come from the gitignored `Secrets.xcconfig` (template: `Secrets.xcconfig.template`).

---

## Tests

`ResumeBuilder IOS APPTests/` (XCTest + a few Swift Testing cases). No live API calls.

```bash
xcodebuild -project "ResumeBuilder IOS APP.xcodeproj" \
  -scheme "ResumeBuilder IOS APP" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

---

## Design System

Use the tokens in `Core/DesignSystem/Tokens/` and `Theme` for new UI. Fonts: the `Font.app*` tokens in `Tokens/AppTypography.swift`. The app runs in dark mode only (`.preferredColorScheme(.dark)` at the root).
