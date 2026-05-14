# Technical Risks — ResumeBuilder iOS

**Last updated:** 2026-05-13

---

## Risk: Swift 6 Strict Concurrency

**Severity:** High
**Likelihood:** Common trap for agents unfamiliar with Swift 6

The project uses `SWIFT_VERSION = 6.0`. Strict concurrency is enforced at compile time. Common failures:
- Passing non-`Sendable` types across actor boundaries
- Using `ObservableObject`/`@Published` (requires `Combine`, inconsistent with `@Observable`)
- Missing `@MainActor` on ViewModels that update UI state
- Using `DispatchQueue.main.async` instead of `await MainActor.run` or `@MainActor` annotation

**Rule:** Every new class/struct that is shared across actors must be `Sendable`. Every ViewModel must be `@Observable @MainActor`. Use `async/await` throughout.

---

## Risk: Features/ vs Features/V2/ Coexistence

**Severity:** High
**Likelihood:** High — an agent not reading lessons will naturally extend the wrong folder

The repo has two feature folders:
- `Features/` — legacy screens (some still in use: Track, Onboarding, Score [partial], Profile [partial])
- `Features/V2/` — current active screens (all new work goes here)

**Rule:** All new screens and extensions go in `Features/V2/`. Never add files to top-level `Features/` unless fixing a bug in a screen not yet migrated.

---

## Risk: WKWebView PDF Rendering

**Severity:** Medium
**Likelihood:** Medium — works on simulator, may fail on real device or older hardware

`ResumePreviewWebView.swift` uses `WKWebView` to render resume previews and the PDF export. Known fragilities:
- Custom fonts may not load in WKWebView sandbox
- Hebrew text direction may not render correctly
- PDF page breaks can overflow on small iPhones
- Real device behavior differs from simulator for some web content

**Rule:** Always test PDF preview and export on a physical iPhone before TestFlight submission. iPhone SE viewport must be validated.

---

## Risk: Dark Mode Only

**Severity:** Low
**Likelihood:** Low — but easy to accidentally break if an agent adds light-mode colors

The app sets `.preferredColorScheme(.dark)` in `ResumeBuilder_IOS_APPApp.swift`. All design tokens in `AppColors` are calibrated for dark mode.

**Rule:** Never change the `preferredColorScheme`. Never add hardcoded `Color(.white)` or `Color(.black)` assuming light backgrounds.

---

## Risk: API_BASE_URL Hardcoding

**Severity:** Medium
**Likelihood:** Low — but high impact if done

The API base URL is set via the `API_BASE_URL` Info.plist key in Xcode build settings. This supports separate development, staging, and production environments.

**Rule:** Never reference a raw URL string for the backend API. Always use the `Endpoint` enum in `Core/API/Endpoints.swift`.

---

## Risk: No Swift Package Manager

**Severity:** Low
**Likelihood:** Medium — agents may try to add packages

This project has no `Package.swift` and no SPM dependencies. All imports are system frameworks (`SwiftUI`, `Foundation`, `WebKit`, `StoreKit`, `AuthenticationServices`, etc.).

**Rule:** Do not add any `import ThirdPartyLibrary` without first creating a Package.swift and getting explicit approval. Adding packages requires Xcode project file changes.

---

## Risk: TestFlight Signing

**Severity:** High
**Likelihood:** Common at submission time

The app requires:
- A valid Apple Developer team selected in signing settings
- Provisioning profile for `Resumebuilder-IOS.ResumeBuilder-IOS-APP`
- Sign in with Apple entitlement configured
- Push notification entitlement (if PushService is active)

**Rule:** Never change signing settings, bundle ID, or entitlements files without explicit approval. Check `ResumeBuilder_IOS_APP.entitlements` before any TestFlight prep.

---

## Risk: Hebrew / RTL Absence

**Severity:** Low (currently)
**Likelihood:** n/a — not yet in scope

No Hebrew or RTL code exists. The resume templates and PDF rendering have not been tested with Hebrew text. Implementing Hebrew support requires:
- RTL layout direction in SwiftUI views
- WKWebView CSS `direction: rtl` for PDF templates
- API support for Hebrew resume sections

**Rule:** Do not add Hebrew support unless it is an approved story. Flag it as a known gap, not a bug.

---

## Risk: V1 → Optimization Review Flow (plan-phases-3-5-6.md)

**Severity:** Medium
**Likelihood:** Current — this is the active in-progress work

Three phases remain incomplete:
- Phase 3: `OptimizedResumeView` shows empty sections after the review-apply path
- Phase 5: "Preview PDF" button has no navigation destination
- Phase 6: Design template picker not reachable from `OptimizedResumeView`

**Rule:** Before touching any optimization flow, read `plan-phases-3-5-6.md` in the root. These phases have detailed backend + iOS implementation specs.
