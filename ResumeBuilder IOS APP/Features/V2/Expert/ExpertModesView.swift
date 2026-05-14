import SwiftUI

struct ExpertModesView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: ExpertModesViewModel

    private var token: String? { appState.session?.accessToken }

    private var optimizationReady: Bool {
        !vm.optimizationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if optimizationReady {
                content
            } else {
                ContentUnavailableView(
                    "Expert analysis unavailable",
                    systemImage: "rectangle.stack.badge.person.crop",
                    description: Text("Return after running Optimize to unlock expert workflows.")
                )
                .foregroundStyle(AppColors.textPrimary)
            }
        }
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Expert Analysis")
        .navigationBarTitleDisplayMode(.inline)
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

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(ExpertWorkflowType.allCases) { mode in
                    ExpertModeTile(
                        mode: mode,
                        phase: vm.phase(for: mode),
                        applying: vm.applyingWorkflow == mode,
                        onRun: {
                            Task {
                                await vm.run(mode, token: token)
                                if case .failed = vm.phase(for: mode) {} else {}
                            }
                        },
                        onApply: {
                            Task { await vm.apply(mode, token: token, appState: appState) }
                        }
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}

private struct ExpertModeTile: View {
    let mode: ExpertWorkflowType
    let phase: ExpertCardPhase
    let applying: Bool
    var onRun: () -> Void
    var onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: mode.symbolName)
                    .font(.title2)
                    .foregroundStyle(AppColors.accentViolet)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayTitle)
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(mode.cardDescription)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            GradientButton(title: primaryButtonTitle, isLoading: phase == .running || applying) {
                guard phase != .running, !applying else { return }
                onRun()
            }
            .disabled(phase == .running)

            if phase == .running {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Analyzing…")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if case .failed(let message) = phase {
                Text(message)
                    .font(.appCaption)
                    .foregroundStyle(.red)
            }

            if case .ready(let state) = phase {
                let report = state.report
                    ?? ExpertReportDisplayModel(
                        headline: mode.displayTitle,
                        executiveSummary: "Run completed — review output on web for full fidelity if needed.",
                        priorityActions: [],
                        evidenceGaps: state.missingEvidence,
                        atsImpact: nil
                    )

                ExpertReportView(
                    report: report,
                    executiveSummaryVisible: true,
                    missingEvidence: state.missingEvidence,
                    needsUserInput: state.needsUserInput,
                    showApplyButton: true,
                    isApplying: applying,
                    onApply: onApply
                )
            }
        }
        .padding(AppSpacing.md)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var primaryButtonTitle: String {
        switch phase {
        case .idle:
            return "Run"
        case .running:
            return "Running"
        case .ready:
            return "Run Again"
        case .failed:
            return "Retry"
        }
    }
}

#Preview {
    let vm = ExpertModesViewModel(
        optimizationId: "opt-prev",
        resumeViewModel: OptimizedResumeViewModel(
            optimizationId: "opt-prev",
            sections: [],
            optimizationService: MockResumeOptimizationService()
        )
    )
    NavigationStack {
        ExpertModesView(vm: vm)
    }
    .environment(AppState())
}
