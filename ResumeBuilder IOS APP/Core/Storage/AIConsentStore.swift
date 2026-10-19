import Foundation

/// The user's answer to "your résumé and job text go to OpenAI" (App Review
/// 5.1.2(i): disclose third-party AI and get explicit permission first).
///
/// Stored per device as the date the user agreed. The key is versioned: if what
/// is sent, or who receives it, changes, bump the key and everyone is asked again.
@MainActor
struct AIConsentStore {
    static let key = "ai_data_consent_v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var consentedAt: Date? {
        guard defaults.object(forKey: Self.key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: Self.key))
    }

    var hasConsented: Bool { consentedAt != nil }

    /// True until the user agrees. Nothing that sends résumé or job text may run
    /// while this is true.
    var needsConsentBeforeSending: Bool { !hasConsented }

    func recordConsent(at date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.key)
    }
}
