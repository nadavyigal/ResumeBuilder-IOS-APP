import Foundation

/// One person's answer to "your résumé and job text go to OpenAI" (App Review
/// 5.1.2(i): disclose third-party AI and get explicit permission first).
///
/// Scoped to the Supabase user id, so a second account on the same phone is
/// asked again instead of inheriting the first account's yes. A guest's
/// anonymous session keeps its user id when it becomes an account, so the
/// person who agreed as a guest is not asked twice. With no session at all the
/// identity is `guest`; when the anonymous session starts later, it takes over
/// that answer (`carryGuestConsent`). `AppState.signOut` clears every stored answer.
///
/// The key is versioned: if what is sent, or who receives it, changes, bump
/// `keyPrefix` and everyone is asked again.
@MainActor
struct AIConsentStore {
    static let keyPrefix = "ai_data_consent_v1"
    static let guestIdentity = "guest"

    let identity: String
    private let defaults: UserDefaults

    init(identity: String, defaults: UserDefaults = .standard) {
        self.identity = identity
        self.defaults = defaults
    }

    /// The identity for a session's user id; `guest` when there is none.
    static func identity(forUserId userId: String?) -> String {
        guard let userId, !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return guestIdentity
        }
        return userId
    }

    static func key(for identity: String) -> String {
        "\(keyPrefix).\(identity)"
    }

    var consentedAt: Date? {
        let key = Self.key(for: identity)
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    var hasConsented: Bool { consentedAt != nil }

    /// True until this identity agrees. Nothing that sends résumé, job or chat
    /// text to an OpenAI-backed endpoint may run while this is true.
    var needsConsentBeforeSending: Bool { !hasConsented }

    func recordConsent(at date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.key(for: identity))
    }

    /// Moves a `guest` yes to the anonymous session that started after it on
    /// this device: same phone, same person, no sign-in (#204). Keeps the date it
    /// was given. Never call this for a real account; that one must be asked.
    static func carryGuestConsent(to identity: String, defaults: UserDefaults = .standard) {
        let guestKey = key(for: guestIdentity)
        guard identity != guestIdentity, let givenAt = defaults.object(forKey: guestKey) else { return }
        let targetKey = key(for: identity)
        if defaults.object(forKey: targetKey) == nil {
            defaults.set(givenAt, forKey: targetKey)
        }
        defaults.removeObject(forKey: guestKey)
    }

    /// Removes every identity's answer, plus the unscoped key an unreleased
    /// build of this branch wrote. Called on sign-out and account deletion.
    static func clearAll(defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys
        where key == keyPrefix || key.hasPrefix(keyPrefix + ".") {
            defaults.removeObject(forKey: key)
        }
    }
}
