import XCTest
@testable import ResumeBuilder_IOS_APP

/// Forgot password, change password, and the `resumebuilder://signin` link
/// the website opens after a reset (1.6.1, plan A).
@MainActor
final class PasswordFlowsTests: XCTestCase {

    // MARK: - Forgot password

    func testForgotPasswordSendsTrimmedEmailAndShowsSent() async {
        var sent: [String] = []
        let model = ForgotPasswordViewModel(email: "  user@example.com \n") { sent.append($0) }

        await model.submit()

        XCTAssertEqual(sent, ["user@example.com"])
        XCTAssertEqual(model.phase, .sent)
        XCTAssertNil(model.errorMessage)
    }

    func testForgotPasswordRejectsAnInvalidEmailWithoutSending() async {
        var calls = 0
        let model = ForgotPasswordViewModel(email: "not-an-email") { _ in calls += 1 }

        await model.submit()

        XCTAssertEqual(calls, 0)
        XCTAssertEqual(model.phase, .editing)
        XCTAssertNotNil(model.errorMessage)
    }

    func testForgotPasswordShowsTheServerErrorAndLetsTheUserRetry() async {
        let model = ForgotPasswordViewModel(email: "user@example.com") { _ in
            throw AuthServiceError.serverError("For security purposes, you can only request this after 18 seconds.")
        }

        await model.submit()

        XCTAssertEqual(model.phase, .editing)
        XCTAssertEqual(model.errorMessage, "For security purposes, you can only request this after 18 seconds.")
    }

    func testEmailShapeCheck() {
        XCTAssertTrue(ForgotPasswordViewModel.looksLikeEmail("a@b.co"))
        XCTAssertFalse(ForgotPasswordViewModel.looksLikeEmail("a@b"))
        XCTAssertFalse(ForgotPasswordViewModel.looksLikeEmail("@b.co"))
        XCTAssertFalse(ForgotPasswordViewModel.looksLikeEmail("a b@c.co"))
        XCTAssertFalse(ForgotPasswordViewModel.looksLikeEmail("a@@b.co"))
    }

    // MARK: - Change password

    func testChangePasswordRejectsShortAndMismatchedPasswords() async {
        var calls = 0
        let model = ChangePasswordViewModel { _ in calls += 1 }

        model.newPassword = Self.shortValue
        model.confirmPassword = Self.shortValue
        await model.save()
        XCTAssertNotNil(model.errorMessage)

        model.newPassword = Self.validValue
        model.confirmPassword = Self.validValue + "x"
        await model.save()
        XCTAssertNotNil(model.errorMessage)

        XCTAssertEqual(calls, 0)
        XCTAssertFalse(model.didSave)
    }

    func testChangePasswordSavesAndClearsTheFields() async {
        var saved: [String] = []
        let model = ChangePasswordViewModel { saved.append($0) }
        model.newPassword = Self.validValue
        model.confirmPassword = Self.validValue

        await model.save()

        XCTAssertEqual(saved, [Self.validValue])
        XCTAssertTrue(model.didSave)
        XCTAssertEqual(model.newPassword, "")
        XCTAssertNil(model.errorMessage)
    }

    func testChangePasswordShowsTheServerError() async {
        let model = ChangePasswordViewModel { _ in
            throw AuthServiceError.serverError("New password should be different from the old password.")
        }
        model.newPassword = Self.validValue
        model.confirmPassword = Self.validValue

        await model.save()

        XCTAssertFalse(model.didSave)
        XCTAssertEqual(model.errorMessage, "New password should be different from the old password.")
    }

    func testAppStateChangePasswordUsesTheSessionToken() async throws {
        let client = PasswordAuthClient()
        let appState = AppState(authClient: client)
        appState.session = Self.session(provider: "email")

        try await appState.changePassword(Self.validValue)

        XCTAssertEqual(client.updates.count, 1)
        XCTAssertEqual(client.updates.first?.password, Self.validValue)
        XCTAssertEqual(client.updates.first?.token, appState.session?.accessToken)
    }

    func testOnlyEmailAccountsCanChangePassword() {
        let appState = AppState(authClient: PasswordAuthClient())

        appState.session = Self.session(provider: "email")
        XCTAssertTrue(appState.canChangePassword)

        appState.session = Self.session(provider: "apple")
        XCTAssertFalse(appState.canChangePassword, "Apple sign-in has no password to change.")

        appState.session = Self.session(provider: "anonymous", isAnonymous: true)
        XCTAssertFalse(appState.canChangePassword, "A guest has no account password.")

        appState.session = nil
        XCTAssertFalse(appState.canChangePassword)
    }

