# SwiftUI Standards — ResumeBuilder iOS

## Core Pattern: @Observable ViewModel

```swift
@Observable
@MainActor
final class MyViewModel {
    var isLoading = false
    var errorMessage: String?
    
    private let service: MyService
    
    init(service: MyService = .init()) {
        self.service = service
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        // ...
    }
}
```

**Never use:** `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`
These are Combine-based and incompatible with the project's Swift Observation setup.

---

## View Structure

Views should be thin. Logic belongs in the ViewModel.

```swift
struct MyFeatureView: View {
    @State private var viewModel = MyViewModel()
    
    var body: some View {
        content
            .task { await viewModel.loadData() }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else {
            // main content
        }
    }
}
```

**Keep `body` short.** Extract sub-views or computed `@ViewBuilder` properties.

---

## Navigation

Use `NavigationStack`, not `NavigationView`:

```swift
NavigationStack {
    MyView()
        .navigationTitle("Title")
        .navigationBarTitleDisplayMode(.inline)
}
```

---

## Async in Views

Use `.task {}` for async work triggered on view appear:

```swift
.task {
    await viewModel.loadData()
}
```

Use `.task(id:)` to re-run when a value changes:

```swift
.task(id: selectedId) {
    await viewModel.load(id: selectedId)
}
```

Never use `DispatchQueue.main.async` in view code.

---

## State in Parent Container

VMs that must survive tab switching are instantiated at the parent level as `@State`:

```swift
// In MainTabViewV2.swift
@State private var scoreViewModel = ScoreViewModel()
```

This is intentional — it keeps VMs alive when tabs are hidden.

---

## Design Tokens

Always use tokens, never literal values:

```swift
// Correct
.foregroundStyle(AppColors.textPrimary)
.padding(AppSpacing.md)
.cornerRadius(AppRadii.card)
.font(AppTypography.body)

// Wrong
.foregroundStyle(.white)
.padding(16)
.cornerRadius(12)
```

---

## New Screens

All new screens go in `Features/V2/[FeatureName]/`. File naming convention:
- `MyFeatureView.swift` — the SwiftUI View
- `MyFeatureViewModel.swift` — the ViewModel (if not co-located with other VMs)

---

## Swift 6 Concurrency

- All ViewModels must be `@MainActor`
- All models (structs) crossing actor boundaries must be `Sendable`
- `final class` is easier to make `Sendable` than open classes
- Use `async/await` — never `completion handlers` for new code
- Avoid `Task.detached` unless absolutely necessary

---

## Loading, Empty, and Error States

Every screen that loads data must handle all three states:

```swift
var body: some View {
    Group {
        if viewModel.isLoading {
            ProgressView("Loading...")
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error, retry: { Task { await viewModel.load() } })
        } else if viewModel.items.isEmpty {
            EmptyStateView(message: "No items yet")
        } else {
            ListView(items: viewModel.items)
        }
    }
}
```
