import SwiftUI

/// Picks an optimization from History to attach via `attach-optimized`.
struct OptimizeAttachmentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var historyViewModel = HistoryViewModel()

    let accessToken: String?
    let onSelect: (OptimizationHistoryItem) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if historyViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if historyViewModel.filteredOptimizations.isEmpty {
                    ContentUnavailableView(
                        "No optimizations",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Run Optimize first to attach a version here.")
                    )
                } else {
                    List(historyViewModel.filteredOptimizations) { row in
                        Button {
                            onSelect(row)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.jobTitle ?? "Optimized Resume")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                                HStack {
                                    Text(row.company ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(row.formattedDate)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Text("\(row.matchScorePercent)% match")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accentViolet)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Attach resume")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $historyViewModel.searchText, prompt: "Search title or company")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await historyViewModel.load(token: accessToken)
            }
        }
    }
}
