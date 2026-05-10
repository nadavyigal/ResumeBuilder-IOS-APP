# iOS Optimization Detail — Phases 3, 5 & 6

Branch: `feat/ios-optimization-detail-phases-356`  
Depends on: `feat/ios-optimization-detail-phases-124` (merged or cherry-picked)

---

## Context

Phases 1, 2, and 4 shipped on `feat/ios-optimization-detail-phases-124`:
- Phase 1: After `OptimizationReviewView.apply()` succeeds, navigate to `OptimizedResumeView`
- Phase 2: ATS before/after score header with job title/company
- Phase 4: Download PDF (share sheet) + Copy Text (clipboard toast)

Three gaps remain to reach web-app parity:

| Phase | What's missing |
|-------|---------------|
| 3 | `OptimizedResumeView` sections are empty when opened from the review-apply path (no section data in apply response) |
| 5 | "Preview PDF" button in bottom bar is wired but has no navigation destination |
| 6 | Design template picker is a separate standalone flow; it's not accessible from `OptimizedResumeView` |

---

## Phase 3 — Fetch Optimization Sections from Backend

### Problem
`OptimizationReviewApplyResponseDTO` returns only `optimizationId`. When Phase 1 navigates to
`OptimizedResumeView(viewModel: OptimizedResumeViewModel(optimizationId: optId, ...))`,
`sections` is an empty array. The view shows the ATS header but no resume content.

### Solution
Add a backend `GET /api/v1/optimizations/[id]` route that returns the optimization's resume
sections (converted from `rewrite_data`) plus job context and ATS scores. Then add
`loadSections(token:)` to `OptimizedResumeViewModel` and call it on appear when sections
is empty.

### Backend — new file: `src/app/api/v1/optimizations/[id]/route.ts`

**Response shape:**
```json
{
  "sections": [
    { "id": "s_summary", "type": "summary", "body": "...", "status": "optimized" },
    { "id": "s_experience", "type": "experience", "body": "...", "status": "optimized" },
    { "id": "s_skills", "type": "skills", "body": "...", "status": "optimized" },
    { "id": "s_education", "type": "education", "body": "...", "status": "optimized" }
  ],
  "jobTitle": "Senior iOS Engineer",
  "company": "Apple",
  "atsScoreBefore": 54,
  "atsScoreAfter": 82
}
```

**Implementation sketch:**
```ts
// GET /api/v1/optimizations/[id]
const { data: row } = await supabase
  .from("optimizations")
  .select("rewrite_data, ats_score_original, ats_score_optimized, jd_id")
  .eq("id", id).eq("user_id", user.id).maybeSingle();

const { data: jd } = await supabase
  .from("job_descriptions")
  .select("title, company")
  .eq("id", row.jd_id).maybeSingle();

// Convert rewrite_data → sections array using same mapping as OptimizedResumeSection
const sections = rewriteDataToSections(row.rewrite_data);
return NextResponse.json({ sections, jobTitle: jd.title, company: jd.company,
  atsScoreBefore: row.ats_score_original, atsScoreAfter: row.ats_score_optimized });
```

The `rewriteDataToSections` helper maps the Supabase `rewrite_data` JSON shape to the same
`OptimizedResumeSection[]` format that `POST /api/optimize` already returns.

### iOS changes

**1. `Core/API/Endpoints.swift`** — add case:
```swift
case optimizationDetail(id: String)
// path: "/api/v1/optimizations/\(id)"
```

**2. `Core/API/Models/DomainModels.swift`** — add DTO:
```swift
struct OptimizationDetailDTO: Decodable, Sendable {
    let sections: [OptimizedResumeSection]
    let jobTitle: String?
    let company: String?
    let atsScoreBefore: Int?
    let atsScoreAfter: Int?
}
```

