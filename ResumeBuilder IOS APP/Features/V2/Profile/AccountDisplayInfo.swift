import Foundation

/// Pure account display labels for Me tab — testable without SwiftUI.
enum AccountDisplayInfo: Equatable, Sendable {
    case guest
    case authenticated(email: String, initials: String)

    static func resolve(isAuthenticated: Bool, email: String?) -> AccountDisplayInfo {
        guard isAuthenticated else { return .guest }
        let resolvedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayEmail = resolvedEmail.isEmpty ? NSLocalizedString("Account", comment: "") : resolvedEmail
        return .authenticated(email: displayEmail, initials: initials(from: displayEmail))
    }

    var title: String {
        switch self {
        case .guest: return NSLocalizedString("Guest mode", comment: "")
        case .authenticated(let email, _): return email
        }
    }

    var subtitle: String {
        switch self {
        case .guest:
            return NSLocalizedString("Sign in to save optimizations and sync across devices", comment: "")
        case .authenticated:
            return NSLocalizedString("Active account", comment: "")
        }
    }

    /// Body copy for the guest sign-in value card in the Me tab.
    ///
    /// Lives here rather than inline in `ProfileView` so the claims it makes are
    /// testable without SwiftUI, like every other label in this type.
    ///
    /// Names only what an account actually adds. Export is deliberately absent:
    /// `ResumeExportAction.exportPDF` gates on `optimizationIdentifier` alone,
    /// `BackendConfig.isMonetizationEnabled` is false, and Home routes anonymous
    /// sessions through on `canOptimize` — so a guest shown this card can
    /// already export, and telling them otherwise costs the export the north
    /// star measures (WP-75 S4).
    static var guestValueProposition: String {
        NSLocalizedString(
            "Create a free account to save every optimization and sync across devices.",
            comment: "Guest sign-in value card body"
        )
    }

    var showsSignIn: Bool {
        if case .guest = self { return true }
        return false
    }

    var showsSignOut: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var avatarInitials: String {
        switch self {
        case .guest: return "G"
        case .authenticated(_, let initials): return initials
        }
    }

    private static func initials(from email: String) -> String {
        let parts = email.split(separator: "@").first?.split(separator: ".") ?? []
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "R" : String(joined.prefix(2))
    }
}
