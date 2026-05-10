import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isAuthenticated {
                    signedOutState
                } else if viewModel.isLoading {
                    loadingState
                } else if viewModel.filteredOptimizations.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .searchable(text: $viewModel.searchText, prompt: "Search job title or company")
            .screenBackground(showRadialGlow: false)
            .task {
                await viewModel.load(token: appState.session?.accessToken)
            }
            .refreshable {
                await viewModel.load(token: appState.session?.accessToken)
            }
            .sheet(item: $viewModel.downloadedPDF) { pdf in
                HistoryShareSheet(activityItems: [pdf.url])
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.filteredOptimizations) { item in
                HistoryRow(
                    item: item,
                    isDownloading: viewModel.downloadingId == item.id
                ) {
                    Task {
                        await viewModel.downloadPDF(for: item, token: appState.session?.accessToken)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                Task {
                    await viewModel.deleteFilteredItems(at: offsets, token: appState.session?.accessToken)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
    }

    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.gradientMid)
            Text("Loading optimization history...")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppColors.gradientMid)

            Text(viewModel.searchText.isEmpty ? "No optimizations yet" : "No matching optimizations")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)

            Text(viewModel.searchText.isEmpty ? "Run a scan and optimization to see it here." : "Try another job title or company.")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var signedOutState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppColors.gradientMid)

            Text("Sign in to view history")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)

            Text("Your optimized resumes and PDF downloads are linked to your account.")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryRow: View {
    let item: OptimizationHistoryItem
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.jobTitle ?? "Optimized Resume")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    Text(item.company ?? "Company not specified")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text("\(item.matchScorePercent)%")
                    .font(.appCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 5)
                    .background(scoreColor, in: Capsule())
            }

            HStack {
                Label(item.formattedDate, systemImage: "calendar")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)

                Spacer()

                Button(action: onDownload) {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.down.doc.fill")
                        }
                        Text("Download PDF")
                    }
                    .font(.appCaption)
                    .foregroundStyle(AppColors.gradientMid)
                }
                .buttonStyle(.plain)
                .disabled(isDownloading)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.vertical, AppSpacing.xs)
    }

    private var scoreColor: Color {
        switch item.matchScorePercent {
        case 80...100: return AppColors.accentTeal
        case 60..<80: return AppColors.accentSky
        default: return .orange
        }
    }
}

private struct HistoryShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HistoryView(viewModel: HistoryViewModel(historyService: MockOptimizationHistoryService()))
        .environment(AppState())
}
