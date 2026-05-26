import SwiftUI

struct ExpertModesView: View {
    @Environment(AppState.self) private var appState
    @Bindable var vm: ExpertModesViewModel
    @State private var evidenceEditorMode: ExpertWorkflowType?

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
        .task(id: vm.applicationId) {
            await vm.loadSavedReports(token: token)
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

    private var content: some View {
        ScrollView {
            if !vm.savedReports.isEmpty {
                savedReportsSection
            }
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(ExpertWorkflowType.allCases) { mode in
                    ExpertModeTile(
                        mode: mode,
                        phase: vm.phase(for: mode),
                        applying: vm.applyingWorkflow == mode,
                        evidenceText: vm.evidenceText(for: mode),
                        submittedEvidence: vm.submittedEvidenceByType[mode] ?? "",
                        selectedVariantIndex: vm.selectedVariantIndex(for: mode),
                        onEditEvidence: {
                            evidenceEditorMode = mode
                        },
                        onRun: {
                            Task { await vm.run(mode, token: token) }
                        },
                        onApply: {
                            Task { await vm.apply(mode, token: token, appState: appState) }
                        },
                        onSelectVariantIndex: { index in
                            vm.setSelectedVariantIndex(index, for: mode)
                        }
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
        .sheet(item: $evidenceEditorMode) { mode in
            evidenceEditor(mode)
        }
    }

    private var savedReportsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Saved Reports")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)

            ForEach(vm.savedReports) { report in
                NavigationLink {
                    ExpertSavedReportDetailView(
                        vm: vm,
                        reportId: report.id,
                        workflowTypeRaw: report.workflowType
                    )
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.reportTitle ?? report.workflowType ?? "Saved Report")
                                .font(.appSubheadline)
                                .foregroundStyle(AppColors.textPrimary)
                            if let savedAt = report.savedAt {
                                Text(relativeDate(from: savedAt))
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(AppSpacing.md)
                    .glassCard(cornerRadius: AppRadii.md)
                    .padding(.horizontal, AppSpacing.lg)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func relativeDate(from iso: String) -> String {
        let parsers: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        for p in parsers {
            if let d = p.date(from: iso) {
                let rf = RelativeDateTimeFormatter()
                rf.unitsStyle = .abbreviated
                return rf.localizedString(for: d, relativeTo: Date())
            }
        }
        return iso
    }

    private func evidenceEditor(_ mode: ExpertWorkflowType) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(mode.displayTitle)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(mode.requiredInputHint ?? "Add concrete achievements, metrics, constraints, or preferences for this expert pass.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                TextEditor(
                    text: Binding(
                        get: { vm.evidenceText(for: mode) },
                        set: { vm.setEvidenceText($0, for: mode) }
                    )
                )
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.sm)
                .frame(minHeight: 180)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.md))
                Spacer()
            }
            .padding(AppSpacing.lg)
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Expert Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { evidenceEditorMode = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ExpertModeTile: View {
    let mode: ExpertWorkflowType
    let phase: ExpertCardPhase
    let applying: Bool
    let evidenceText: String
    let submittedEvidence: String
    let selectedVariantIndex: Int?
    var onEditEvidence: () -> Void
    var onRun: () -> Void
    var onApply: () -> Void
    var onSelectVariantIndex: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: mode.symbolName)
                    .font(.title2)
                    .foregroundStyle(AppColors.accentViolet)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(mode.displayTitle)
                            .font(.appSubheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer(minLength: 0)
                        ExpertResumeBadge(changesResume: mode.changesResume)
                    }
                    Text(mode.purposeText)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                onEditEvidence()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: evidenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "plus.circle" : "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                    Text(evidenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add Expert Input" : "Edit Expert Input")
                        .font(.appCaption.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(AppColors.accentSky)
                .padding(AppSpacing.sm)
                .background(AppColors.accentSky.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadii.sm))
            }
            .buttonStyle(.plain)

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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run \(state.runId)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                    if !submittedEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Input saved for this run", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColors.accentTeal)
                    }
                }

                ExpertModeTileOutputView(
                    mode: mode,
                    state: state,
                    applying: applying,
                    selectedVariantIndex: selectedVariantIndex,
                    onSelectVariantIndex: onSelectVariantIndex,
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

private struct ExpertResumeBadge: View {
    let changesResume: Bool

    var body: some View {
        Text(changesResume ? "Changes resume" : "Application asset")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(changesResume ? AppColors.accentViolet : AppColors.accentSky)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (changesResume ? AppColors.accentViolet : AppColors.accentSky).opacity(0.10),
                in: Capsule()
            )
    }
}

private struct ExpertModeTileOutputView: View {
    let mode: ExpertWorkflowType
    let state: ExpertRunUIState
    let applying: Bool
    let selectedVariantIndex: Int?
    var onSelectVariantIndex: (Int) -> Void
    var onApply: () -> Void

    var body: some View {
        let parsed = state.parsedOutput
        switch mode {
        case .fullResumeRewrite:
            fallbackReportView(state: state, buttonTitle: "Apply Changes")
        case .achievementQuantifier:
            if !parsed.bulletRewrites.isEmpty {
                ExpertBulletRewritesView(rewrites: parsed.bulletRewrites, applying: applying, onApply: onApply)
            } else {
                fallbackReportView(state: state, buttonTitle: "Apply Changes")
            }
        case .atsOptimizationReport:
            if let atsReport = parsed.atsReport {
                ExpertATSReportView(atsReport: atsReport, applying: applying, onApply: onApply)
            } else {
                fallbackReportView(state: state, buttonTitle: "Add Keywords to Skills")
            }
        case .professionalSummaryLab:
            if !parsed.summaryOptions.isEmpty {
                ExpertSummaryOptionsView(
                    options: parsed.summaryOptions,
                    recommendedIndex: parsed.recommendedIndex,
                    selectedIndex: selectedVariantIndex,
                    applying: applying,
                    onSelect: onSelectVariantIndex,
                    onApply: onApply
                )
            } else {
                fallbackReportView(state: state, buttonTitle: "Apply Selected Summary")
            }
        case .coverLetterArchitect:
            if !parsed.coverLetterVariants.isEmpty {
                ExpertCoverLetterView(
                    variants: parsed.coverLetterVariants,
                    selectedIndex: selectedVariantIndex,
                    applying: applying,
                    onSelect: onSelectVariantIndex,
                    onApply: onApply
                )
            } else {
                fallbackReportView(state: state, buttonTitle: "Save Cover Letter")
            }
        case .screeningAnswerStudio:
            if !parsed.screeningAnswers.isEmpty {
                ExpertScreeningAnswersView(answers: parsed.screeningAnswers, applying: applying, onApply: onApply)
            } else {
                fallbackReportView(state: state, buttonTitle: "Save Answers")
            }
        }
    }

    @ViewBuilder
    private func fallbackReportView(state: ExpertRunUIState, buttonTitle: String) -> some View {
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
            applyButtonTitle: buttonTitle,
            onApply: onApply
        )
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