**3. `ViewModels/OptimizedResumeViewModel.swift`** — add method:
```swift
func loadSections(token: String?) async {
    guard sections.isEmpty, let optId = optimizationId, let token else { return }
    do {
        let detail: OptimizationDetailDTO = try await APIClient().get(
            endpoint: .optimizationDetail(id: optId), token: token
        )
        sections      = detail.sections
        jobTitle      = detail.jobTitle ?? jobTitle
        company       = detail.company  ?? company
        atsScoreBefore = detail.atsScoreBefore ?? atsScoreBefore
        atsScoreAfter  = detail.atsScoreAfter  ?? atsScoreAfter
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**4. `Features/V2/Improve/OptimizedResumeView.swift`** — call in `.task`:
```swift
.task {
    await viewModel.loadSections(token: appState.session?.accessToken)
}
```

Add a loading state (ProgressView) while sections are empty and `loadSections` is in-flight.
Gate the section cards on `!viewModel.sections.isEmpty` with a `ProgressView` fallback.

### Test
- Add `OptimizedResumeViewModelTests.swift`
- `testLoadSectionsPopulatesModel`: create VM with empty sections, call `loadSections(token:)`,
  assert sections count > 0, assert jobTitle set

---

## Phase 5 — Resume Preview via WKWebView

### Problem
`OptimizedResumeView.bottomBar` has a "Preview PDF" button that sets `navigateToPreview = true`,
but there is no `.navigationDestination(isPresented: $navigateToPreview)` wired up.

### Solution
Add a new `ResumePreviewWebView` that:
1. Calls `POST /api/v1/design/render-preview` to get HTML (using existing `ResumeDesignService.renderPreview`)
2. Loads the returned HTML in a `WKWebView`
3. Offers a share/export action from the rendered view

### New file: `Features/V2/Preview/ResumePreviewWebView.swift`

```swift
import SwiftUI
import WebKit

struct ResumePreviewWebView: View {
    @Environment(AppState.self) private var appState
    let optimizationId: String

    @State private var html: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSharePDF = false
    @State private var pdfURL: URL?

    private let designService: any ResumeDesignServiceProtocol = ResumeDesignService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Rendering preview…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let html {
                WebKitView(html: html)
                    .ignoresSafeArea(edges: .bottom)
            } else if let error = errorMessage {
                Text(error).foregroundStyle(.red).padding()
            }
        }
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Trigger PDF download + share (reuse Phase 4 logic)
                    Task { await downloadAndShare() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await renderPreview()
        }
        .sheet(isPresented: $showSharePDF, onDismiss: { pdfURL = nil }) {
            if let url = pdfURL { ShareSheet(items: [url]).ignoresSafeArea() }
        }
    }

    private func renderPreview() async {
        guard let token = appState.session?.accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Use default template when no design is assigned
            let request = RenderPreviewRequest(
                optimizationId: optimizationId,
                templateId: "ats-clean",           // default slug
                customization: .default
            )
            let response = try await designService.renderPreview(request, token: token)
            if let previewHTML = response.previewHTML {
                html = previewHTML
            } else {
                errorMessage = response.error ?? "Preview unavailable"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func downloadAndShare() async {
        guard let token = appState.session?.accessToken else { return }
        // Reuse OptimizedResumeViewModel.downloadPDF logic inline or extract to a helper
        // ...
    }
}

struct WebKitView: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: BackendConfig.apiBaseURL)
    }
}
```

### Wire into `OptimizedResumeView`

Add `.navigationDestination(isPresented: $navigateToPreview)` in the existing modifier chain:
```swift
.navigationDestination(isPresented: $navigateToPreview) {
    if let optId = viewModel.optimizationIdentifier {
        ResumePreviewWebView(optimizationId: optId)
    }
}
```

The button is already in `bottomBar`; no button changes needed.

### Design loading (no assigned template)
`renderPreview` needs a `templateId`. Add `GET /api/v1/design/{id}` call (already mapped as
`Endpoint.designRenderPreview` on POST side; we need the GET side) to check for an assigned
template slug first, falling back to `"ats-clean"` if none is set.

Alternatively: the render-preview API can accept `templateId: null` / omit it and server
uses the user's current assignment. Check backend behavior; if supported, simplify iOS call.

---

## Phase 6 — Design Template Picker Sheet in OptimizedResumeView

### Problem
Template selection lives in the separate standalone `RedesignResumeView` tab. The web app
exposes "Change Design" directly on the optimization detail page. On iOS, users must leave
the optimization view to change templates.

### Solution
Add a design sheet triggered from `OptimizedResumeView` that embeds the template strip,
category picker, and style controls in a half-sheet (`.presentationDetents([.medium, .large])`).

### New file: `Features/V2/Improve/OptimizationDesignSheet.swift`

```swift
import SwiftUI

