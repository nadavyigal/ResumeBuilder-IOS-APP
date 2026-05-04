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
            appState.session = session
        } catch {
            // User cancelled the sheet — don't show an error in that case
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Token refresh (called by AppState on 401)

    func refreshIfNeeded() async {
        guard let refreshToken = appState.session?.refreshToken else { return }
        do {
            let session = try await AuthService.shared.refreshSession(refreshToken: refreshToken)
            appState.session = session
        } catch {
            appState.signOut()
        }
    }

    // MARK: - Private

    private func validate() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return false
        }
        if isSignUp && password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
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
            appState.session = session
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