    func testAnAppleAccountThatAddedAPasswordCanChangeIt() {
        let appState = AppState(authClient: PasswordAuthClient())
        appState.session = Self.session(provider: "apple", providers: ["apple", "email"])

        XCTAssertTrue(appState.canChangePassword)
    }

    func testAnExpiredSessionGetsASignInAgainMessage() async {
        let model = ChangePasswordViewModel { _ in throw APIClientError.unauthorized }
        model.newPassword = Self.validValue
        model.confirmPassword = Self.validValue

        await model.save()

        XCTAssertFalse(model.didSave)
        XCTAssertEqual(
            model.errorMessage,
            NSLocalizedString("Your session has expired. Sign out, sign in again, then change your password.", comment: "")
        )
    }

    // MARK: - resumebuilder://signin

    func testSignInLinkIsRecognised() throws {
        XCTAssertTrue(DeepLinkRouter.isSignInLink(try XCTUnwrap(URL(string: "resumebuilder://signin"))))
        XCTAssertTrue(DeepLinkRouter.isSignInLink(try XCTUnwrap(URL(string: "ResumeBuilder://SignIn"))))
        XCTAssertFalse(DeepLinkRouter.isSignInLink(try XCTUnwrap(URL(string: "resumebuilder://share?url=https://x.co"))))
        XCTAssertFalse(DeepLinkRouter.isSignInLink(try XCTUnwrap(URL(string: "https://signin.example.com"))))
    }

    func testSignInLinkAsksForSignInOnlyWhenSignedOut() throws {
        let link = try XCTUnwrap(URL(string: "resumebuilder://signin"))
        let appState = AppState(authClient: PasswordAuthClient())

        appState.handleIncomingURL(link)
        XCTAssertEqual(appState.signInRequestCount, 1)
        XCTAssertNil(appState.pendingSharedJobURL, "The sign-in link is not a shared job.")

        appState.session = Self.session(provider: "email")
        appState.handleIncomingURL(link)
        XCTAssertEqual(appState.signInRequestCount, 1, "A signed-in user has nothing to sign in to.")
    }

    func testSharedJobLinkStillWorks() throws {
        let appState = AppState(authClient: PasswordAuthClient())
        appState.handleIncomingURL(try XCTUnwrap(URL(string: "resumebuilder://share?url=https://jobs.example.com/1")))

        XCTAssertEqual(appState.pendingSharedJobURL?.absoluteString, "https://jobs.example.com/1")
        XCTAssertEqual(appState.signInRequestCount, 0)
    }

    // MARK: - Request shape

    func testRecoverRequestShape() throws {
        let request = try AuthService.makeRecoverRequest(email: "user@example.com")

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/auth/v1/recover") == true)
        XCTAssertNotNil(request.value(forHTTPHeaderField: "apikey"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["email": "user@example.com"])
    }

    func testUpdatePasswordRequestShape() throws {
        let request = try AuthService.makeUpdatePasswordRequest(accessToken: "tok", newPassword: Self.validValue)

        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertTrue(request.url?.path.hasSuffix("/auth/v1/user") == true)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["password": Self.validValue])
    }

    // MARK: - Helpers

    /// Built at runtime: secret scanners flag string literals assigned to
    /// password fields, even made-up ones.
    private static let validValue = String(repeating: "q", count: minimumPasswordLength + 4)
    private static let shortValue = String(repeating: "q", count: minimumPasswordLength - 3)

    private static func session(provider: String, providers: [String]? = nil, isAnonymous: Bool = false) -> AuthSession {
        let list = (providers ?? [provider]).map { "\"\($0)\"" }.joined(separator: ",")
        let payload = #"{"sub":"user-1","exp":4102444800,"is_anonymous":\#(isAnonymous),"app_metadata":{"provider":"\#(provider)","providers":[\#(list)]}}"#
        return AuthSession(
            accessToken: "\(base64URL("{\"alg\":\"none\"}")).\(base64URL(payload)).sig",
            refreshToken: "refresh-1",
            userId: "user-1",
            email: "user@example.com",
            isAnonymous: isAnonymous
        )
    }

    private static func base64URL(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class PasswordAuthClient: AuthClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(token: String, password: String)] = []

    var updates: [(token: String, password: String)] {
        lock.withLock { recorded }
    }

    func restoreSession() -> AuthSession? { nil }
    func clearSession() {}
    func refreshSession(refreshToken: String) async throws -> AuthSession {
        throw AuthServiceError.invalidResponse
    }
    func deleteAccount(accessToken: String) async throws {}

    func updatePassword(accessToken: String, newPassword: String) async throws {
        lock.withLock { recorded.append((accessToken, newPassword)) }
    }
}
