import SwiftUI
import StoreKit
import UIKit

struct OptimizedResumeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.requestReview) private var requestReview
    @Bindable var viewModel: OptimizedResumeViewModel
    var isActive = true
    var onSwitchTab: (ResumlyTab) -> Void = { _ in }

    /// ATS headline percent for export "share score" copy (from Improve analysis).
    var atsScorePercent: Int? = nil

    @State private var showRefineSheet = false
    @State private var refineInstruction = ""
    @State private var editingSectionId: String? = nil
    @State private var isManualEditMode = false
    @State private var manualEditTextBySection: [String: String] = [:]
    @State private var manualEditError: String? = nil
    @State private var showDiscardManualEditConfirmation = false
    @State private var submitVM: SubmitApplicationViewModel? = nil
    @State private var showSubmitPackageSheet = false
    @State private var navigateToModifications = false

    // Download & copy
    @State private var isDownloadingPDF = false
    @State private var pdfTempURL: URL? = nil
    @State private var showPDFShare = false
    @State private var pendingReviewOptimizationId: String? = nil
    @State private var showCopyConfirmation = false
    @State private var showExportSuccess = false
    @State private var optimizedViewedIds: Set<String> = []
    @State private var exportCTASeenIds: Set<String> = []
    @State private var previewActivationPolicy = PreviewActivationPolicy()
    @State private var savePromptViewedIds: Set<String> = []

    // Target-reached celebration + save-account handoff (fires on a real
    // ATS score crossing the target band, never a fabricated value).
    @State private var showTargetReached = false
    @State private var showSaveAccount = false
    @State private var showSaveAccountOnboarding = false
    @State private var targetReachedPreviousScore: Int? = nil
    @State private var didShowTargetReached = false
    private let targetReachedThreshold = 80

    // Design VM for preview fidelity (passes current template + customization to preview)
    @State private var designVM: DesignViewModel? = nil
    // Updated by the preview web view after each render-preview call.
    // Passed to the export action so the PDF matches the displayed design template.
    @State private var renderedPreviewHTML: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // ATS score card (shown when before/after data is available)
                if viewModel.atsScoreBefore != nil || viewModel.atsScoreAfter != nil {
                    atsScoreCard
                        .padding(.top, AppSpacing.xl)
                        .padding(.horizontal, AppSpacing.lg)
                }

                // The resume is the primary deliverable. Keep it ahead of the
                // supporting ATS/diagnosis panels so opening this tab never looks
                // like the optimized document is missing on a phone-sized screen.
                if let optId = viewModel.optimizationIdentifier {
                    if viewModel.hasVisibleAppliedChanges {
                        Label("Applied changes are ready to preview", systemImage: "checkmark.seal.fill")
                            .font(.appSubheadline.weight(.semibold))
                            .foregroundStyle(AppColors.accentTeal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    ResumePreviewWebView(
                        optimizationId: optId,
                        sections: viewModel.sections,
                        contact: viewModel.contact,
                        templateId: designVM?.selectedTemplateId,
                        customization: designVM?.customization,
                        isActive: isActive,
                        renderedHTML: $renderedPreviewHTML,
                        onVisibleRender: { displayedHTML in
                            if let optimizationId = previewActivationPolicy.consumeVisibleRender(
                                optimizationId: viewModel.optimizationIdentifier,
                                renderedHTML: displayedHTML,
                                isActive: isActive
                            ) {
                                AnalyticsService.shared.track(
                                    .optimizedPreviewRendered(optimizationId: optimizationId)
                                )
                            }
                        }
                    )
                    .aspectRatio(8.5 / 11, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadii.lg))
                    .padding(.horizontal, AppSpacing.lg)
                    .accessibilityIdentifier("optimized-resume-preview")

                    savedResumePanel
                        .padding(.horizontal, AppSpacing.lg)
                } else if viewModel.isLoadingSections || viewModel.isAwaitingInitialSections {
                    ProgressView("Loading resume…")
                        .tint(AppColors.accentViolet)
                        .padding(.top, AppSpacing.xl)
                }

                if shouldShowATSInsightPanel {
                    atsInsightPanel
                        .padding(.horizontal, AppSpacing.lg)
                }

                if shouldShowDiagnosisPanels {
                    diagnosisSnapshotPanel
                        .padding(.horizontal, AppSpacing.lg)
                }

                // Improvement tools follow the primary preview and supporting evidence.
                if viewModel.optimizationIdentifier != nil {
                    improveActionsRow
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, viewModel.atsScoreBefore == nil && viewModel.atsScoreAfter == nil ? AppSpacing.xl : 0)
                }

                if viewModel.optimizationIdentifier != nil {
                    atsUpliftPanel
                        .padding(.horizontal, AppSpacing.lg)

                    if shouldShowDiagnosisPanels {
                        ResumeConfidenceChecklist(items: viewModel.resumeDiagnosis.confidenceChecklist)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, AppSpacing.lg)
                }

                Spacer(minLength: 120)
            }
        }
        .scrollIndicators(.hidden)
        .task {
            if let optId = viewModel.optimizationIdentifier, designVM == nil {
                designVM = DesignViewModel(optimizationId: optId)
            }
            let currentDesignVM = designVM
            async let sectionLoad: Void = viewModel.loadSections(appState: appState)
            async let assignmentLoad: Void = currentDesignVM?.loadCurrentAssignment(token: appState.session?.accessToken) ?? ()
            await sectionLoad
            await assignmentLoad
            viewModel.restoreSavedResumeState(appState: appState)
        }
        .onChange(of: appState.resumePreviewRefreshToken) { _, _ in
            Task {
                await viewModel.forceReloadSections(appState: appState)
                await designVM?.loadCurrentAssignment(token: appState.session?.accessToken)
            }
        }
        .onChange(of: viewModel.optimizationIdentifier) { _, newId in
            renderedPreviewHTML = nil
            pdfTempURL = nil
            showPDFShare = false
            showExportSuccess = appState.isExportComplete(for: newId)
            viewModel.restoreSavedResumeState(appState: appState)
            if let newId {
                designVM = DesignViewModel(optimizationId: newId)
                Task { await designVM?.loadCurrentAssignment(token: appState.session?.accessToken) }
            } else {
                designVM = nil
            }
        }
        .onChange(of: viewModel.atsScoreAfter) { oldValue, newValue in
            // A nil oldValue means this is the initial load (including viewing an
            // already-optimized resume from history), not a real improvement —
            // never treat that as a crossing, or re-opening a high-scoring resume
            // would fire a fake celebration.
            guard !didShowTargetReached,
                  let oldValue,
                  let newValue,
                  oldValue < targetReachedThreshold,
                  newValue >= targetReachedThreshold
            else { return }
            targetReachedPreviousScore = oldValue
            didShowTargetReached = true
            showTargetReached = true
        }
        .fullScreenCover(isPresented: $showTargetReached) {
            TargetReachedView(
                score: viewModel.atsScoreAfter ?? targetReachedThreshold,
                previousScore: targetReachedPreviousScore,
                onOpenDesign: {
                    showTargetReached = false
                    onSwitchTab(.design)
                },
                onSaveProgress: {
                    showTargetReached = false
                    showSaveAccount = true
                }
            )
        }
        .sheet(isPresented: $showSaveAccount) {
            SaveAccountSheetView(
                score: viewModel.atsScoreAfter ?? targetReachedThreshold,
                onContinueWithApple: {
                    showSaveAccount = false
                    showSaveAccountOnboarding = true
                },
                onMaybeLater: {
                    showSaveAccount = false
                }
            )
        }
        .sheet(isPresented: $showSaveAccountOnboarding) {
            NavigationStack {
                OnboardingView(viewModel: OnboardingViewModel(appState: appState))
            }
        }
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Optimized Resume")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        navigateToModifications = true
                    } label: {
                        Label("Modification History", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(viewModel.optimizationIdentifier == nil)

                    Divider()

                    Button {
                        UIPasteboard.general.string = viewModel.plainTextResume
                        showCopyConfirmation = true
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                    .disabled(viewModel.sections.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .onAppear {
            showExportSuccess = appState.isExportComplete(for: viewModel.optimizationIdentifier)
            trackOptimizedAndExportVisibilityIfNeeded()
        }
        .task(id: isActive) {
            guard isActive else { return }
            trackOptimizedAndExportVisibilityIfNeeded()
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            trackOptimizedAndExportVisibilityIfNeeded()
        }
        .onChange(of: viewModel.optimizationIdentifier) { _, _ in
            trackOptimizedAndExportVisibilityIfNeeded()
        }
        .task(id: "\(viewModel.optimizationIdentifier ?? "none"):\(isActive)") {
            trackSavePromptVisibilityIfNeeded()
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showRefineSheet) {
            refineSheet
        }
        .sheet(isPresented: $showSubmitPackageSheet) {
            if let submitVM {
                SubmitApplicationSheet(
                    vm: submitVM,
                    accessToken: appState.session?.accessToken
                )
            }
        }
        .sheet(isPresented: $isManualEditMode) {
            manualEditSheet
        }
        .sheet(isPresented: $showPDFShare, onDismiss: handlePDFShareDismissed) {
            if let url = pdfTempURL {
                ShareSheet(items: [url])
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .top) {
            if showCopyConfirmation {
                Label("Copied to clipboard", systemImage: "checkmark.circle.fill")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accentTeal, in: Capsule())
                    .padding(.top, AppSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopyConfirmation = false }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCopyConfirmation)
        .navigationDestination(isPresented: $navigateToModifications) {
            if let optId = viewModel.optimizationIdentifier {
                ModificationHistoryView(
                    viewModel: ModificationHistoryViewModel(optimizationId: optId)
                )
            } else {
                Text("Optimization not available.")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    // MARK: - ATS score card (unchanged)

    private var shouldShowATSInsightPanel: Bool {
        viewModel.optimizationIdentifier != nil
            && (viewModel.atsScoreBefore != nil || viewModel.atsScoreAfter != nil || !viewModel.atsBlockers.isEmpty)
    }

    private var shouldShowDiagnosisPanels: Bool {
        viewModel.optimizationIdentifier != nil
            && !viewModel.isAwaitingInitialSections
            && !viewModel.isLoadingSections
    }

    private var atsScoreCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let title = viewModel.jobTitle {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "briefcase.fill")
                        .imageScale(.small)
                        .foregroundStyle(AppColors.accentTeal)
                    Text(title)
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                    if let co = viewModel.company {
                        Text("· \(co)")
                            .font(.appSubheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            HStack(spacing: AppSpacing.lg) {
                if let before = viewModel.atsScoreBefore {
                    VStack(spacing: 2) {
                        Text("Before")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("\(before)%")
                            .font(.appHeadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Image(systemName: "arrow.forward")
                        .foregroundStyle(AppColors.textTertiary)
                        .imageScale(.small)
                }
                if let after = viewModel.atsScoreAfter {
                    VStack(spacing: 2) {
                        Text("After")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("\(after)%")
                            .font(.appHeadline)
                            .foregroundStyle(AppColors.accentTeal)
                    }
                    if let before = viewModel.atsScoreBefore, after > before {
                        Label("+\(after - before)pts", systemImage: "arrow.up.circle.fill")
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(AppColors.accentTeal)
                    }
                }
                Spacer()
            }
            Text("Based on formatting + keyword match vs the job you paste. Not affiliated with any ATS vendor.")
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var atsInsightPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Match insights")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.accentTeal)
                    Text("See what's blocking this resume")
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(viewModel.atsStatusDescription)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.sm)

                VStack(spacing: 2) {
                    Text("\(viewModel.currentATSScore)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(atsStatusColor)
                    Text("/ 100")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(minWidth: 88)
                .padding(.vertical, AppSpacing.sm)
                .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
            }

            if let delta = viewModel.atsScoreDelta {
                HStack(spacing: AppSpacing.md) {
                    scoreDeltaTile(title: "Before", value: viewModel.atsScoreBefore)
                    Image(systemName: "arrow.forward")
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accentSky)
                    scoreDeltaTile(title: "Optimized", value: viewModel.atsScoreAfter)
                    Spacer(minLength: 0)
                    Text(delta >= 0 ? "+\(delta) pts" : "\(delta) pts")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(delta >= 0 ? AppColors.accentTeal : AppColors.accentViolet)
                }
            }

            if let explanation = viewModel.atsLowScoreExplanation {
                Label(explanation, systemImage: "exclamationmark.triangle.fill")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.accentSky)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.md)
                    .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Score signals")
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(AppColors.textTertiary)
                ForEach(viewModel.atsInsightRows) { row in
                    atsInsightRow(row)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Top blockers")
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(AppColors.textTertiary)
                ForEach(Array(viewModel.atsRecommendedActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Circle()
                            .fill(AppColors.accentTeal)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                        Text(action)
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !viewModel.keywordSuggestions.isEmpty {
                addableKeywordsSection
            }

            Button {
                AnalyticsService.shared.track(.atsImproveTapped(currentScore: viewModel.currentATSScore))
                Task { await viewModel.improveATS(token: appState.session?.accessToken, appState: appState) }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if viewModel.isImprovingATS {
                        ProgressView()
                            .tint(AppColors.textPrimary)
                    } else {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                    }
                    Text(viewModel.isImprovingATS ? "Improving match…" : "Improve match")
                }
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(viewModel.isImprovingATS)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func scoreDeltaTile(title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.textTertiary)
            Text(value.map { "\($0)" } ?? "--")
                .font(.appHeadline)
                .foregroundStyle(title == "Optimized" ? AppColors.accentTeal : AppColors.textPrimary)
        }
        .frame(width: 92, alignment: .leading)
        .padding(AppSpacing.md)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                .stroke(title == "Optimized" ? AppColors.accentTeal.opacity(0.45) : AppColors.glassStroke, lineWidth: 1)
        }
    }

    private func atsInsightRow(_ row: ATSInsightRow) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(row.title)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(row.score)")
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(atsSignalColor(score: row.score))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.glassStroke)
                    Capsule()
                        .fill(atsSignalColor(score: row.score))
                        .frame(width: proxy.size.width * CGFloat(row.score) / 100)
                }
            }
            .frame(height: 8)

            Text(row.reason)
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.vertical, 2)
    }

    private var addableKeywordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Addable keywords")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.textTertiary)
            Text("These appear in the job description but not your resume. Review the proposed wording before adding it.")
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(viewModel.keywordSuggestions) { blocker in
                keywordSuggestionRow(blocker)
            }
        }
    }

    private func keywordSuggestionRow(_ blocker: ATSOptimizationBlocker) -> some View {
        let suggestionId = blocker.id
        let isApproved = viewModel.keywordsApproved.contains(suggestionId)
        let isPreviewing = viewModel.keywordsBeingPreviewed.contains(suggestionId)
        let isApproving = viewModel.keywordsBeingApproved.contains(suggestionId)
        let preview = viewModel.keywordPreviews[suggestionId]
        let error = viewModel.keywordPreviewErrors[suggestionId]

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(blocker.title)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = blocker.detail, detail != blocker.title {
                        Text(detail)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: AppSpacing.sm)

                if isApproved {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.accentTeal)
                } else if preview == nil {
                    Button {
                        Task { await viewModel.previewKeyword(suggestionId: suggestionId, token: appState.session?.accessToken) }
                    } label: {
                        if isPreviewing {
                            ProgressView()
                        } else {
                            Text("Preview")
                                .font(.appCaption.weight(.semibold))
                        }
                    }
                    .disabled(isPreviewing)
                }
            }

            if let preview, !isApproved {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(Array(preview.enumerated()), id: \.offset) { _, field in
                        if let newValue = field.newValue {
                            Text(describeAffectedFieldChange(field, newValue: newValue))
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Button {
                            Task { await viewModel.approveKeyword(suggestionId: suggestionId, token: appState.session?.accessToken) }
                        } label: {
                            if isApproving {
                                ProgressView()
                            } else {
                                Text("Approve")
                                    .font(.appCaption.weight(.bold))
                            }
                        }
                        .disabled(isApproving)
                        .buttonStyle(GradientButtonStyle())

                        Button("Reject") {
                            viewModel.rejectKeyword(suggestionId: suggestionId)
                        }
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(.top, AppSpacing.xs)
            }

            if let error {
                Text(error)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.accentSky)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func describeAffectedFieldChange(_ field: ChatAffectedField, newValue: JSONValue) -> String {
        "Proposed: \(newValue.displayString)"
    }

    private var diagnosisSnapshotPanel: some View {
        let diagnosis = viewModel.resumeDiagnosis
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Resume diagnosis")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.accentTeal)
                    Text(diagnosis.recruiterReview.impression)
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.sm)

                VStack(spacing: 0) {
                    Text("\(diagnosis.matchScore)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.accentTeal)
                    Text("% match")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            if !diagnosis.topGaps.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(diagnosis.topGaps.prefix(2)) { gap in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Circle()
                                .fill(AppColors.accentSky)
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gap.title)
                                    .font(.appCaption.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(gap.explanation)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }

            Text(diagnosis.scoreNote)
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    // MARK: - New bottom bar

    private var bottomBar: some View {
        VStack(spacing: AppSpacing.sm) {
            if showExportSuccess || appState.isExportComplete(for: viewModel.optimizationIdentifier) {
                exportSuccessActions
            }

            GradientButton(
                title: "Preview & Export PDF",
                icon: "arrow.down.doc.fill",
                isLoading: isDownloadingPDF
            ) {
                Task { await performExport() }
            }
            .disabled(viewModel.optimizationIdentifier == nil || isDownloadingPDF)

            Button {
                openSubmitPackage()
            } label: {
                Label("Submit Package", systemImage: "paperplane.fill")
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .glassCard(cornerRadius: AppRadii.md)
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(viewModel.optimizationIdentifier == nil || viewModel.sections.isEmpty)
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial.opacity(0.8))
    }

    private var savedResumePanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            switch viewModel.savedResumeState {
            case .idle:
                Text("Keep this optimized resume in Saved Resumes so you can reuse it later.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                Button {
                    Task { await viewModel.saveOptimizedResume(appState: appState) }
                } label: {
                    Label("Save to My Resumes", systemImage: "bookmark.fill")
                        .font(.appSubheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(!viewModel.hasVisibleAppliedChanges)
            case .saving:
                HStack(spacing: AppSpacing.sm) {
                    ProgressView().tint(AppColors.accentViolet)
                    Text("Saving resume…")
                        .font(.appSubheadline.weight(.semibold))
                }
            case .saved(let resume):
                Label(resume.displayName ?? resume.filename, systemImage: "checkmark.circle.fill")
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accentTeal)
                Text("Saved in My Resumes")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
            case .failed(let message):
                Text(message)
                    .font(.appCaption)
                    .foregroundStyle(.red)
                Button("Try Save Again") {
                    Task { await viewModel.saveOptimizedResume(appState: appState) }
                }
                .font(.appSubheadline.weight(.semibold))
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var improveActionsRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Improve further")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.leading, AppSpacing.xs)

            HStack(spacing: AppSpacing.md) {
                improveButton(title: "Refine", icon: "wand.and.stars") {
                    editingSectionId = heuristicSectionId
                    refineInstruction = ""
                    showRefineSheet = true
                }
                .disabled(viewModel.sections.isEmpty || viewModel.optimizationIdentifier == nil)

                improveButton(title: isManualEditMode ? "Done" : "Edit", icon: isManualEditMode ? "checkmark.circle" : "square.and.pencil") {
                    openManualEditor()
                }
                .disabled(viewModel.sections.isEmpty || viewModel.optimizationIdentifier == nil || viewModel.isSaving)

                improveButton(title: "Design", icon: "paintbrush") {
                    onSwitchTab(.design)
                }
                .disabled(viewModel.optimizationIdentifier == nil)

                improveButton(title: "Expert", icon: "rectangle.stack.badge.person.crop") {
                    onSwitchTab(.expert)
                }
                .disabled(viewModel.optimizationIdentifier == nil)
            }
        }
    }

    private func improveButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .glassCard(cornerRadius: AppRadii.md)
        }
        .buttonStyle(GradientButtonStyle())
    }

    private var atsUpliftPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Match")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                    HStack(spacing: AppSpacing.sm) {
                        Text(viewModel.atsStatusLabel)
                            .font(.appHeadline)
                            .foregroundStyle(atsStatusColor)
                        if let before = viewModel.atsScoreBefore, let after = viewModel.atsScoreAfter {
                            Text("\(before)% → \(after)%")
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    Text(viewModel.atsStatusDescription)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    AnalyticsService.shared.track(.atsImproveTapped(currentScore: viewModel.currentATSScore))
                    Task { await viewModel.improveATS(token: appState.session?.accessToken, appState: appState) }
                } label: {
                    if viewModel.isImprovingATS {
                        ProgressView()
                            .tint(AppColors.accentTeal)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.accentTeal)
                            .frame(width: 40, height: 40)
                            .glassCard(cornerRadius: AppRadii.md)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isImprovingATS)
            }

            if !viewModel.atsBlockers.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(viewModel.atsBlockers.prefix(3)) { blocker in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .imageScale(.small)
                                .foregroundStyle(AppColors.accentSky)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(blocker.title)
                                    .font(.appCaption.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                if let action = blocker.suggestedAction ?? blocker.detail {
                                    Text(action)
                                        .font(.appCaption)
                                        .foregroundStyle(AppColors.textTertiary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            if let gain = blocker.estimatedGain {
                                Text("+\(gain)")
                                    .font(.appCaption.weight(.bold))
                                    .foregroundStyle(AppColors.accentTeal)
                            }
                        }
                    }
                }
            }

            if let message = viewModel.atsUpliftMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.accentTeal)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var atsStatusColor: Color {
        switch viewModel.atsStatusLabel {
        case "High": return AppColors.accentTeal
        case "Strong": return AppColors.accentSky
        case "Medium": return AppColors.accentCyan
        default: return AppColors.accentViolet
        }
    }

    private func atsSignalColor(score: Int) -> Color {
        if score >= 80 { return AppColors.accentTeal }
        if score >= 70 { return AppColors.accentSky }
        if score >= 55 { return AppColors.accentCyan }
        return AppColors.accentViolet
    }

    private var manualEditSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                manualSectionSelector

                if let section = selectedManualSection {
                    focusedManualEditor(section)
                } else {
                    ContentUnavailableView("No section selected", systemImage: "doc.text")
                        .foregroundStyle(AppColors.textSecondary)
                }

                if let manualEditError {
                    Text(manualEditError)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Edit Resume")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(selectedManualSection.map(hasPendingManualEdit(for:)) ?? false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        closeManualEditorRespectingDirtyState()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
            .confirmationDialog(
                "Discard unsaved edit?",
                isPresented: $showDiscardManualEditConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    if let section = selectedManualSection {
                        manualEditTextBySection[section.id] = section.body
                    }
                    isManualEditMode = false
                }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    private var manualSectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.sections) { section in
                    Button {
                        editingSectionId = section.id
                        manualEditError = nil
                    } label: {
                        Text(section.type.displayName)
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(editingSectionId == section.id ? .black : AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.md)
                            .frame(height: 36)
                            .background(
                                editingSectionId == section.id ? AppColors.accentTeal : .clear,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(AppColors.glassStroke, lineWidth: editingSectionId == section.id ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func focusedManualEditor(_ section: OptimizedResumeSection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.type.displayName)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Edit only facts you can verify. Save refreshes the preview and Match Score.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                    .fill(.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                            .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                    )

                TextEditor(text: manualEditBinding(for: section))
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.sm)
                    .frame(minHeight: max(220, editorHeight(for: section.body)))
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    manualEditTextBySection[section.id] = section.body
                    manualEditError = nil
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.appCaption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(viewModel.isSaving || !hasPendingManualEdit(for: section))

                Button {
                    Task { await saveManualEdit(section) }
                } label: {
                    Label(viewModel.isSaving ? "Saving" : "Save", systemImage: "checkmark")
                        .font(.appCaption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(viewModel.isSaving || !hasPendingManualEdit(for: section))
            }
        }
    }

    private var selectedManualSection: OptimizedResumeSection? {
        if let editingSectionId,
           let selected = viewModel.sections.first(where: { $0.id == editingSectionId }) {
            return selected
        }
        return viewModel.sections.first
    }

    private func manualEditBinding(for section: OptimizedResumeSection) -> Binding<String> {
        Binding(
            get: { manualEditTextBySection[section.id] ?? section.body },
            set: { manualEditTextBySection[section.id] = $0 }
        )
    }

    private func editorHeight(for text: String) -> CGFloat {
        let lineCount = max(4, min(12, text.components(separatedBy: .newlines).count + 2))
        return CGFloat(lineCount * 24)
    }

    private func hasPendingManualEdit(for section: OptimizedResumeSection) -> Bool {
        let current = manualEditTextBySection[section.id] ?? section.body
        return current != section.body
    }

    private func openManualEditor() {
        manualEditTextBySection = Dictionary(uniqueKeysWithValues: viewModel.sections.map { ($0.id, $0.body) })
        editingSectionId = heuristicSectionId ?? viewModel.sections.first?.id
        manualEditError = nil
        isManualEditMode = true
    }

    private func closeManualEditorRespectingDirtyState() {
        if let section = selectedManualSection, hasPendingManualEdit(for: section) {
            showDiscardManualEditConfirmation = true
        } else {
            isManualEditMode = false
        }
    }

    @MainActor
    private func saveManualEdit(_ section: OptimizedResumeSection) async {
        let text = manualEditTextBySection[section.id] ?? section.body
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            manualEditError = "Section text cannot be empty."
            return
        }
        manualEditError = nil
        await viewModel.saveManualEdit(sectionId: section.id, newText: text, token: appState.session?.accessToken)
        guard viewModel.errorMessage == nil else { return }
        manualEditTextBySection[section.id] = text
        renderedPreviewHTML = nil
        await viewModel.rescanATS(token: appState.session?.accessToken)
    }

    private func openSubmitPackage() {
        submitVM = SubmitApplicationViewModel(resumeProvider: viewModel)
        showSubmitPackageSheet = true
    }

    private var exportSuccessActions: some View {
        VStack(spacing: AppSpacing.sm) {
            Label("PDF exported successfully", systemImage: "checkmark.circle.fill")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.accentTeal)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppSpacing.md) {
                Button {
                    Task { await performExport() }
                } label: {
                    Label("Share again", systemImage: "square.and.arrow.up")
                        .font(.appCaption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())

                Button {
                    guard let optimizationId = viewModel.optimizationIdentifier else { return }
                    appState.requestSecondJob(from: optimizationId)
                    AnalyticsService.shared.track(.secondJobStarted)
                    onSwitchTab(.tailor)
                } label: {
                    Label("Optimize for another job", systemImage: "plus.circle")
                        .font(.appCaption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
    }

    @MainActor
    private func performExport() async {
        guard !isDownloadingPDF,
              let optimizationId = viewModel.optimizationIdentifier else { return }
        AnalyticsService.shared.track(.exportPdfTapped(optimizationId: optimizationId))
        isDownloadingPDF = true
        viewModel.errorMessage = nil
        defer { isDownloadingPDF = false }
        do {
            let result = try await ResumeExportAction.exportPDF(
                viewModel: viewModel,
                appState: appState,
                renderedHTML: renderedPreviewHTML
            )
            pdfTempURL = result.fileURL
            pendingReviewOptimizationId = result.optimizationId
            showPDFShare = true
            showExportSuccess = true
        } catch {
            if case .serverError(_, let message)? = error as? APIClientError {
                viewModel.errorMessage = message
            } else {
                viewModel.errorMessage = String(format: NSLocalizedString("PDF export failed: %@", comment: ""), error.localizedDescription)
            }
        }
    }

    @MainActor
    private func handlePDFShareDismissed() {
        pdfTempURL = nil
        defer { pendingReviewOptimizationId = nil }

        guard let optimizationId = pendingReviewOptimizationId,
              appState.isExportComplete(for: optimizationId)
        else {
            return
        }

        let gate = ReviewPromptGate()
        guard gate.claimAfterSuccessfulExport(hasCompletedExport: true) else { return }

        AnalyticsService.shared.track(.appStoreReviewRequested(source: "export_success"))
        requestReview()
    }

    private func trackOptimizedAndExportVisibilityIfNeeded() {
        guard isActive, let optimizationId = viewModel.optimizationIdentifier else { return }
        if optimizedViewedIds.insert(optimizationId).inserted {
            AnalyticsService.shared.track(.optimizedViewed(optimizationId: optimizationId))
        }
        if exportCTASeenIds.insert(optimizationId).inserted {
            AnalyticsService.shared.track(.exportCTASeen(optimizationId: optimizationId))
        }
    }

    private func trackSavePromptVisibilityIfNeeded() {
        guard isActive,
              let optimizationId = viewModel.optimizationIdentifier,
              savePromptViewedIds.insert(optimizationId).inserted else { return }
        AnalyticsService.shared.track(.savedResumePromptViewed(optimizationId: optimizationId))
    }

    // MARK: - Refine sheet

    /// Picks the best target section for a whole-resume refine.
    private var heuristicSectionId: String? {
        viewModel.sections.first(where: { $0.type == .summary })?.id
            ?? viewModel.sections.first(where: { $0.type == .experience })?.id
            ?? viewModel.sections.first?.id
    }

    @ViewBuilder
    private var refineSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Refinement Instruction")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                            )

                        if refineInstruction.isEmpty {
                            Text("e.g. Make it more concise and add leadership examples…")
                                .font(.appBody)
                                .foregroundStyle(AppColors.textTertiary)
                                .padding(AppSpacing.lg)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $refineInstruction)
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(AppSpacing.md)
                            .frame(minHeight: 120)
                    }
                }

                if let pending = viewModel.pendingRefine {
                    BulletDiffRow(
                        original: pending.original,
                        optimized: pending.suggested,
                        onAccept: {
                            Task {
                                if let sid = editingSectionId {
                                    await viewModel.acceptRefine(sectionId: sid, acceptedText: pending.suggested, token: appState.session?.accessToken)
                                    showRefineSheet = false
                                }
                            }
                        },
                        onReject: {
                            viewModel.rejectRefine()
                        }
                    )
                }

                if viewModel.pendingRefine == nil {
                    GradientButton(
                        title: "Refine Resume",
                        icon: "wand.and.stars",
                        isLoading: viewModel.isRefining
                    ) {
                        Task {
                            if let sid = editingSectionId {
                                await viewModel.refineSection(sectionId: sid, instruction: refineInstruction, token: appState.session?.accessToken)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(AppSpacing.lg)
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Refine Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.rejectRefine()
                        showRefineSheet = false
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

private struct SubmitApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var vm: SubmitApplicationViewModel
    let accessToken: String?

    @State private var showCopiedCoverLetter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let package = vm.package {
                        packageView(package)
                    } else {
                        formView
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Submit Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .overlay(alignment: .top) {
                if showCopiedCoverLetter {
                    Label("Cover letter copied", systemImage: "checkmark.circle.fill")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.accentTeal, in: Capsule())
                        .padding(.top, AppSpacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCopiedCoverLetter = false }
                            }
                        }
                }
            }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            internalPackageNotice

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Role")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                TextField("Job title", text: $vm.jobTitle)
                    .textInputAutocapitalization(.words)
                    .submitPackageField()
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Company")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                TextField("Company name", text: $vm.companyName)
                    .textInputAutocapitalization(.words)
                    .submitPackageField()
            }

            if let missingContextMessage = vm.missingContextMessage {
                Label(missingContextMessage, systemImage: "info.circle.fill")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Job Link")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                TextField("LinkedIn or job post URL", text: $vm.sourceURLString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitPackageField()
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Cover Letter Notes")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                        .fill(.black.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                                .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                        )
                    if vm.coverLetterContext.isEmpty {
                        Text("Optional details to mention")
                            .font(.appBody)
                            .foregroundStyle(AppColors.textTertiary)
                            .padding(AppSpacing.lg)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $vm.coverLetterContext)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(AppSpacing.md)
                        .frame(minHeight: 110)
                }
            }

            GradientButton(
                title: "Create Package",
                icon: "paperplane.fill",
                isLoading: vm.isSubmitting
            ) {
                Task {
                    await vm.submit(token: accessToken)
                }
            }
            .disabled(!vm.canSubmit)
        }
    }

    private func packageView(_ package: SubmitApplicationPackage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Label(
                package.application == nil ? "Package ready" : "Saved to Me",
                systemImage: package.application == nil ? "tray.full.fill" : "checkmark.circle.fill"
            )
                .font(.appHeadline)
                .foregroundStyle(AppColors.accentTeal)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(package.application?.jobTitle ?? package.jobTitle)
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(package.application?.companyName ?? package.companyName)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

            if package.application == nil {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("This is an internal tracking package. Saving it adds it to Me; it does not send anything to the recruiter.")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)

                    GradientButton(
                        title: "Save Package to Me",
                        icon: "tray.and.arrow.down.fill",
                        isLoading: vm.isSavingPackage
                    ) {
                        Task {
                            await vm.savePackageToMe(token: accessToken)
                            if let savedPackage = vm.package, savedPackage.application != nil {
                                appState.rememberSubmitPackage(
                                    for: savedPackage.optimizationId,
                                    sourceURLString: savedPackage.sourceURLString,
                                    coverLetterText: savedPackage.coverLetterText,
                                    screeningAnswers: savedPackage.screeningAnswers.map {
                                        SubmitPackageCachedScreeningAnswer(
                                            id: $0.id,
                                            question: $0.question,
                                            answer: $0.answer,
                                            evidenceUsed: $0.evidenceUsed,
                                            confidenceNote: $0.confidenceNote
                                        )
                                    }
                                )
                                appState.applicationsRefreshToken += 1
                            }
                        }
                    }
                    .disabled(vm.isSavingPackage)
                }
            } else {
                Label("Saved internally in Me. Nothing was sent automatically; you can share the resume, copy the cover letter, or open the job link when you are ready.", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            packageAssetsView(package)

            VStack(spacing: AppSpacing.sm) {
                ShareLink(item: package.resumePDFURL) {
                    Label("Share Resume PDF", systemImage: "square.and.arrow.up")
                        .font(.appSubheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())

                Button {
                    UIPasteboard.general.string = package.coverLetterText
                    withAnimation { showCopiedCoverLetter = true }
                } label: {
                    Label("Copy Cover Letter", systemImage: "doc.on.doc")
                        .font(.appSubheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())

                if let url = package.jobURL {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Submit at Job Link", systemImage: "safari")
                            .font(.appSubheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .glassCard(cornerRadius: AppRadii.md)
                    }
                    .buttonStyle(GradientButtonStyle())
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Cover Letter")
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(package.coverLetterText)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .textSelection(.enabled)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

            if !package.screeningAnswers.isEmpty {
                screeningAnswersView(package.screeningAnswers)
            }
        }
    }

    private var internalPackageNotice: some View {
        Label(
            "Internal package only. Nothing is sent to a recruiter from here. Use this to save, share, and track your application.",
            systemImage: "lock.shield.fill"
        )
        .font(.appCaption)
        .foregroundStyle(AppColors.textSecondary)
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
    }

    private func packageAssetsView(_ package: SubmitApplicationPackage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Package Contents")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Label("Resume PDF", systemImage: "doc.fill")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)

            Label("Cover Letter", systemImage: "doc.text.fill")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)

            if let url = package.jobURL {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Job Link", systemImage: "link")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(package.sourceURLString ?? url.absoluteString)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            } else {
                Label("No job link is attached yet. Add the job URL before saving so the package can track this application.", systemImage: "exclamationmark.triangle.fill")
                    .font(.appCaption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func screeningAnswersView(_ answers: [ExpertScreeningAnswer]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Screening Answers")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            ForEach(answers) { answer in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(answer.question)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(answer.answer)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textPrimary)
                        .textSelection(.enabled)
                    if let note = answer.confidenceNote {
                        Text(note)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}

private extension View {
    func submitPackageField() -> some View {
        self
            .font(.appBody)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: 48)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        OptimizedResumeView(
            viewModel: OptimizedResumeViewModel(
                optimizationId: "mock-opt-001",
                sections: [
                    OptimizedResumeSection(id: "s1", type: .summary, body: "Experienced engineer specializing in TypeScript and cloud infrastructure.", status: "optimized"),
                    OptimizedResumeSection(id: "s2", type: .experience, body: "Led migration of legacy system, cutting costs by 30%.", status: "improved"),
                ],
                optimizationService: MockResumeOptimizationService()
            )
        )
    }
    .environment(AppState())
}
