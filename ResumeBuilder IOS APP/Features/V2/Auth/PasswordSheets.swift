import SwiftUI
import Observation

/// Same minimum as Supabase (`supabase/config.toml`), sign-up, and the web
/// update-password page.
let minimumPasswordLength = 6

// MARK: - Forgot password

@Observable
@MainActor
final class ForgotPasswordViewModel: Identifiable {
    enum Phase: Equatable {
        case editing
        case sending
        case sent
    }

    var email: String
    private(set) var phase: Phase = .editing
    private(set) var errorMessage: String?

    private let send: (String) async throws -> Void

    init(
        email: String = "",
        send: @escaping (String) async throws -> Void = { try await AuthService.shared.sendPasswordReset(email: $0) }
    ) {
        self.email = email
        self.send = send
    }

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func submit() async {
        guard phase == .editing else { return }
        guard Self.looksLikeEmail(trimmedEmail) else {
            errorMessage = NSLocalizedString("Enter a valid email address.", comment: "Forgot password sheet")
            return
        }
        errorMessage = nil
        phase = .sending
        do {
            try await send(trimmedEmail)
            phase = .sent
        } catch {
            errorMessage = error.localizedDescription
            phase = .editing
        }
    }

    static func looksLikeEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !value.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}

struct ForgotPasswordView: View {
    @Bindable var viewModel: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if viewModel.phase == .sent {
                        sentState
                    } else {
                        formState
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(Text("Reset password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.phase == .sent ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    private var formState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Enter your account email. We'll send you a link to choose a new password.")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)

            TextField("Email", text: $viewModel.email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.submit() } }
                .accessibilityLabel(Text("Email"))
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .padding(AppSpacing.lg)
                .glassCard(cornerRadius: AppRadii.md)

            GradientButton(title: "Send reset link", isLoading: viewModel.phase == .sending) {
                Task { await viewModel.submit() }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.appCaption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var sentState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Check your email", systemImage: "envelope.badge.fill")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)
            Text("If an account uses \(viewModel.trimmedEmail), a reset link is on its way. Open it, choose a new password, then sign in here.")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Change password

@Observable
@MainActor
final class ChangePasswordViewModel: Identifiable {
    var newPassword = ""
    var confirmPassword = ""
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var errorMessage: String?

    private let change: (String) async throws -> Void

    init(change: @escaping (String) async throws -> Void) {
        self.change = change
    }

    func save() async {
        guard !isSaving, !didSave else { return }
        guard newPassword.count >= minimumPasswordLength else {
            errorMessage = String(
                format: NSLocalizedString("Use at least %lld characters.", comment: "Password rule"),
                Int64(minimumPasswordLength)
            )
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = NSLocalizedString("The passwords don't match.", comment: "Change password sheet")
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await change(newPassword)
            didSave = true
            newPassword = ""
            confirmPassword = ""
        } catch APIClientError.unauthorized {
            // The token refresh failed too, so the session is gone.
            errorMessage = NSLocalizedString(
                "Your session has expired. Sign out, sign in again, then change your password.",
                comment: "Change password sheet"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ChangePasswordView: View {
    @Bindable var viewModel: ChangePasswordViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if viewModel.didSave {
                        Label("Password changed. Use it next time you sign in.", systemImage: "checkmark.seal.fill")
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        passwordField("New password", text: $viewModel.newPassword)
                        passwordField("Confirm new password", text: $viewModel.confirmPassword)

                        GradientButton(title: "Save new password", isLoading: viewModel.isSaving) {
                            Task { await viewModel.save() }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.appCaption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(Text("Change Password"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.didSave ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    private func passwordField(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)
            SecureField(title, text: text)
                .textContentType(.newPassword)
                .accessibilityLabel(Text(title))
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .padding(AppSpacing.lg)
                .glassCard(cornerRadius: AppRadii.md)
        }
    }
}
