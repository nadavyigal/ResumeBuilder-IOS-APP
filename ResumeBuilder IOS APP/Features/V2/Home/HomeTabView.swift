import SwiftUI
import UniformTypeIdentifiers

/// V2 Home activation surface — guest-first upload → job → ATS/optimize funnel.
struct HomeTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: TailorViewModel
    var onSwitchTab: (ResumlyTab) -> Void = { _ in }
    var onShowOptimizedPreview: (String) -> Void = { _ in }

    @State private var isImporterPresented = false
    @State private var journeyRoute: FirstSessionJourneyRoute?
    @State private var diagnosisViewModel: ResumeDiagnosisViewModel? = nil
    @State private var showOnboarding = false
    @State private var showLibraryPicker = false
    @State private var saveDisplayName = ""
    @State private var libraryViewModel = ResumeLibraryViewModel()
    @State private var isImporterFlowActive = false
    @State private var appeared = false
    @State private var didTrackUploadCTASeen = false
    @State private var didTrackJobAdded = false
    @State private var showFitCheck = false
    @State private var fitCheckViewModel = FitCheckViewModel()

    private var activationState: HomeActivationState {
        HomeActivationState.derive(from: .init(
            hasResume: viewModel.selectedResumeName?.isEmpty == false,
            hasJob: jobInputEvaluation.isReady,
            isAuthenticated: appState.isAuthenticated,
            isOptimizing: viewModel.isOptimizing || viewModel.isRunningFreeATS,
            hasATSResult: viewModel.atsResult != nil,
            hasOptimizationId: appState.latestOptimizationId != nil,
            isExportComplete: appState.isExportComplete(for: appState.latestOptimizationId)
        ))
    }

    private enum ScrollAnchor {
        static let jobInput = "job-input"
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

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            pageHeader
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)

                            progressPath
                                .opacity(appeared ? 1 : 0)

                            if activationState == .optimizedReady || activationState == .exportComplete {
                                optimizedReadyCard
                            }

                            uploadHero

                            if viewModel.selectedResumeName?.isEmpty != false,
                               appState.isAuthenticated,
                               RuntimeFeatures.isResumeLibraryEnabled {
                                libraryButton
                            }

                            motivationStrip

                            if let uploadFailureReason = viewModel.uploadFailureReason {
                                UploadFailureView(
                                    reason: uploadFailureReason,
                                    filename: viewModel.failedResumeName,
                                    onChooseAnother: openUploadPicker
                                )
                            }

                            if viewModel.selectedResumeName?.isEmpty == false {
                                jobInputCard
                                    .id(ScrollAnchor.jobInput)

                                optimizeCard
                            }

                            if viewModel.isOptimizing || viewModel.isRunningFreeATS {
                                ResumeOptimizationLoadingView(mode: viewModel.isRunningFreeATS ? .atsCheck : .optimization)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            if viewModel.errorMessage != nil, viewModel.uploadFailureReason == nil, viewModel.isConnectionError {
                                ConnectionLostView(onRetry: { Task { await runAnalysis() } })
                            } else if let error = viewModel.errorMessage, viewModel.uploadFailureReason == nil {
                                errorBanner(error)
                            }

                            // The diagnosis outlives sign-in: it describes the résumé and
                            // job on screen, and authenticating changes neither.
                            if let atsResult = viewModel.atsResult {
                                ScoreResultView(result: atsResult, isAuthenticated: appState.isAuthenticated)
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))

                                if !appState.isAuthenticated {
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
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: viewModel.selectedResumeName) { _, newName in
                        guard newName?.isEmpty == false else { return }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            scrollToJobInput(using: scrollProxy)
                        }
                    }
                }
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
            .sheet(isPresented: $showFitCheck) {
                NavigationStack {
                    FitCheckView(viewModel: fitCheckViewModel)
                }
            }
            .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    showOnboarding = false
                }
                // Authentication does not touch the résumé or job, so this keeps the
                // guest diagnosis on both sign-in and cancellation. Optimization is
                // never started here — the user chooses the next step.
                viewModel.invalidateGuestDiagnosisIfInputsChanged()
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
                        let name = saveDisplayName.isEmpty ? (viewModel.selectedResumeName ?? NSLocalizedString("My Resume", comment: "")) : saveDisplayName
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
                    appState.hasUploadedResumeThisSession = true
                }
            }
            .onChange(of: viewModel.jobDescription) { _, _ in
                trackJobAddedIfNeeded()
                viewModel.invalidateGuestDiagnosisIfInputsChanged()
            }
            .onChange(of: viewModel.jobDescriptionURL) { _, _ in
                trackJobAddedIfNeeded()
                viewModel.invalidateGuestDiagnosisIfInputsChanged()
            }
            .onChange(of: viewModel.selectedResumeURL) { _, _ in
                viewModel.invalidateGuestDiagnosisIfInputsChanged()
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: Self.resumeImportContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    markImporterResolved()
                    guard let url = urls.first else {
                        AnalyticsService.shared.track(.resumeFilePickerCancelled(source: "home"))
                        return
                    }
                    viewModel.cachePickedFile(url: url)
                case .failure(let error):
                    markImporterResolved()
                    if (error as NSError).code == NSUserCancelledError {
                        AnalyticsService.shared.track(.resumeFilePickerCancelled(source: "home"))
                    } else {
                        viewModel.errorMessage = error.localizedDescription
                        AnalyticsService.shared.track(.resumeUploadErrorShown(errorCode: "picker_failure"))
                    }
                }
            }
            .onChange(of: isImporterPresented) { _, isPresented in
                guard !isPresented else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    trackImporterCancellationIfNeeded()
                }
            }
            .navigationDestination(item: $journeyRoute) { route in
                switch route {
                case .optimizationReview(let reviewId):
                    OptimizationReviewDestination(
                        reviewId: reviewId,
                        onAppliedOptimization: { optId in
                            FirstSessionJourneyTransition.completeApply(
                                optimizationId: optId,
                                persist: { optimizationId in
                                    appState.latestOptimizationId = optimizationId
                                    appState.rememberJobURL(viewModel.jobDescriptionURL, for: optimizationId)
                                    viewModel.pendingSaveResumeId = optimizationId
                                    journeyRoute = nil
                                },
                                showPreview: onShowOptimizedPreview
                            )
                        }
                    )
                case .diagnosis:
                    if let diagnosisViewModel {
                        ResumeDiagnosisView(
                            viewModel: diagnosisViewModel,
                            onImprove: {
                                journeyRoute = nil
                                self.diagnosisViewModel = nil
                                onSwitchTab(.optimized)
                            },
                            onEditTargetJob: {
                                journeyRoute = nil
                                self.diagnosisViewModel = nil
                            }
                        )
                    }
                }
            }
        }
    }

    @State private var showSavePrompt = false

    /// Resume import accepts PDF plus Word docs — the preflight/backend already
    /// support .docx, so restricting the picker to PDF silently blocked Word users (WP-18).
    static let resumeImportContentTypes: [UTType] = {
        var types: [UTType] = [.pdf]
        if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
        if let doc = UTType(filenameExtension: "doc") { types.append(doc) }
        return types
    }()

    private var jobInputEvaluation: JobInputPolicy.Evaluation {
        JobInputPolicy.evaluate(
            description: viewModel.jobDescription,
            urlString: viewModel.jobDescriptionURL
        )
    }

    private var hasJobInput: Bool {
        jobInputEvaluation.isReady
    }

    private func scrollToJobInput(using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(ScrollAnchor.jobInput, anchor: .top)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(ScrollAnchor.jobInput, anchor: .top)
            }
        }
    }

    private func trackJobAddedIfNeeded() {
        guard hasJobInput, !didTrackJobAdded else { return }
        didTrackJobAdded = true
        appState.hasAddedJobThisSession = true
        AnalyticsService.shared.track(.jobAdded(
            hasURL: !viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            hasPaste: !viewModel.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ))
    }

    private func openUploadPicker() {
        AnalyticsService.shared.track(.resumeUploadCTATapped(source: "home"))
        openResumeImporter()
    }

    private func openResumeImporter() {
        isImporterFlowActive = true
        AnalyticsService.shared.track(.resumeFilePickerOpened(source: "home"))
        isImporterPresented = true
    }

    private func markImporterResolved() {
        isImporterFlowActive = false
    }

    private func trackImporterCancellationIfNeeded() {
        guard isImporterFlowActive else { return }
        isImporterFlowActive = false
        AnalyticsService.shared.track(.resumeFilePickerCancelled(source: "home"))
    }

    private func trackUploadCTASeenIfNeeded() {
        guard !didTrackUploadCTASeen else { return }
        didTrackUploadCTASeen = true
        AnalyticsService.shared.track(.resumeUploadCTASeen(source: "home"))
    }

    private func runAnalysis() async {
        if appState.isAuthenticated {
            if BackendConfig.isFitCheckEnabled {
                await prepareFitCheck()
            } else {
                await continueOptimization()
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

    private func trackAnalysisIntent() {
        let evaluation = JobInputPolicy.evaluate(
            description: viewModel.jobDescription,
            urlString: viewModel.jobDescriptionURL
        )
        if let reason = evaluation.blockingReason?.analyticsValue {
            AnalyticsService.shared.track(.jobInputValidationShown(surface: "home", reason: reason))
        }
        guard appState.isAuthenticated else { return }
        AnalyticsService.shared.track(.analysisCTATapped(
            source: "home",
            flowVersion: .fitGateV1,
            hasURL: evaluation.hasURLInput,
            hasPaste: evaluation.hasDescriptionInput
        ))
    }

    private func prepareFitCheck() async {
        do {
            guard let upload = try await viewModel.ensureUploadedResumeForCurrentJob(appState: appState),
                  let resumeId = upload.resumeId,
                  !resumeId.isEmpty else {
                if viewModel.errorMessage == nil {
                    viewModel.errorMessage = NSLocalizedString("Upload did not return resume or job description ids.", comment: "")
                }
                return
            }

            fitCheckViewModel.resumeId = resumeId
            fitCheckViewModel.accessToken = appState.session?.accessToken
            fitCheckViewModel.jobDescription = viewModel.jobDescription
            fitCheckViewModel.jobDescriptionURL = viewModel.jobDescriptionURL
            fitCheckViewModel.resetToEntry()
            fitCheckViewModel.onOptimize = { _ in
                showFitCheck = false
                Task { await continueOptimization() }
            }
            fitCheckViewModel.onSkip = { showFitCheck = false }
            fitCheckViewModel.onNeedResume = {
                showFitCheck = false
                openUploadPicker()
            }
            showFitCheck = true
        } catch let apiError as APIClientError {
            if case .serverError(let status, _) = apiError, status == 400 {
                viewModel.errorMessage = JobInputPolicy.friendlyInputError()
            } else {
                viewModel.errorMessage = apiError.userFacingMessage
            }
            viewModel.isConnectionError = false
        } catch {
            viewModel.errorMessage = error.localizedDescription
            viewModel.isConnectionError = TailorViewModel.isConnectivityError(error)
        }
    }

    private func continueOptimization() async {
        // optimizationStarted / optimizationCompleted are fired inside
        // TailorViewModel.optimize() — do not double-fire here.
        await viewModel.optimize(appState: appState)
        if let optId = viewModel.optimizationId, !optId.isEmpty {
            appState.latestOptimizationId = optId
            appState.rememberJobURL(viewModel.jobDescriptionURL, for: optId)
            viewModel.pendingSaveResumeId = optId
            diagnosisViewModel = ResumeDiagnosisViewModel(optimizationId: optId)
            journeyRoute = .diagnosis(optimizationId: optId)
        } else if let reviewId = viewModel.reviewId {
            journeyRoute = .optimizationReview(reviewId: reviewId)
        }
    }

    // MARK: - Header & activation

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GET STARTED")
                    .font(.caption2.weight(.black))
                    .kerning(1.1)
                    .foregroundStyle(AppColors.accentSky)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColors.accentSky.opacity(0.12), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(AppColors.accentSky.opacity(0.3), lineWidth: 1)
                    )

                Spacer()

                languageSwitcher
            }

            Text("Step 1 of 3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)

            Text("See your résumé like a recruiter does")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Upload, match to a job, and get your first diagnosis in under 2 minutes.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(LocalizationManager.AppLanguage.allCases) { language in
                languageButton(language)
            }
        }
        .padding(4)
        .background(AppColors.glassTint, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppColors.glassStroke, lineWidth: 1)
        )
        .accessibilityLabel("Language")
    }

    private func languageButton(_ language: LocalizationManager.AppLanguage) -> some View {
        let isSelected = localization.language == language
        return Button {
            localization.setLanguage(language)
        } label: {
            Text(language.rawValue.uppercased())
                .font(.caption2.weight(.black))
                .frame(minWidth: 34, minHeight: 28)
                .foregroundStyle(isSelected ? Color.white : AppColors.textSecondary)
                .background(
                    isSelected ? AnyShapeStyle(AppGradients.primary) : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var progressPath: some View {
        HStack(spacing: AppSpacing.sm) {
            progressChip(index: 1, title: "Upload", isActive: viewModel.selectedResumeName?.isEmpty != false, isComplete: viewModel.selectedResumeName?.isEmpty == false)
            progressConnector(isComplete: viewModel.selectedResumeName?.isEmpty == false)
            progressChip(index: 2, title: "Add job", isActive: viewModel.selectedResumeName?.isEmpty == false && !hasJobInput, isComplete: hasJobInput)
            progressConnector(isComplete: hasJobInput)
            progressChip(index: 3, title: "ATS score", isActive: hasJobInput, isComplete: viewModel.atsResult != nil || appState.latestOptimizationId != nil)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress path. Upload, add job, ATS score.")
    }

    private func progressChip(index: Int, title: LocalizedStringKey, isActive: Bool, isComplete: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isComplete || isActive ? AnyShapeStyle(AppGradients.primary) : AnyShapeStyle(AppColors.glassTint))
                    .frame(width: 25, height: 25)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(isActive ? .white : AppColors.textTertiary)
                }
            }

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive || isComplete ? AppColors.textPrimary : AppColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            (isActive ? AppColors.accentSky.opacity(0.1) : AppColors.glassTint),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(isActive ? AppColors.accentSky.opacity(0.34) : AppColors.glassStroke, lineWidth: 1)
        )
    }

    private func progressConnector(isComplete: Bool) -> some View {
        Rectangle()
            .fill(isComplete ? AppColors.accentSky.opacity(0.45) : Color.white.opacity(0.16))
            .frame(width: 12, height: 2)
    }

    private var uploadHero: some View {
        Button(action: openUploadPicker) {
            VStack(spacing: 0) {
                VStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppGradients.primary)
                            .frame(width: 58, height: 58)
                            .shadow(color: AppColors.accentSky.opacity(reduceMotion ? 0.32 : 0.55), radius: reduceMotion ? 14 : 22, y: 8)
                            .scaleEffect(appeared && !reduceMotion ? 1.03 : 1)
                            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: appeared && !reduceMotion)

                        Image(systemName: viewModel.selectedResumeName?.isEmpty == false ? "checkmark" : "square.and.arrow.up")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 5) {
                        Text(viewModel.selectedResumeName?.isEmpty == false ? "Résumé selected" : "Upload your résumé")
                            .font(.title3.weight(.black))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(viewModel.selectedResumeName?.isEmpty == false ? (viewModel.selectedResumeName ?? "") : NSLocalizedString("PDF or DOCX · up to 5 MB", comment: ""))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(viewModel.selectedResumeName?.isEmpty == false ? AppColors.accentSky : AppColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "folder.fill")
                        Text(viewModel.selectedResumeName?.isEmpty == false ? "Choose a different file" : "Choose a file")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [AppColors.accentSky.opacity(0.12), .clear],
                                center: .top,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                        .foregroundStyle(AppColors.accentSky.opacity(0.42))
                )

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "folder")
                    Text("Files")
                    Text("·").foregroundStyle(Color.white.opacity(0.25))
                    Text("iCloud Drive")
                    Text("·").foregroundStyle(Color.white.opacity(0.25))
                    Text("Downloads")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.accentSky)
                .padding(.vertical, 12)
                .accessibilityHidden(true)
            }
            .padding(7)
            .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
            )
            .shadow(color: AppColors.accentSky.opacity(0.22), radius: 28, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.selectedResumeName?.isEmpty == false ? NSLocalizedString("Résumé selected. Choose a different file.", comment: "") : NSLocalizedString("Upload your résumé. PDF or DOCX up to 5 megabytes.", comment: ""))
        .onAppear(perform: trackUploadCTASeenIfNeeded)
    }

    private var motivationStrip: some View {
        Label {
            Text("See what a recruiter notices in the first 7 seconds — then fix it.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "eye.fill")
                .foregroundStyle(AppColors.accentCyan)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentCyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColors.accentCyan.opacity(0.18), lineWidth: 1)
        )
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
        Label("Your resume is uploaded securely for analysis. Sign in only when you're ready to optimize and export.", systemImage: "lock.shield.fill")
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
        title: LocalizedStringKey,
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
                    Text(verbatim: subtitle)
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

                HStack(spacing: 6) {
                    Image(systemName: jobInputEvaluation.isReady ? "checkmark.circle.fill" : "info.circle.fill")
                    Text(jobInputEvaluation.inlineGuidance)
                }
                .font(.caption)
                .foregroundStyle(jobInputEvaluation.isReady ? Color.green : Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// True once a signed-in user still has the diagnosis they ran as a guest —
    /// the step in front of them is continuing from it, not producing it again.
    private var isContinuingFromGuestDiagnosis: Bool {
        appState.isAuthenticated && viewModel.postAuthStep == .continueToOptimize
    }

    private var optimizeCardTitle: LocalizedStringKey {
        if isContinuingFromGuestDiagnosis { return "Optimize" }
        return appState.isAuthenticated ? "Analyze" : "Free ATS Check"
    }

    private var optimizeCardSubtitle: LocalizedStringKey {
        if isContinuingFromGuestDiagnosis { return "Continue from the diagnosis you already ran" }
        return appState.isAuthenticated ? "Diagnose gaps and improve this resume" : "See your score before signing in"
    }

    private var optimizeCardActionTitle: LocalizedStringKey {
        if isContinuingFromGuestDiagnosis { return "Continue to optimize" }
        return appState.isAuthenticated ? "Analyze my resume" : "Run Free ATS Check"
    }

    private var optimizeCardIcon: String {
        if isContinuingFromGuestDiagnosis { return "arrow.forward.circle.fill" }
        return appState.isAuthenticated ? "wand.and.stars" : "gauge.medium"
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
                    Text(optimizeCardTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(optimizeCardSubtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)

            Button {
                trackAnalysisIntent()
                Task { await runAnalysis() }
            } label: {
                Group {
                    if viewModel.isOptimizing || viewModel.isRunningFreeATS {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: optimizeCardIcon)
                            Text(optimizeCardActionTitle)
                                .fontWeight(.bold)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(canOptimize ? Color.white : Theme.textTertiary)
                .background(
                    canOptimize && !(viewModel.isOptimizing || viewModel.isRunningFreeATS)
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
