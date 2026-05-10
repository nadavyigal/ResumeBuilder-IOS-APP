import SwiftUI

@Observable
@MainActor
final class ModificationHistoryViewModel {
    let optimizationId: String

    var modifications: [ContentModificationDTO] = []
    var isLoading = false
    var revertingId: String?
    var errorMessage: String?
    var infoMessage: String?

    private let api = APIClient()

    init(optimizationId: String) {
        self.optimizationId = optimizationId
    }

    func load(token: String?) async {
        guard let token else {
            errorMessage = "Sign in to view modification history."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let env: ModificationHistoryEnvelope = try await api.getWithQuery(
                endpoint: .modificationHistory(optimizationId: optimizationId),
                token: token
            )
            modifications = env.modifications
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revert(id: String, token: String?) async {
        guard let token else { return }
        revertingId = id
        errorMessage = nil
        infoMessage = nil
        defer { revertingId = nil }
        do {
            let _: ModificationRevertResponseDTO = try await api.postJSON(
                endpoint: .modificationRevert(id: id),
                body: [:],
                token: token
            )
            infoMessage = "Reverted on the server. Close and reopen this resume to refresh section text."
            await load(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ModificationHistoryView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ModificationHistoryViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.modifications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.modifications.isEmpty {
                ContentUnavailableView(
                    "No modifications yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Edits from refine, chat, and expert tools will appear here.")
                )
            } else {
                List {
                    ForEach(viewModel.modifications) { row in
                        modificationRow(row)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Modification History")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground(showRadialGlow: false)
        .task {
            await viewModel.load(token: appState.session?.accessToken)
        }
        .ifLetMessage(viewModel.infoMessage) { base, msg in
            base.overlay(alignment: .bottom) {
                Text(msg)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.accentTeal)
                    .padding(AppSpacing.lg)
            }
        }
    }

    private func modificationRow(_ row: ContentModificationDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(row.fieldPath ?? "Field")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if let created = row.createdAt {
                    Text(shortDate(created))
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            if let op = row.operationType {
                Text(op)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack {
                Button {
                    Task {
                        await viewModel.revert(id: row.id, token: appState.session?.accessToken)
                    }
                } label: {
                    if viewModel.revertingId == row.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Revert")
                    }
                }
                .font(.appCaption)
                .foregroundStyle(AppColors.gradientMid)
                .disabled(viewModel.revertingId != nil)

                Spacer()
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.vertical, AppSpacing.xs)
    }

    private func shortDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }
}

private extension View {
    @ViewBuilder
    func ifLetMessage(_ message: String?, transform: (Self, String) -> some View) -> some View {
        if let message {
            transform(self, message)
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        ModificationHistoryView(
            viewModel: ModificationHistoryViewModel(optimizationId: "opt-1")
        )
    }
    .environment(AppState())
}