struct OptimizationDesignSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @Bindable var designVM: DesignViewModel

    private let categories = [("ats_safe","ATS Safe"),("modern","Modern"),("creative","Creative")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    categoryPicker
                    if designVM.isLoading {
                        ProgressView().tint(AppColors.accentViolet).frame(height: 80)
                    } else {
                        templateStrip
                    }
                    styleControls
                    GradientButton(title: "Apply Design", icon: "paintbrush.fill",
                                   isLoading: designVM.isApplying) {
                        Task {
                            let ok = await designVM.applyDesign(token: appState.session?.accessToken)
                            if ok { isPresented = false }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    if let err = designVM.errorMessage {
                        Text(err).font(.appCaption).foregroundStyle(.red)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .task {
                await designVM.loadTemplates(token: appState.session?.accessToken)
                await designVM.loadStyleHistory(token: appState.session?.accessToken)
            }
            .onChange(of: designVM.activeCategory) { _, _ in
                Task { await designVM.loadTemplates(token: appState.session?.accessToken) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // Reuse category picker, template strip, and style controls verbatim from RedesignResumeView
    // (extract them to private helpers identical to the existing RedesignResumeView subviews)
}
```

### Wire into `OptimizedResumeView`

**State additions:**
```swift
@State private var showDesignSheet = false
@State private var designVM: DesignViewModel? = nil
```

**Bottom bar — add "Design" button alongside "Preview PDF":**
```swift
Button {
    if designVM == nil, let optId = viewModel.optimizationIdentifier {
        designVM = DesignViewModel(optimizationId: optId)
    }
    showDesignSheet = true
} label: {
    Label("Design", systemImage: "paintbrush")
        .font(.appSubheadline)
        .foregroundStyle(AppColors.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 50)
        .glassCard(cornerRadius: AppRadii.md)
}
.buttonStyle(GradientButtonStyle())
.disabled(viewModel.optimizationIdentifier == nil)
```

**Sheet modifier:**
```swift
.sheet(isPresented: $showDesignSheet) {
    if let vm = designVM {
        OptimizationDesignSheet(isPresented: $showDesignSheet, designVM: vm)
    }
}
```

**After apply succeeds** (in `OptimizationDesignSheet`): trigger a preview refresh.
If Phase 5 is live, this can re-render the WKWebView. Otherwise a toast suffices.

---

## File Change Summary

| Phase | Files added | Files modified |
|-------|-------------|---------------|
| 3 | `src/app/api/v1/optimizations/[id]/route.ts` (backend)<br>`ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests.swift` | `Core/API/Endpoints.swift`<br>`Core/API/Models/DomainModels.swift`<br>`ViewModels/OptimizedResumeViewModel.swift`<br>`Features/V2/Improve/OptimizedResumeView.swift` |
| 5 | `Features/V2/Preview/ResumePreviewWebView.swift` | `Features/V2/Improve/OptimizedResumeView.swift` |
| 6 | `Features/V2/Improve/OptimizationDesignSheet.swift` | `Features/V2/Improve/OptimizedResumeView.swift` |

---

## Implementation Order

1. **Phase 3 first** — without sections, the view is empty. Everything else depends on content being present.
2. **Phase 5** — independent of Phase 6; wire the existing "Preview PDF" button.
3. **Phase 6** — independent of Phase 5; add the design sheet.

Phases 5 and 6 can be implemented in parallel if desired.

---

## Open Questions

1. Does `POST /api/v1/design/render-preview` accept a null/missing `templateId` and fall back
   to the user's current assignment? If yes, simplify Phase 5 — no need for a pre-fetch of
   the design assignment.
2. Should the design sheet in Phase 6 also show an inline HTML preview (reusing Phase 5's
   `WebKitView`) so the user can see their template change live before applying? This is what
   the web app does with `DesignRenderer`, but would add significant complexity.
3. After the design is applied in Phase 6, should `OptimizedResumeView` re-render anything?
   Currently sections are plain text and won't change. Consider a light "Design applied" toast.
