import SwiftUI

struct ApplicationsListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ApplicationsViewModel

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.optimizations.isEmpty {
                    Section("Optimized Resumes") {
                        ForEach(viewModel.optimizations) { optimization in
                            NavigationLink {
                                OptimizationDetailView(optimization: optimization)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(optimization.jobTitle ?? "Optimized resume")
                                        .font(.headline)
                                    Text(optimization.company ?? "Saved optimization")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Applications") {
                    ForEach(viewModel.applications) { app in
                        NavigationLink {
                            ApplicationDetailView(application: app)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.jobTitle ?? "Untitled role")
                                    .font(.headline)
                                Text(app.companyName ?? "Unknown company")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
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
                if let errorMessage = viewModel.errorMessage {
                    ToolbarItem(placement: .bottomBar) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
