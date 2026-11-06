import Foundation

/// Decodes JWT payload fields for client-side expiry gating only — no signature verification.
enum JWTDecoder: Sendable {
    static func expirationDate(from jwt: String) -> Date? {
        guard let exp = payload(from: jwt)?["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// Supabase's `is_anonymous` claim, or nil when the token has no such claim
    /// or cannot be read. Used only to repair a saved session's flag on restore.
    static func isAnonymous(from jwt: String) -> Bool? {
        payload(from: jwt)?["is_anonymous"] as? Bool
    }

    /// Whether the account has an email-and-password identity. Supabase puts
    /// the first sign-in provider in `app_metadata.provider` and every linked
    /// one in `app_metadata.providers`, so an Apple account that later added a
    /// password still counts. Only decides whether Me offers "Change Password".
    static func hasEmailPasswordIdentity(from jwt: String) -> Bool {
        guard let metadata = payload(from: jwt)?["app_metadata"] as? [String: Any] else { return false }
        if metadata["provider"] as? String == "email" { return true }
        return (metadata["providers"] as? [String])?.contains("email") == true
    }

    private static func payload(from jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = base64URLDecode(String(parts[1]))
        else { return nil }
        return try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
    }

    /// Returns true when the access token is missing, unparsable, or expires within `leeway` seconds.
    static func shouldRefresh(accessToken: String, leeway: TimeInterval = 300, now: Date = Date()) -> Bool {
        guard let expiration = expirationDate(from: accessToken) else { return true }
        return expiration.timeIntervalSince(now) <= leeway
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}
