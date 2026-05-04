import SwiftUI

struct RedesignResumeView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: DesignViewModel
    var onPreview: (() -> Void)? = nil

    private let categories = [
        ("ats_safe", "ATS Safe"),
        ("modern",   "Modern"),
        ("creative", "Creative")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                GreetingHeader(name: "there", screenTitle: "Redesign")
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)

                // Category segmented control
                categoryPicker

                // Live preview card
                previewCard

                // Template strip
                if !viewModel.templates.isEmpty {
                    templateStrip
                }

                // Style controls
                styleControls

                // Apply CTA
                GradientButton(
                    title: "Apply Design",
                    icon: "paintbrush.fill",
                    isLoading: viewModel.isApplying
                ) {
                    Task {
                        let success = await viewModel.applyDesign(token: appState.session?.accessToken)
                        if success { onPreview?() }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, AppSpacing.lg)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: false)
        .task { await viewModel.loadTemplates(token: appState.session?.accessToken) }
        .onChange(of: viewModel.activeCategory) { _, _ in
            Task { await viewModel.loadTemplates(token: appState.session?.accessToken) }
        }
    }

    // MARK: - Subviews

    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(categories, id: \.0) { cat in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.activeCategory = cat.0
                    }
                } label: {
                    Text(cat.1)
                        .font(.appSubheadline)
                        .foregroundStyle(viewModel.activeCategory == cat.0 ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            viewModel.activeCategory == cat.0
                                ? AnyShapeStyle(AppGradients.primary)
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
        .padding(4)
        .glassCard(cornerRadius: AppRadii.full)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadii.glass, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.glass, style: .continuous)
                        .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                )

            if viewModel.isLoading {
                ProgressView().tint(AppColors.accentViolet)
            } else {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(viewModel.selectedTemplate?.name ?? "Select a template")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)

                    if let desc = viewModel.selectedTemplate?.description {
                        Text(desc)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var templateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.lg) {
                ForEach(viewModel.templates) { template in
                    TemplateThumbnail(
                        name: template.name,
                        isSelected: viewModel.selectedTemplateId == template.id,
                        isPremium: template.isPremium
                    )
                    .onTapGesture {
                        withAnimation { viewModel.selectedTemplateId = template.id }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var styleControls: some View {
        VStack(spacing: AppSpacing.lg) {
            // Spacing slider
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Spacing")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Slider(value: $viewModel.customization.spacing, in: 0...1)
                    .tint(AppColors.gradientMid)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

            // Accent color row
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Accent Color")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    ForEach(["6366F1", "22D3EE", "A78BFA", "2DD4BF", "F59E0B"], id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: viewModel.customization.accentColor == hex ? 2 : 0)
                            )
                            .onTapGesture { viewModel.customization.accentColor = hex }
                    }
                    Spacer()
                }
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

            // Font style picker
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Font Style")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: AppSpacing.md) {
                    ForEach(["Classic", "Modern", "Minimal"], id: \.self) { style in
                        let slug = style.lowercased()
                        Text(style)
                            .font(.appCaption)
                            .foregroundStyle(viewModel.customization.fontStyle == slug ? AppColors.textPrimary : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                viewModel.customization.fontStyle == slug
                                    ? AnyShapeStyle(AppGradients.primary)
                                    : AnyShapeStyle(AppColors.glassTint)
                            )
                            .clipShape(Capsule())
                            .onTapGesture { viewModel.customization.fontStyle = slug }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}

#Preview {
    RedesignResumeView(
        viewModel: DesignViewModel(
            optimizationId: "mock-opt-001",
            designService: MockResumeDesignService()
        )
    )
    .environment(AppState())
}
