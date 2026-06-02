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
    @State private var isManualEditMode = false
    @State private var manualEditTextBySection: [String: String] = [:]
    @State private var submitVM: SubmitApplicationViewModel? = nil
    @State private var showSubmitPackageSheet = false
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

                if isManualEditMode {
                    manualEditPanel
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
        .sheet(isPresented: $showSubmitPackageSheet) {
            if let submitVM {
                SubmitApplicationSheet(
                    vm: submitVM,
                    accessToken: appState.session?.accessToken
                )
            }
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
                        toggleManualEditMode()
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

    private var manualEditPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Manual Edits")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if viewModel.isRefreshingATS {
                    ProgressView()
                        .tint(AppColors.accentTeal)
                }
            }

            ForEach(viewModel.sections) { section in
                manualEditSection(section)
            }
        }
    }

    private func manualEditSection(_ section: OptimizedResumeSection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(section.type.displayName)
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

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
                    .frame(minHeight: editorHeight(for: section.body))
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    manualEditTextBySection[section.id] = section.body
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.appCaption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(viewModel.isSaving || !hasPendingManualEdit(for: section))

                Button {
                    Task { await saveManualEdit(section) }
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.appCaption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .glassCard(cornerRadius: AppRadii.md)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(viewModel.isSaving || !hasPendingManualEdit(for: section))
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
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

    private func toggleManualEditMode() {
        if isManualEditMode {
            isManualEditMode = false
            return
        }
        manualEditTextBySection = Dictionary(uniqueKeysWithValues: viewModel.sections.map { ($0.id, $0.body) })
        isManualEditMode = true
    }

    @MainActor
    private func saveManualEdit(_ section: OptimizedResumeSection) async {
        let text = manualEditTextBySection[section.id] ?? section.body
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

private struct SubmitApplicationSheet: View {
    @Environment(\.dismiss) private var dismiss
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
                Task { await vm.submit(token: accessToken) }
            }
            .disabled(!vm.canSubmit)
        }
    }

    private func packageView(_ package: SubmitApplicationPackage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Label("Package ready", systemImage: "checkmark.circle.fill")
                .font(.appHeadline)
                .foregroundStyle(AppColors.accentTeal)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(package.application.jobTitle ?? vm.jobTitle)
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(package.application.companyName ?? vm.companyName)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)

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
                        Label("Open Job Link", systemImage: "safari")
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
        }
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
