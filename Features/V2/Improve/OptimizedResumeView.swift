import SwiftUI

struct OptimizedResumeView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: OptimizedResumeViewModel

    @State private var showRefineSheet = false
    @State private var refineInstruction = ""
    @State private var editingSectionId: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Header badge
                headerBadge
                    .padding(.top, AppSpacing.xl)
                    .padding(.horizontal, AppSpacing.lg)

                // Section cards
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
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Optimized Resume")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showRefineSheet) {
            refineSheet
        }
    }

    // MARK: - Subviews

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
        HStack(spacing: AppSpacing.md) {
            Button {
                // Navigate to preview — handled by parent nav
            } label: {
                Label("Preview PDF", systemImage: "doc.richtext")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .glassCard(cornerRadius: AppRadii.md)
            }
            .buttonStyle(GradientButtonStyle())

            GradientButton(title: "Save Changes", isLoading: viewModel.isSaving) {
                // Saving is handled per-section via refine apply
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
