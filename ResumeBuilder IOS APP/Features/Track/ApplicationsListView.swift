import SwiftUI

struct ApplicationsListView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ApplicationsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.optimizations.isEmpty && viewModel.applications.isEmpty {
                    // ── Empty state ───────────────────────────────────────────
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.textTertiary)
                        Text("No applications yet")
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Tailor your resume to a job to start tracking.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List {
                        if !viewModel.optimizations.isEmpty {
                            Section {
                                ForEach(viewModel.optimizations) { optimization in
                                    NavigationLink {
                                        OptimizationDetailView(optimization: optimization)
                                    } label: {
                                        TrackRowView(
                                            title: optimization.jobTitle ?? "Optimized resume",
                                            subtitle: optimization.company ?? "Saved optimization",
                                            score: optimization.matchScore,
                                            icon: "wand.and.stars"
                                        )
                                    }
                                }
                            } header: {
                                SectionHeader("Optimized Resumes")
                            }
                        }

                        if !viewModel.applications.isEmpty {
                            Section {
                                ForEach(viewModel.applications) { app in
                                    NavigationLink {
                                        ApplicationDetailView(application: app)
                                    } label: {
                                        TrackRowView(
                                            title: app.jobTitle ?? "Untitled role",
                                            subtitle: app.companyName ?? "Unknown company",
                                            score: app.atsScore,
                                            icon: "briefcase"
                                        )
                                    }
                                }
                            } header: {
                                SectionHeader("Applications")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.bgPrimary)
                }
            }
            .navigationTitle("Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.load(token: appState.session?.accessToken)
            }
            .refreshable {
                await viewModel.load(token: appState.session?.accessToken)
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Sub-views

private struct TrackRowView: View {
    let title: String
    let subtitle: String
    let score: Int?
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Theme.accent.opacity(0.15)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if let score {
                Text("\(score)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(scoreColor(score))
                    .background(scoreColor(score).opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return Theme.accentCyan
        case 60...: return Theme.accentBlue
        default: return Theme.accent
        }
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textTertiary)
            .textCase(nil)
    }
}
