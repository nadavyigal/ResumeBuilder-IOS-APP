import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xxl) {
                    // Hero
                    VStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppColors.gradientMid.opacity(0.15))
                                .frame(width: 88, height: 88)
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(AppGradients.primary)
                        }

                        Text("Resumely")
                            .font(.appTitle)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Tailor your resume to any job in 60 seconds.")
                            .font(.appBody)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppSpacing.xxxl)

                    // Sign in with Apple — auth flow unchanged
                    SignInWithAppleButton(
                        viewModel.isSignUp ? .signUp : .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { _ in
                            // Handled by the ViewModel via its own coordinator call.
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .onTapGesture {
                        Task { await viewModel.signInWithApple() }
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(AppColors.glassStroke)
                        Text("or")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                        Rectangle().frame(height: 1).foregroundStyle(AppColors.glassStroke)
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    // Email form
                    VStack(spacing: AppSpacing.md) {
                        TextField("Email", text: $viewModel.email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(AppSpacing.lg)
                            .glassCard(cornerRadius: AppRadii.md)

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(viewModel.isSignUp ? .newPassword : .password)
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(AppSpacing.lg)
                            .glassCard(cornerRadius: AppRadii.md)

                        GradientButton(
                            title: viewModel.isSignUp ? "Create Account" : "Sign In",
                            isLoading: viewModel.isLoading
                        ) {
                            Task {
                                if viewModel.isSignUp {
                                    await viewModel.signUp()
                                } else {
                                    await viewModel.signInWithEmail()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    // Toggle sign-in / sign-up
                    Button {
                        withAnimation { viewModel.isSignUp.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundStyle(AppColors.textSecondary)
                            Text(viewModel.isSignUp ? "Sign In" : "Sign Up")
                                .foregroundStyle(AppColors.gradientMid)
                                .fontWeight(.semibold)
                        }
                        .font(.appCaption)
                    }

                    // Error
                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, AppSpacing.lg)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.bottom, AppSpacing.xxxl)
            }
            .scrollIndicators(.hidden)
            .screenBackground(showRadialGlow: true)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
