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

    private let accentColors = ["6366F1", "22D3EE", "A78BFA", "2DD4BF", "F59E0B"]

    private var spacingLabel: String {
        switch designVM.customization.spacing {
        case 0..<0.34:  return "Compact"
        case 0.34..<0.67: return "Balanced"
        default:        return "Airy"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    categoryPicker
                    templateSection
                    selectedTemplateInfo
                    styleControls
                    actionFooter
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

    // MARK: - Category Picker

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

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(icon: "square.grid.2x2", title: "Templates")
                .padding(.horizontal, AppSpacing.lg)

            if designVM.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.accentViolet)
                    Spacer()
                }
                .frame(height: 150)
            } else if designVM.templates.isEmpty {
                emptyTemplateState
            } else {
                templateStrip
            }
        }
    }

    private var emptyTemplateState: some View {
        HStack {
            Spacer()
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.textSecondary)
                Text("No templates available")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .frame(height: 120)
    }

    private var templateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.lg) {
                ForEach(designVM.templates) { template in
                    TemplateThumbnail(
                        name: template.name,
                        category: template.category,
                        thumbnailURL: template.thumbnailURL.flatMap(URL.init),
                        isSelected: designVM.selectedTemplateId == template.id,
                        isPremium: template.isPremium
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            designVM.selectedTemplateId = template.id
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Selected Template Info

    @ViewBuilder
    private var selectedTemplateInfo: some View {
        if let template = designVM.selectedTemplate {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(categoryLabel(for: template.category))
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                if let ats = template.atsScore {
                    VStack(spacing: 2) {
                        Text("\(ats)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.gradientStart)
                        Text("ATS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                if template.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.accentViolet)
                }
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    // MARK: - Style Controls

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            sectionHeader(icon: "slider.horizontal.3", title: "Customise")
                .padding(.horizontal, AppSpacing.lg)

            spacingCard
            accentColorCard
            fontStyleCard
        }
    }

    private var spacingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Spacing")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(spacingLabel)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Slider(value: $designVM.customization.spacing, in: 0...1)
                .tint(AppColors.gradientMid)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var accentColorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Accent Color")
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textPrimary)
            HStack(spacing: AppSpacing.md) {
                ForEach(accentColors, id: \.self) { hex in
                    let isActive = designVM.customization.accentColor == hex
                    ZStack {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                        if isActive {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(isActive ? .white : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: isActive ? Color(hex: hex).opacity(0.6) : .clear, radius: 6)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2)) {
                            designVM.customization.accentColor = hex
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var fontStyleCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Font Style")
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textPrimary)
            HStack(spacing: AppSpacing.md) {
                ForEach(["Classic", "Modern", "Minimal"], id: \.self) { style in
                    let slug = style.lowercased()
                    let isActive = designVM.customization.fontStyle == slug
                    Text(style)
                        .font(.appCaption)
                        .foregroundStyle(isActive ? AppColors.textPrimary : AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            isActive
                                ? AnyShapeStyle(AppGradients.primary)
                                : AnyShapeStyle(AppColors.glassTint)
                        )
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                designVM.customization.fontStyle = slug
                            }
                        }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Action Footer

    private var actionFooter: some View {
        VStack(spacing: AppSpacing.md) {
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

            if designVM.canUndoDesign {
                Button {
                    Task { await designVM.undoLastDesign(token: appState.session?.accessToken) }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if designVM.isUndoing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppColors.textSecondary)
                        } else {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 13))
                        }
                        Text(designVM.isUndoing ? "Undoing…" : "Undo Last Design")
                            .font(.appSubheadline)
                    }
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.glassTint)
                    .clipShape(Capsule())
                }
                .disabled(designVM.isUndoing || designVM.isApplying)
            }

            if let err = designVM.errorMessage {
                Text(err)
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accentViolet)
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private func categoryLabel(for slug: String) -> String {
        switch slug.lowercased() {
        case "traditional", "ats_safe", "ats-safe": return "Traditional · ATS-Safe"
        case "modern":    return "Modern"
        case "creative":  return "Creative"
        case "corporate": return "Corporate"
        default:          return slug.capitalized
        }
    }
}
