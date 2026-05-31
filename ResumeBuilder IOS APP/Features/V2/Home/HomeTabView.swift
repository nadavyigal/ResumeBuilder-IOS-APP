import SwiftUI
import UniformTypeIdentifiers

/// V2 Home activation surface — guest-first upload → job → ATS/optimize funnel.
struct HomeTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: TailorViewModel
    var onSwitchTab: (ResumlyTab) -> Void = { _ in }

    @State private var isImporterPresented = false
    @State private var shouldNavigate = false
    @State private var showOnboarding = false
    @State private var showLibraryPicker = false
    @State private var saveDisplayName = ""
    @State private var libraryViewModel = ResumeLibraryViewModel()
    @State private var appeared = false
    @State private var didTrackJobAdded = false

    private var activationState: HomeActivationState {
        HomeActivationState.derive(from: .init(
            hasResume: viewModel.selectedResumeName?.isEmpty == false,
            hasJob: !viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isAuthenticated: appState.isAuthenticated,
            isOptimizing: viewModel.isOptimizing || viewModel.isRunningFreeATS,
            hasATSResult: viewModel.atsResult != nil,
            hasOptimizationId: appState.latestOptimizationId != nil,
            isExportComplete: appState.isExportComplete(for: appState.latestOptimizationId)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                RadialGradient(
                    colors: [Theme.accent.opacity(0.14), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        pageHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        activationBanner
                            .opacity(appeared ? 1 : 0)

                        if activationState == .optimizedReady || activationState == .exportComplete {
                            optimizedReadyCard
                        }

                        VStack(spacing: 12) {
                            stepCard(
                                step: 1,
                                title: "Upload Resume",
                                subtitle: viewModel.selectedResumeName?.isEmpty == false ? viewModel.selectedResumeName! : "PDF, up to 5 MB",
                                icon: "doc.fill",
                                isFilled: viewModel.selectedResumeName?.isEmpty == false,
                                action: { isImporterPresented = true }
                            )

                            if viewModel.selectedResumeName?.isEmpty != false,
                               appState.isAuthenticated,
                               RuntimeFeatures.isResumeLibraryEnabled {
                                libraryButton
                            }

                            stepConnector(filled: viewModel.selectedResumeName?.isEmpty == false)

                            jobInputCard

                            stepConnector(filled: hasJobInput)

                            optimizeCard
                        }

                        if viewModel.isOptimizing || viewModel.isRunningFreeATS {
                            OptimizingView()
                                .transition(.scale.combined(with: .opacity))
                        }

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        if let atsResult = viewModel.atsResult, !appState.isAuthenticated {
                            ScoreResultView(result: atsResult, isAuthenticated: false)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))

                            privacyReassurance

                            Button {
                                showOnboarding = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Sign in to Optimize")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(.white)
                                .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.useSharedJobURLIfNeeded(from: appState)
                withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            }
            .sheet(isPresented: $showOnboarding) {
                NavigationStack {
                    OnboardingView(viewModel: OnboardingViewModel(appState: appState))
                }
            }
            .sheet(isPresented: $showLibraryPicker) {
                SavedResumePickerSheet(
                    libraryViewModel: libraryViewModel,
                    onSelect: { localURL, displayName in
                        viewModel.useLibraryResume(localURL: localURL, displayName: displayName)
                        showLibraryPicker = false
                    }
                )
                .environment(appState)
            }
            .confirmationDialog(
                "Save this resume?",
                isPresented: $showSavePrompt,
                titleVisibility: .visible
            ) {
                Button("Save") {
                    if let id = viewModel.pendingSaveResumeId,
                       let token = appState.session?.accessToken {
                        let name = saveDisplayName.isEmpty ? (viewModel.selectedResumeName ?? "My Resume") : saveDisplayName
                        Task { await libraryViewModel.save(id: id, displayName: name, token: token) }
                    }
                    viewModel.pendingSaveResumeId = nil
                }
                Button("Not now", role: .cancel) {
                    viewModel.pendingSaveResumeId = nil
                }
            } message: {
                Text("Save to reuse on other jobs without re-uploading.")
            }
            .onChange(of: viewModel.pendingSaveResumeId) { _, newId in
                if newId != nil, RuntimeFeatures.isResumeLibraryEnabled {
                    saveDisplayName = viewModel.selectedResumeName ?? ""
                    showSavePrompt = true
                } else if newId != nil {
                    viewModel.pendingSaveResumeId = nil
                }
            }
            .onChange(of: viewModel.selectedResumeName) { _, newName in
                if newName?.isEmpty == false {
                    AnalyticsService.shared.track(.resumeUploaded)
                }
            }
            .onChange(of: viewModel.jobDescription) { _, _ in trackJobAddedIfNeeded() }
            .onChange(of: viewModel.jobDescriptionURL) { _, _ in trackJobAddedIfNeeded() }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.cachePickedFile(url: url)
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .navigationDestination(isPresented: $shouldNavigate) {
                if let reviewId = viewModel.reviewId {
                    OptimizationReviewView(
                        viewModel: OptimizationReviewViewModel(reviewId: reviewId),
                        onAppliedOptimization: { optId in
                            appState.latestOptimizationId = optId
                            AnalyticsService.shared.track(.optimizationCompleted)
                            shouldNavigate = false
                            onSwitchTab(.optimized)
                        }
                    )
                }
            }
        }
    }

    @State private var showSavePrompt = false

    private var hasJobInput: Bool {
        !viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func trackJobAddedIfNeeded() {
        guard hasJobInput, !didTrackJobAdded else { return }
        didTrackJobAdded = true
        AnalyticsService.shared.track(.jobAdded(
            hasURL: !viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            hasPaste: !viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ))
    }

    // MARK: - Header & activation

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("GET STARTED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .kerning(1.2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.accent.opacity(0.12), in: Capsule())

            Text("Home")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Upload, match to a job, and optimize your resume.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
        }
    }

    private var activationBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activationState.headline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(activationState.subheadline)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activationState.headline). \(activationState.subheadline)")
    }

    private var optimizedReadyCard: some View {
        VStack(spacing: 12) {
            Button {
                onSwitchTab(.optimized)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.richtext.fill")
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("View optimized resume")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Preview and export your PDF")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var privacyReassurance: some View {
        Label("Your resume stays private until you sign in.", systemImage: "lock.shield.fill")
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared step UI (mirrors TailorView)

    private var libraryButton: some View {
        Button {
            if let token = appState.session?.accessToken {
                Task { await libraryViewModel.load(token: token) }
            }
            showLibraryPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accentBlue)
                Text("Use a saved resume")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(12)
            .background(Theme.accentBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepCard(
        step: Int,
        title: String,
        subtitle: String,
        icon: String,
        isFilled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            let circleFill: AnyShapeStyle = isFilled ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.bgPrimary)
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(circleFill)
                        .frame(width: 36, height: 36)
                    if isFilled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(step)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isFilled ? Theme.accentBlue : Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isFilled ? "pencil" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isFilled ? Theme.accentBlue : Theme.textTertiary)
            }
            .padding(16)
            .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepConnector(filled: Bool) -> some View {
        HStack {
            Spacer().frame(width: 38)
            Rectangle()
                .fill(filled ? Theme.accent.opacity(0.5) : Theme.textTertiary.opacity(0.15))
                .frame(width: 2, height: 20)
                .padding(.leading, 17)
            Spacer()
        }
    }

    private var jobInputCard: some View {
        let jobFilled = hasJobInput
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(jobFilled ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.bgPrimary))
                        .frame(width: 36, height: 36)
                    if jobFilled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("2")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Add Job")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("URL or paste description")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(Theme.textTertiary)
                    TextField("LinkedIn or job post URL", text: $viewModel.jobDescriptionURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                }
                .padding(12)
                .background(Theme.bgPrimary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.bgPrimary.opacity(0.5))
                    if viewModel.jobDescription.isEmpty {
                        Text("Or paste job description here")
                            .foregroundStyle(Theme.textTertiary)
                            .font(.subheadline)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $viewModel.jobDescription)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 110)
                        .padding(8)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                }
                .frame(minHeight: 110)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var optimizeCard: some View {
        let canOptimize = viewModel.selectedResumeName?.isEmpty == false && hasJobInput
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(canOptimize ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.bgPrimary))
                        .frame(width: 36, height: 36)
                    Text("3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canOptimize ? Color.white : Theme.textTertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.isAuthenticated ? "Optimize" : "Free ATS Check")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(appState.isAuthenticated ? "AI rewrites for this job" : "See your score before signing in")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)

            Button {
                Task {
                    if appState.isAuthenticated {
                        AnalyticsService.shared.track(.optimizationStarted)
                        await viewModel.optimize(appState: appState)
                        if let optId = viewModel.optimizationId, !optId.isEmpty {
                            appState.latestOptimizationId = optId
                            AnalyticsService.shared.track(.optimizationCompleted)
                            onSwitchTab(.optimized)
                        } else if viewModel.reviewId != nil {
                            shouldNavigate = true
                        }
                    } else {
                        await viewModel.runFreeATS(appState: appState)
                        if viewModel.atsResult?.score?.overall != nil {
                            let score = viewModel.atsResult?.score?.overall ?? 0
                            AnalyticsService.shared.track(.freeATSCompleted(
                                scoreBucket: AnalyticsEvent.scoreBucket(for: score)
                            ))
                        }
                    }
                }
            } label: {
                Group {
                    if viewModel.isOptimizing || viewModel.isRunningFreeATS {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: appState.isAuthenticated ? "wand.and.stars" : "gauge.medium")
                            Text(appState.isAuthenticated ? "Optimize Resume" : "Run Free ATS Check")
                                .fontWeight(.bold)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(canOptimize ? Color.white : Theme.textTertiary)
                .background(
                    canOptimize && !viewModel.isOptimizing
                        ? AnyShapeStyle(Theme.brandGradient)
                        : AnyShapeStyle(Theme.bgPrimary.opacity(0.5)),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .disabled(!canOptimize || viewModel.isOptimizing || viewModel.isRunningFreeATS)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    HomeTabView(viewModel: TailorViewModel())
        .environment(AppState())
}
