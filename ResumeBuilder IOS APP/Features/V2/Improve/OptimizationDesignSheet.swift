import SwiftUI

struct OptimizationDesignSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @Bindable var designVM: DesignViewModel

    private let categories = [
        ("traditional", "Traditional"),
        ("modern",      "Modern"),
        ("creative",    "Creative"),
        ("corporate",   "Corporate"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    categoryPicker

                    if designVM.isLoading {
                        ProgressView()
                            .tint(AppColors.accentViolet)
                            .frame(height: 80)
                    } else if !designVM.templates.isEmpty {
                        templateStrip
                    }

                    styleControls

                    GradientButton(
                        title: "Apply Design",
                        icon: "paintbrush.fill",
                        isLoading: designVM.isApplying
                    ) {
                        Task {
                            let ok = await designVM.applyDesign(token: appState.session?.accessToken)
                            if ok { isPresented = false }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    if let err = designVM.errorMessage {
                        Text(err)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .task {
                await designVM.loadTemplates(token: appState.session?.accessToken)
                await designVM.loadStyleHistory(token: appState.session?.accessToken)
            }
            .onChange(of: designVM.activeCategory) { _, _ in
                Task { await designVM.loadTemplates(token: appState.session?.accessToken) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(categories, id: \.0) { cat in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        designVM.activeCategory = cat.0
                    }
                } label: {
                    Text(cat.1)
                        .font(.appSubheadline)
                        .foregroundStyle(designVM.activeCategory == cat.0 ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            designVM.activeCategory == cat.0
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

    private var templateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.lg) {
                ForEach(designVM.templates) { template in
                    TemplateThumbnail(
                        name: template.name,
                        isSelected: designVM.selectedTemplateId == template.id,
                        isPremium: template.isPremium
                    )
                    .onTapGesture {
                        withAnimation { designVM.selectedTemplateId = template.id }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var styleControls: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Spacing")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Slider(value: $designVM.customization.spacing, in: 0...1)
                    .tint(AppColors.gradientMid)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

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
                                    .strokeBorder(.white, lineWidth: designVM.customization.accentColor == hex ? 2 : 0)
                            )
                            .onTapGesture { designVM.customization.accentColor = hex }
                    }
                    Spacer()
                }
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Font Style")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: AppSpacing.md) {
                    ForEach(["Classic", "Modern", "Minimal"], id: \.self) { style in
                        let slug = style.lowercased()
                        Text(style)
                            .font(.appCaption)
                            .foregroundStyle(designVM.customization.fontStyle == slug ? AppColors.textPrimary : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                designVM.customization.fontStyle == slug
                                    ? AnyShapeStyle(AppGradients.primary)
                                    : AnyShapeStyle(AppColors.glassTint)
                            )
                            .clipShape(Capsule())
                            .onTapGesture { designVM.customization.fontStyle = slug }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}
