import SwiftUI
import UniformTypeIdentifiers

struct ProfileViewV2: View {
    @Environment(AppState.self) private var appState
    @State private var resumeViewModel = ResumeManagementViewModel()
    @State private var showPaywall = false
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    GreetingHeader(
                        name: firstName,
                        screenTitle: "Profile"
                    )
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)

                    // Account card
                    accountCard

                    // Resume card
                    resumeCard

                    // My Applications
                    applicationsCard

                    // Credits (monetization guard)
                    if BackendConfig.isMonetizationEnabled {
                        creditsCard
                    }

                    // Sign out
                    if appState.isAuthenticated {
                        signOutButton
                    } else {
                        signInButton
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)
            .screenBackground(showRadialGlow: false)
            .navigationBarHidden(true)
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
            }
            .sheet(isPresented: $showAuth) {
                OnboardingView(viewModel: OnboardingViewModel(appState: appState))
            }
            .fileImporter(
                isPresented: $resumeViewModel.isImporterPresented,
                allowedContentTypes: [.pdf, .data],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        await resumeViewModel.upload(fileURL: url, token: appState.session?.accessToken)
                    case .failure(let error):
                        resumeViewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .task {
                await resumeViewModel.load(token: appState.session?.accessToken)
            }
        }
    }

    // MARK: - Section cards

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Account", systemImage: "person.fill")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: AppSpacing.md) {
                Circle()
                    .fill(AppColors.gradientMid.opacity(0.25))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(firstName.prefix(1).uppercased())
                            .font(.appSubheadline)
                            .foregroundStyle(AppColors.gradientMid)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.session?.email ?? "Guest mode")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(appState.isAuthenticated ? "Free plan" : "Free ATS checks available")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Text(appState.identityDebugSummary())
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .textSelection(.enabled)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var resumeCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("My Resume", systemImage: "doc.fill")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)

            if resumeViewModel.isLoading {
                ProgressView()
                    .tint(AppColors.gradientMid)
            } else if let resume = resumeViewModel.currentResume {
                ResumeFileCard(
                    filename: resume.filename,
                    metadata: "Uploaded \(resume.formattedDate)"
                )

                if let preview = resume.previewText {
                    Text(preview)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(4)
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
                }
            } else {
                Text(appState.isAuthenticated ? "No master resume uploaded yet." : "Sign in to manage your master resume.")
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let uploadStatus = resumeViewModel.uploadStatus {
                Text(uploadStatus)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.accentTeal)
            }

            if let error = resumeViewModel.errorMessage {
                Text(error)
                    .font(.appCaption)
                    .foregroundStyle(.red)
            }

            GradientButton(
                title: resumeViewModel.currentResume == nil ? "Upload Resume" : "Upload New Resume",
                icon: "arrow.up.doc.fill",
                isLoading: resumeViewModel.isUploading
            ) {
                if appState.isAuthenticated {
                    resumeViewModel.isImporterPresented = true
                } else {
                    showAuth = true
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var applicationsCard: some View {
        NavigationLink {
            ApplicationsListView(viewModel: ApplicationsViewModel())
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("My Applications", systemImage: "tray.full.fill")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Track your job applications")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)
            .padding(.horizontal, AppSpacing.lg)
        }
        .buttonStyle(GradientButtonStyle())
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Credits", systemImage: "creditcard.fill")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Text("\(appState.creditsBalance) credits remaining")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button("Buy More") { showPaywall = true }
                    .font(.appCaption)
                    .foregroundStyle(AppColors.gradientMid)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: AppRadii.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            appState.signOut()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(.appSubheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 50)
            .glassCard(cornerRadius: AppRadii.lg)
        }
        .buttonStyle(GradientButtonStyle())
        .padding(.horizontal, AppSpacing.lg)
    }

    private var signInButton: some View {
        GradientButton(title: "Sign In to Optimize", icon: "person.crop.circle.badge.plus") {
            showAuth = true
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Helpers

    private var firstName: String {
        guard let email = appState.session?.email,
              let local = email.components(separatedBy: "@").first else { return "there" }
        return local.capitalized
    }
}

#Preview {
    ProfileViewV2()
        .environment(AppState())
}
