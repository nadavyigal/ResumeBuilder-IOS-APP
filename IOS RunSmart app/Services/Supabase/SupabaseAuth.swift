import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

// MARK: - Sign in with Apple handler

final class AppleSignInHandler: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var rawNonce: String = ""

    func signIn() async throws -> (credential: ASAuthorizationAppleIDCredential, nonce: String) {
        rawNonce = randomNonceString()
        let hashed = sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashed

        let credential = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }

        return (credential, rawNonce)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: appleCredential)
        } else {
            continuation?.resume(throwing: AppleSignInError.invalidCredential)
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Apple sign-in returned an unexpected credential."
        case .missingToken: "Could not retrieve the identity token from Apple."
        }
    }
}

// MARK: - SupabaseSession extension for SIWA

extension SupabaseSession {
    func signInWithApple() async throws {
        let handler = AppleSignInHandler()
        let (appleCredential, nonce) = try await handler.signIn()

        guard let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.missingToken
        }

        _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }
}
