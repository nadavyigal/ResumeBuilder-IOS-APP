import SwiftUI
import UIKit

struct OptimizedResumeView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: OptimizedResumeViewModel
    var isActive = true
    var onSwitchTab: (ResumlyTab) -> Void = { _ in }

    /// ATS headline percent for export "share score" copy (from Improve analysis).
    var atsScorePercent: Int? = nil

    @State private var showRefineSheet = false
    @State private var refineInstruction = ""
    @State private var editingSectionId: String? = nil
    @State private var navigateToModifications = false

    // Download & copy
    @State private var isDownloadingPDF = false
    @State private var pdfTempURL: URL? = nil
    @State private var showPDFShare = false
    @State private var showCopyConfirmation = false
    @State private var showExportSuccess = false

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

                // Inline resume preview — the main content
                if let optId = viewModel.optimizationIdentifier {
                    ResumePreviewWebView(
                        optimizationId: optId,
                        sections: viewModel.sections,
                        contact: viewModel.contact,
                        templateId: designVM?.selectedTemplateId,
                        customization: designVM?.customization,
                        isActive: isActive,
                        renderedHTML: $renderedPreviewHTML
                    )
                    .aspectRatio(8.5 / 11, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadii.lg))
                    .padding(.top, viewModel.atsScoreBefore == nil && viewModel.atsScoreAfter == nil ? AppSpacing.xl : 0)
                    .padding(.horizontal, AppSpacing.lg)
                } else if viewModel.isLoadingSections || viewModel.isAwaitingInitialSections {
                    ProgressView("Loading resume…")
                        .tint(AppColors.accentViolet)
                        .padding(.top, AppSpacing.xl)
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
            if let newId {
                designVM = DesignViewModel(optimizationId: newId)
                Task { await designVM?.loadCurrentAssignment(token: appState.session?.accessToken) }
            } else {
                designVM = nil
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
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showRefineSheet) {
            refineSheet
        }
        .sheet(isPresented: $showPDFShare, onDismiss: { pdfTempURL = nil }) {
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
                    Image(systemName: "arrow.right")
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
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial.opacity(0.8))
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
                    onSwitchTab(.tailor)
                } label: {
                    Label("New job", systemImage: "plus.circle")
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
        guard !isDownloadingPDF else { return }
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
            showPDFShare = true
            showExportSuccess = true
        } catch {
            if case .serverError(_, let message)? = error as? APIClientError {
                viewModel.errorMessage = message
            } else {
                viewModel.errorMessage = "PDF export failed: \(error.localizedDescription)"
            }
        }
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
