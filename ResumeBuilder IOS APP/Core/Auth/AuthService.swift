import AuthenticationServices
import Foundation

enum AuthServiceError: Error, LocalizedError {
    case invalidResponse
    case missingSupabaseKey
    case serverError(String)
    case emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid auth response."
        case .missingSupabaseKey:
            return "Supabase configuration is missing."
        case .serverError(let message):
            return message
        case .emailConfirmationRequired:
            return "Check your email to confirm your account, then sign in."
        }
    }
}

final class AuthService {
    static let shared = AuthService()

    private let keychain = KeychainStore.shared
    private let service = "com.nadavyigal.resumebuilder.auth"
    private let account = "supabase_session"

    private init() {}

    // MARK: - Session persistence

    func restoreSession() -> AuthSession? {
        guard let data = keychain.read(service: service, account: account) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func clearSession() {
        keychain.remove(service: service, account: account)
    }

    private func persist(_ session: AuthSession) {
        if let data = try? JSONEncoder().encode(session) {
            keychain.save(data, service: service, account: account)
        }
    }

    // MARK: - Email sign-in

    func signInWithEmail(email: String, password: String) async throws -> AuthSession {
        let url = BackendConfig.supabaseURL
            .appendingPathComponent("auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")])

        let payload: [String: Any] = ["email": email, "password": password]
        let session = try await postToGoTrue(url: url, payload: payload)
        persist(session)
        return session
    }

    // MARK: - Email sign-up

    func signUpWithEmail(email: String, password: String) async throws -> AuthSession {
        let url = BackendConfig.supabaseURL.appendingPathComponent("auth/v1/signup")
        let payload: [String: Any] = ["email": email, "password": password]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(BackendConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? "Sign-up failed"
            throw AuthServiceError.serverError(parseGoTrueError(text))
        }

        // Supabase returns access_token=nil when email confirmation is required
        struct SignUpResponse: Decodable {
            let access_token: String?
            let refresh_token: String?
            let user: GoTrueUser?
        }
        let decoded = try JSONDecoder().decode(SignUpResponse.self, from: data)
        guard let token = decoded.access_token, let user = decoded.user else {
            throw AuthServiceError.emailConfirmationRequired
        }

        let session = AuthSession(
            accessToken: token,
            refreshToken: decoded.refresh_token,
            userId: user.id,
            email: user.email
        )
        persist(session)
        return session
    }

    // MARK: - Sign in with Apple

    @MainActor
    func signInWithApple() async throws -> AuthSession {
        let (credential, rawNonce) = try await SignInWithAppleCoordinator.signIn()

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthServiceError.invalidResponse
        }

        let url = BackendConfig.supabaseURL
            .appendingPathComponent("auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")])

        let payload: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": rawNonce,
        ]
        let session = try await postToGoTrue(url: url, payload: payload)
        persist(session)
        return session
    }

    // MARK: - Token refresh

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        let url = BackendConfig.supabaseURL
            .appendingPathComponent("auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])

        let payload: [String: Any] = ["refresh_token": refreshToken]
        let session = try await postToGoTrue(url: url, payload: payload)
        persist(session)
        return session
    }

    // MARK: - Shared GoTrue POST helper

    private func postToGoTrue(url: URL, payload: [String: Any]) async throws -> AuthSession {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(BackendConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? "Authentication failed"
            throw AuthServiceError.serverError(parseGoTrueError(text))
        }

        struct GoTrueResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let user: GoTrueUser
        }
        let decoded = try JSONDecoder().decode(GoTrueResponse.self, from: data)
        return AuthSession(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            userId: decoded.user.id,
            email: decoded.user.email
        )
    }

    // Extracts a human-readable message from GoTrue error JSON ({"error":"…","message":"…"})
    private func parseGoTrueError(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONDecoder().decode([String: String].self, from: data),
              let msg = json["message"] ?? json["error_description"] ?? json["error"]
        else { return raw }
        return msg
    }
}

// MARK: - Shared GoTrue user shape

private struct GoTrueUser: Decodable {
    let id: String
    let email: String?
}
