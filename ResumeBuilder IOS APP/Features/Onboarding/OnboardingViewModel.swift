import AuthenticationServices
import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var isSignUp = false
    var errorMessage: String?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func signInWithEmail() async {
        guard validate() else { return }
        await perform { try await AuthService.shared.signInWithEmail(email: self.email, password: self.password) }
    }

    func signUp() async {
        guard validate() else { return }
        await perform { try await AuthService.shared.signUpWithEmail(email: self.email, password: self.password) }
    }

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await AuthService.shared.signInWithApple()
            await appState.setSession(session)
        } catch {
            // User cancelled the sheet — don't show an error in that case
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private func validate() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = NSLocalizedString("Email and password are required.", comment: "")
            return false
        }
        if isSignUp && password.count < 6 {
            errorMessage = NSLocalizedString("Password must be at least 6 characters.", comment: "")
            return false
        }
        return true
    }

    private func perform(_ action: @escaping () async throws -> AuthSession) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await action()
            await appState.setSession(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

