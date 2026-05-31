import Foundation

/// Pure account display labels for Me tab — testable without SwiftUI.
enum AccountDisplayInfo: Equatable, Sendable {
    case guest
    case authenticated(email: String, initials: String)

    static func resolve(isAuthenticated: Bool, email: String?) -> AccountDisplayInfo {
        guard isAuthenticated else { return .guest }
        let resolvedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayEmail = resolvedEmail.isEmpty ? "Account" : resolvedEmail
        return .authenticated(email: displayEmail, initials: initials(from: displayEmail))
    }

    var title: String {
        switch self {
        case .guest: return "Guest mode"
        case .authenticated(let email, _): return email
        }
    }

    var subtitle: String {
        switch self {
        case .guest:
            return "Sign in to save optimizations and export PDFs"
        case .authenticated:
            return "Active account"
        }
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
