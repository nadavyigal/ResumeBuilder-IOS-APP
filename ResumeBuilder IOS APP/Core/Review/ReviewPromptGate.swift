import Foundation

@MainActor
protocol ReviewPromptVersionStoring {
    func requestedVersion() -> String?
    func saveRequestedVersion(_ version: String) throws
}

@MainActor
struct KeychainReviewPromptVersionStore: ReviewPromptVersionStoring {
    private let service: String
    private let account: String
    private let keychain: KeychainStore

    init(
        service: String = "\(Bundle.main.bundleIdentifier ?? "com.resumely.app").review-prompt",
        account: String = "requested-app-version",
        keychain: KeychainStore = .shared
    ) {
        self.service = service
        self.account = account
        self.keychain = keychain
    }

    func requestedVersion() -> String? {
        guard let data = keychain.read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveRequestedVersion(_ version: String) throws {
        try keychain.save(Data(version.utf8), service: service, account: account)
    }
}

@MainActor
struct ReviewPromptGate {
    private let store: any ReviewPromptVersionStoring
    private let appVersion: String
    private let isInternalTester: Bool

    init(
        store: any ReviewPromptVersionStoring = KeychainReviewPromptVersionStore(),
        appVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown",
        isInternalTester: Bool = AnalyticsService.resolveInternalTester(
            userId: UserDefaults.standard.string(forKey: AnalyticsService.authenticatedUserIdKey)
        )
    ) {
        self.store = store
        self.appVersion = appVersion
        self.isInternalTester = isInternalTester
    }

    func claimAfterSuccessfulExport(hasCompletedExport: Bool) -> Bool {
        guard hasCompletedExport,
              !isInternalTester,
              appVersion != "unknown",
              store.requestedVersion() != appVersion
        else {
            return false
        }

        do {
            try store.saveRequestedVersion(appVersion)
            return true
        } catch {
            // A failed durable claim must not issue a prompt that could repeat indefinitely.
            return false
        }
    }
}
