import SwiftUI
import UIKit

struct OptimizedResumeView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: OptimizedResumeViewModel

    /// ATS headline percent for export “share score” copy (from Improve analysis).
    var atsScorePercent: Int? = nil

    @State private var showRefineSheet = false
    @State private var refineInstruction = ""
    @State private var editingSectionId: String? = nil
    @State private var navigateToChat = false
    @State private var navigateToExpert = false
    @State private var navigateToModifications = false
    @State private var showPreviewSheet = false

    // Phase 4 — download & copy
    @State private var isDownloadingPDF = false
    @State private var pdfTempURL: URL? = nil
    @State private var showPDFShare = false
    @State private var showCopyConfirmation = false

    // Phase 6 — design sheet
    @State private var showDesignSheet = false
    @State private var designVM: DesignViewModel? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // ATS score card (shown when before/after data is available)
                if viewModel.atsScoreBefore != nil || viewModel.atsScoreAfter != nil {
                    atsScoreCard
                        .padding(.top, AppSpacing.xl)
                        .padding(.horizontal, AppSpacing.lg)
                }

                // Header badge
                headerBadge
                    .padding(.top, viewModel.atsScoreBefore == nil && viewModel.atsScoreAfter == nil ? AppSpacing.xl : 0)
                    .padding(.horizontal, AppSpacing.lg)

                // Section cards (or loading placeholder while fetching)
                if viewModel.isLoadingSections {
                    ProgressView("Loading resume…")
                        .tint(AppColors.accentViolet)
                        .padding(.top, AppSpacing.xl)
                } else {
                    ForEach(viewModel.sections) { section in
                        ResumeSectionCard(
                            icon: section.type.icon,
                            title: section.type.displayName,
                            content: section.body,
                            status: section.sectionStatus
                        ) {
                            editingSectionId = section.id
                            refineInstruction = ""
                            showRefineSheet = true
                        }
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
            await viewModel.loadSections(appState: appState)
            if let optId = viewModel.optimizationIdentifier, designVM == nil {
                designVM = DesignViewModel(optimizationId: optId)
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
                        Task {
                            guard !isDownloadingPDF else { return }
                            isDownloadingPDF = true
                            viewModel.errorMessage = nil
                            do {
                                pdfTempURL = try await viewModel.downloadPDF(appState: appState)
                                showPDFShare = true
                            } catch {
                                viewModel.errorMessage = "PDF download failed: \(error.localizedDescription)"
                            }
                            isDownloadingPDF = false
                        }
                    } label: {
                        if isDownloadingPDF {
                            Label("Downloading…", systemImage: "arrow.down.circle")
                        } else {
                            Label("Download PDF", systemImage: "arrow.down.doc.fill")
                        }
                    }
                    .disabled(viewModel.optimizationIdentifier == nil || isDownloadingPDF)

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
        .navigationDestination(isPresented: $navigateToChat) {
            ChatView(resumeViewModel: viewModel)
        }
        .navigationDestination(isPresented: $navigateToExpert) {
            ExpertModesView(
                optimizationId: viewModel.optimizationIdentifier ?? "",
                resumeViewModel: viewModel
            )
        }
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
        .navigationDestination(isPresented: $showPreviewSheet) {
            if let optId = viewModel.optimizationIdentifier {
                ResumePreviewWebView(
                    optimizationId: optId,
                    sections: viewModel.sections,
                    templateId: designVM?.selectedTemplateId,
                    customization: designVM?.customization
                )
            } else {
                Text("Preview not available.")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .sheet(isPresented: $showDesignSheet) {
            if let vm = designVM {
                OptimizationDesignSheet(isPresented: $showDesignSheet, designVM: vm)
                    .environment(appState)
            }
        }
    }

    // MARK: - Subviews

    private var atsScoreCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Job context row
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

            // ATS before → after row
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

    private var headerBadge: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppColors.accentViolet)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Optimized")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Tap any section to refine with custom instructions")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var bottomBar: some View {
        VStack(spacing: AppSpacing.sm) {
            GradientButton(
                title: "Chat with AI",
                icon: "bubble.left.and.bubble.right.fill"
            ) {
                navigateToChat = true
            }
            .disabled(viewModel.optimizationIdentifier == nil)

            Button {
                navigateToExpert = true
            } label: {
                Label("Expert Analysis", systemImage: "rectangle.stack.badge.person.crop")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .glassCard(cornerRadius: AppRadii.md)
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(viewModel.optimizationIdentifier == nil)

            HStack(spacing: AppSpacing.md) {
                Button {
                    showPreviewSheet = true
                } label: {
                    Label("Preview", systemImage: "doc.richtext")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(viewModel.optimizationIdentifier == nil)

                Button {
                    if let optId = viewModel.optimizationIdentifier,
                       designVM?.optimizationId != optId {
                        designVM = DesignViewModel(optimizationId: optId)
                    }
                    showDesignSheet = true
                } label: {
                    Label("Design", systemImage: "paintbrush")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(viewModel.optimizationIdentifier == nil)
            }
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial.opacity(0.8))
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
                        title: "Refine Section",
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
            .navigationTitle("Edit Section")
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
