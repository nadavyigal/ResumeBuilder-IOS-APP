import SwiftUI

private struct ApplicationComparePair: Identifiable {
    let left: ApplicationItem
    let right: ApplicationItem
    var id: String { "\(left.id)—\(right.id)" }
}

struct ProfileView: View {
    var isActive: Bool = false
    var onSwitchTab: (ResumlyTab) -> Void = { _ in }

    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @State private var showPaywall = false
    @State private var showOnboarding = false
    @State private var onboardingStartsInSignUp = false
    @State private var appeared = false
    @State private var navigateToLatestResume = false

    @State private var applicationsViewModel = ApplicationsViewModel()
    @State private var appSelectionMode = false
    @State private var appSelectedIds = Set<String>()
    @State private var comparePair: ApplicationComparePair?
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    private var accountInfo: AccountDisplayInfo {
        AccountDisplayInfo.resolve(
            isAuthenticated: appState.isAuthenticated,
            email: appState.session?.email
        )
    }

    private var latestOptimization: OptimizationHistoryItem? {
        appState.latestOptimization
    }

    private var profileMessage: String {
        guard appState.isAuthenticated else {
            return NSLocalizedString("Sign in and optimize a resume to see it here.", comment: "")
        }
        switch appState.optimizationRecoveryState {
        case .loading:
            return NSLocalizedString("Checking your saved optimizations…", comment: "")
        case .failed:
            return NSLocalizedString("Couldn't restore your latest optimization. Check your connection and try again.", comment: "")
        case .idle, .ready, .recovered, .empty:
            return NSLocalizedString("Tailor a resume to a job to see it here.", comment: "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ── Hero header ──────────────────────────────────────
                        heroHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -8)

                        // ── Stats row ────────────────────────────────────────
                        statsRow
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .opacity(appeared ? 1 : 0)

                        // ── Sections ─────────────────────────────────────────
                        VStack(spacing: 14) {
                            latestResumeSection
                            applicationsSection
                            if BackendConfig.isMonetizationEnabled {
                                creditsSection
                            }
                            trustCard
                            accountSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                        Spacer(minLength: 100)
                    }
                    .environment(\.layoutDirection, localization.layoutDirection)
                }
                .scrollBounceBehavior(.basedOnSize)
                .navigationDestination(isPresented: $navigateToLatestResume) {
                    if let optimizationId = appState.latestOptimizationId {
                        let opt = latestOptimization
                        OptimizedResumeView(
                            viewModel: OptimizedResumeViewModel(
                                optimizationId: optimizationId,
                                atsScoreAfter: opt?.matchScorePercent,
                                jobTitle: opt?.jobTitle,
                                company: opt?.company,
                                jobURLString: opt?.jobUrl ?? appState.jobURL(for: optimizationId)
                            ),
                            onSwitchTab: onSwitchTab
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .task(id: isActive) {
                guard isActive else { return }
                async let optimization: Void = appState.reconcileLatestOptimization()
                async let apps: Void = applicationsViewModel.load(token: appState.session?.accessToken)
                _ = await (optimization, apps)
                if !appeared {
                    withAnimation(.easeOut(duration: 0.5)) { appeared = true }
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
                    .preferredColorScheme(.dark)
                    .tint(Theme.accent)
            }
            .sheet(isPresented: $showOnboarding) {
                NavigationStack {
                    OnboardingView(viewModel: OnboardingViewModel(appState: appState, startInSignUp: onboardingStartsInSignUp))
                }
            }
            .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    showOnboarding = false
                }
            }
            .onChange(of: appState.applicationsRefreshToken) { _, _ in
                guard isActive else { return }
                Task { await applicationsViewModel.load(token: appState.session?.accessToken) }
            }
            .sheet(item: $comparePair) { pair in
                NavigationStack {
                    ApplicationCompareView(left: pair.left, right: pair.right)
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(NSLocalizedString("Account", comment: "Me tab title"))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.md) {
                Text(accountInfo.avatarInitials)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppGradients.primary, in: Circle())
                    .shadow(color: AppColors.accentSky.opacity(0.36), radius: 16, y: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(profileSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            if accountInfo.showsSignIn {
                signInValueCard
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, AppSpacing.xl)
    }

    private var profileTitle: String {
        if case .guest = accountInfo {
            return NSLocalizedString("Guest", comment: "Guest account display name")
        }
        return accountInfo.title
    }

    private var profileSubtitle: String {
        if case .guest = accountInfo {
            return NSLocalizedString("Not signed in", comment: "Guest account status")
        }
        return accountInfo.subtitle
    }

    private var signInValueCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(NSLocalizedString("Save your progress", comment: "Guest sign-in value card title"))
                .font(.title3.weight(.black))
                .foregroundStyle(AppColors.textPrimary)

            Text(NSLocalizedString(
                "Create a free account to save every optimization, sync across devices, and export unlimited PDFs.",
                comment: "Guest sign-in value card body"
            ))
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                onboardingStartsInSignUp = true
                showOnboarding = true
            } label: {
                Text(NSLocalizedString("Create free account", comment: "Guest sign-in primary CTA"))
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                onboardingStartsInSignUp = false
                showOnboarding = true
            } label: {
                Text(NSLocalizedString("Already have one? Sign in", comment: "Guest sign-in secondary CTA"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accentSky)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.accentViolet.opacity(0.13), in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .strokeBorder(AppColors.accentSky.opacity(0.24), lineWidth: 1)
        )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(
                value: appState.latestOptimizationId != nil ? "1+" : "0",
                label: NSLocalizedString("Optimized", comment: "Me stats: count of optimized resumes"),
                icon: "wand.and.stars",
                color: Theme.accent
            )
            statCell(
                value: latestOptimization.map { "\($0.matchScorePercent)%" } ?? "—",
                label: NSLocalizedString("Match Score", comment: "Me stats: latest resume's Resumely Match Score percent"),
                icon: "gauge.medium",
                color: Theme.accentBlue
            )
            statCell(
                value: "∞",
                label: NSLocalizedString("Templates", comment: "Me stats: templates available"),
                icon: "paintbrush.fill",
                color: Theme.accentCyan
            )
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Section: Latest Resume

    private var latestResumeSection: some View {
        ProfileSection(title: "Latest Resume", icon: "doc.text.fill", iconColor: Theme.accent) {
            if appState.latestOptimizationId != nil {
                let opt = latestOptimization
                Button {
                    navigateToLatestResume = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.accent.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opt?.jobTitle ?? NSLocalizedString("Optimized resume", comment: ""))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(latestResumeSubtitle(opt))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let score = opt?.matchScorePercent {
                            ATSScorePill(score: score)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        if appState.optimizationRecoveryState == .loading {
                            ProgressView()
                                .tint(Theme.accent)
                        } else {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Text(profileMessage)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if appState.optimizationRecoveryState == .failed {
                        Button("Try restoring again") {
                            Task { await appState.reconcileLatestOptimization() }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accentBlue)
                    }
                }
                .padding(14)
            }
        }
    }

    private func latestResumeSubtitle(_ optimization: OptimizationHistoryItem?) -> String {
        if appState.savedResumeRecord(for: appState.latestOptimizationId) != nil {
            return NSLocalizedString("Saved in My Resumes · Tap to preview", comment: "")
        }
        return optimization?.company ?? NSLocalizedString("Tap to preview", comment: "")
    }

    // MARK: - Section: Applications

    private var applicationsSection: some View {
        ProfileSection(title: "My Applications", icon: "tray.full.fill", iconColor: Theme.accentBlue) {
            if applicationsViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if applicationsViewModel.applications.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundStyle(Theme.textTertiary)
                    Text(appState.isAuthenticated ? "Tailor a resume to start tracking applications." : "Sign in to track applications.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
            } else {
                VStack(spacing: 0) {
                    if appSelectionMode {
                        HStack {
                            Button("Cancel") {
                                appSelectionMode = false
                                appSelectedIds.removeAll()
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Button("Compare") {
                                let items = applicationsViewModel.applications.filter { appSelectedIds.contains($0.id) }
                                if items.count == 2 {
                                    comparePair = ApplicationComparePair(left: items[0], right: items[1])
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appSelectedIds.count == 2 ? Theme.accent : Theme.textTertiary)
                            .disabled(appSelectedIds.count != 2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    ForEach(Array(applicationsViewModel.applications.enumerated()), id: \.element.id) { index, app in
                        Group {
                            if appSelectionMode {
                                Button {
                                    if appSelectedIds.contains(app.id) {
                                        appSelectedIds.remove(app.id)
                                    } else if appSelectedIds.count < 2 {
                                        appSelectedIds.insert(app.id)
                                    }
                                } label: {
                                    applicationRow(app, selected: appSelectedIds.contains(app.id))
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    ApplicationDetailView(application: app, onSwitchTab: onSwitchTab)
                                } label: {
                                    applicationRow(app, selected: false)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.55)
                                        .onEnded { _ in
                                            appSelectionMode = true
                                            appSelectedIds = [app.id]
                                        }
                                )
                            }
                        }

                        if index < applicationsViewModel.applications.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
    }

    private func applicationRow(_ app: ApplicationItem, selected: Bool) -> some View {
        HStack(spacing: 12) {
            if appSelectionMode {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                    .font(.system(size: 18))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accentBlue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accentBlue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(app.jobTitle ?? NSLocalizedString("Untitled Role", comment: ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(app.companyName ?? app.appliedDate ?? "—")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if let score = app.atsScore {
                ATSScorePill(score: score)
            }
            if !appSelectionMode {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
    }

    // MARK: - Section: Credits

    private var creditsSection: some View {
        ProfileSection(title: "Credits", icon: "creditcard.fill", iconColor: Theme.accentBlue) {
            VStack(spacing: 0) {
                NavigationLink { CreditsView() } label: {
                    profileRow(icon: "list.bullet.rectangle", label: "View Credits", color: Theme.accentBlue)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 14)

                Button { showPaywall = true } label: {
                    profileRow(icon: "plus.circle.fill", label: "Buy Credits", color: Theme.accent, isAction: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trustCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.accentCyan)
                .frame(width: 40, height: 40)
                .background(AppColors.accentCyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(NSLocalizedString("Your résumé stays private", comment: "Me trust card title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(NSLocalizedString(
                    "We never sell or share your data. Delete it anytime.",
                    comment: "Me trust card body"
                ))
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentCyan.opacity(0.07), in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .strokeBorder(AppColors.accentCyan.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Section: Account

    private var accountSection: some View {
        ProfileSection(title: "Account", icon: "person.crop.circle.fill", iconColor: Theme.textTertiary) {
            if accountInfo.showsSignIn {
                VStack(spacing: 0) {
                    Label("Your data stays private. We never share your resume.", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)

                    Button {
                        onboardingStartsInSignUp = false
                        showOnboarding = true
                    } label: {
                        profileRow(icon: "person.crop.circle.badge.plus", label: "Sign In", color: Theme.accent, isAction: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            if accountInfo.showsSignOut {
                Button(role: .destructive) {
                    appState.signOut()
                } label: {
                    profileRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        label: "Sign Out",
                        color: .red,
                        isDestructive: true
                    )
                }
                .buttonStyle(.plain)

                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if isDeletingAccount {
                        HStack(spacing: 12) {
                            ProgressView().tint(.red)
                            Text("Deleting account…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(14)
                    } else {
                        profileRow(
                            icon: "trash",
                            label: "Delete Account",
                            color: .red,
                            isDestructive: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
                .alert("Delete your account?", isPresented: $showDeleteConfirmation) {
                    Button("Delete Account", role: .destructive) {
                        deleteAccount()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes your account, resumes, optimizations, and all personal data. This action cannot be undone.")
                }
                .alert("Could not delete account", isPresented: Binding(
                    get: { deleteAccountError != nil },
                    set: { if !$0 { deleteAccountError = nil } }
                )) {
                    Button("OK", role: .cancel) { deleteAccountError = nil }
                } message: {
                    Text(deleteAccountError ?? NSLocalizedString("Please try again.", comment: ""))
                }
            }
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await appState.deleteAccount()
                // Success: session cleared; profile returns to signed-out state.
            } catch {
                deleteAccountError = error.localizedDescription
            }
            isDeletingAccount = false
        }
    }

    // MARK: - Row helper

    private func profileRow(
        icon: String,
        label: LocalizedStringKey,
        color: Color,
        isAction: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.subheadline.weight(isDestructive ? .medium : .regular))
                .foregroundStyle(isDestructive ? .red : Theme.textPrimary)
            Spacer()
            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
    }

}

// MARK: - ATS Score Pill (inline)

private struct ATSScorePill: View {
    let score: Int

    private var color: Color {
        if score >= 80 { return .green }
        if score >= 60 { return Theme.accentBlue }
        return Theme.accent
    }

    var body: some View {
        Text("\(score)%")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Profile Section Container

private struct ProfileSection<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .textCase(.uppercase)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .kerning(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }
}
