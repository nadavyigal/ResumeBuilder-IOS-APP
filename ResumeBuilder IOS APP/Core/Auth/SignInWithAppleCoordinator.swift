import AuthenticationServices
import CryptoKit
import UIKit

/// Bridges ASAuthorizationController's delegate callbacks into Swift async/await.
/// The static `current` property keeps the coordinator alive during the auth presentation.
@MainActor
final class SignInWithAppleCoordinator: NSObject {
    private enum SignInError: LocalizedError {
        case timedOut

        var errorDescription: String? { "Apple sign in timed out. Please try again." }
    }

    private static var current: SignInWithAppleCoordinator?

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Public entry point

    static func signIn() async throws -> (credential: ASAuthorizationAppleIDCredential, rawNonce: String) {
        let rawNonce = generateNonce()
        let coordinator = SignInWithAppleCoordinator()
        current = coordinator
        defer { current = nil }

        let credential = try await coordinator.present(hashedNonce: sha256(rawNonce))
        return (credential, rawNonce)
    }

    // MARK: - Private

    private func present(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
                self.continuation = continuation

                timeoutTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(20))
                    guard self.continuation != nil else { return }
                    self.continuation?.resume(throwing: SignInError.timedOut)
                    self.continuation = nil
                }

                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } onCancel: { [self] in
            Task { @MainActor in
                guard self.continuation != nil else { return }
                self.continuation?.resume(throwing: CancellationError())
                self.continuation = nil
                self.timeoutTask?.cancel()
                self.timeoutTask = nil
            }
        }
    }

    // MARK: - Nonce helpers

    private static func generateNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension SignInWithAppleCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            Task { @MainActor in
                continuation?.resume(returning: credential)
                continuation = nil
                timeoutTask?.cancel()
                timeoutTask = nil
            }
        } else {
            Task { @MainActor in
                continuation?.resume(throwing: AuthServiceError.invalidResponse)
                continuation = nil
                timeoutTask?.cancel()
                timeoutTask = nil
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension SignInWithAppleCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
