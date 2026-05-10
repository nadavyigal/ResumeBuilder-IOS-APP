import SwiftUI

private struct ApplicationComparePair: Identifiable {
    let left: ApplicationItem
    let right: ApplicationItem
    var id: String { "\(left.id)—\(right.id)" }
}

struct ApplicationsListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ApplicationsViewModel

    @State private var selectionMode = false
    @State private var selectedIds = Set<String>()
    @State private var comparePair: ApplicationComparePair?

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(viewModel.applications) { app in
                        Group {
                            if selectionMode {
                                Button {
                                    toggleSelection(app.id)
                                } label: {
                                    selectionLabel(for: app)
                                }
                            } else {
                                NavigationLink {
                                    ApplicationDetailView(application: app)
                                } label: {
                                    applicationRow(app)
                                }
                            }
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.55)
                                .onEnded { _ in
                                    enterSelectionMode(selecting: app.id)
                                }
                        )
                    }
                }

                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Track")
            .task {
                await viewModel.load(token: appState.session?.accessToken)
            }
            .refreshable {
                await viewModel.load(token: appState.session?.accessToken)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectionMode {
                        Button("Cancel") {
                            selectionMode = false
                            selectedIds.removeAll()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectionMode {
                        Button("Compare") {
                            presentCompare()
                        }
                        .disabled(selectedIds.count != 2)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .sheet(item: $comparePair) { pair in
                ApplicationCompareView(left: pair.left, right: pair.right)
            }
        }
    }

    private func applicationRow(_ app: ApplicationItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.jobTitle ?? "Untitled role")
                .font(.headline)
            Text(app.companyName ?? "Unknown company")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func selectionLabel(for app: ApplicationItem) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: selectedIds.contains(app.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedIds.contains(app.id) ? AppColors.accentViolet : .secondary)
                .font(.title3)
            applicationRow(app)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func enterSelectionMode(selecting id: String) {
        selectionMode = true
        selectedIds = [id]
    }

    private func presentCompare() {
        let ids = Array(selectedIds)
        guard ids.count == 2,
              let one = viewModel.application(withId: ids[0]),
              let two = viewModel.application(withId: ids[1]) else { return }
        comparePair = ApplicationComparePair(left: one, right: two)
    }
}
