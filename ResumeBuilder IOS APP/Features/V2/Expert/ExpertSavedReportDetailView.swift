import SwiftUI

struct ExpertSavedReportDetailView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: ExpertModesViewModel

    let reportId: String
    let workflowTypeRaw: String?

    @State private var snapshot: ExpertWorkflowRunSnapshot? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private var token: String? { appState.session?.accessToken }

    private var workflowType: ExpertWorkflowType? {
        guard let raw = workflowTypeRaw else { return nil }
        return ExpertWorkflowType(rawValue: raw)
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading report…")
                    .tint(AppColors.accentViolet)
                    .padding(.top, AppSpacing.xxl)
                    .frame(maxWidth: .infinity)
            } else if let snap = snapshot {
                reportContent(snap)
            } else if let err = errorMessage {
                VStack(spacing: AppSpacing.md) {
                    Text(err)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    if let type = workflowType {
                        GradientButton(title: "Re-run \(type.displayTitle)") {
                            Task { await vm.run(type, token: token) }
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Saved Report")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReport()
        }
        .alert(
            "Expert modes",
            isPresented: Binding(
                get: { vm.toastMessage != nil },
                set: { if !$0 { vm.dismissToast() } }
            )
        ) {
            Button("OK") { vm.dismissToast() }
        } message: {
            Text(vm.toastMessage ?? "")
        }
    }

    @ViewBuilder
    private func reportContent(_ snap: ExpertWorkflowRunSnapshot) -> some View {
        let report = ExpertReportParsing.displayModel(from: snap.output)
            ?? ExpertReportDisplayModel(
                headline: workflowTypeRaw ?? "Saved Report",
                executiveSummary: "Report loaded — full fidelity may require re-run.",
                priorityActions: [],
                evidenceGaps: snap.missingEvidence,
                atsImpact: nil
            )

        ExpertReportView(
            report: report,
            executiveSummaryVisible: true,
            missingEvidence: snap.missingEvidence,
            needsUserInput: snap.status == "needs_user_input",
            showApplyButton: workflowType != nil,
            isApplying: workflowType.map { vm.applyingWorkflow == $0 } ?? false,
            onApply: {
                if let type = workflowType {
                    Task { await vm.apply(type, token: token, appState: appState) }
                }
            }
        )
        .padding(AppSpacing.lg)
    }

    private func loadReport() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snap = try await ExpertWorkflowService().getStatus(runId: reportId, token: token)
            self.snapshot = snap
            // Pre-seed the parent VM so apply() can find the .ready phase
            if let type = workflowType {
                vm.seedReadyPhase(workflowType: type, snapshot: snap)
            }
        } catch {
            errorMessage = "Could not load saved report: \(error.localizedDescription)"
        }
    }
}
