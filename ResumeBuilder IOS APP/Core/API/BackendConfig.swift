import Foundation

enum BackendConfig {
    /// Stage 1 ships without monetization. Flip to `true` once the backend
    /// credit ledger and StoreKit IAP wiring land in Stage 2.
    static let isMonetizationEnabled = false

    /// Sign in with Apple is hidden until the Apple provider is enabled in the
    /// Supabase dashboard (Authentication -> Providers -> Apple, with this
    /// app's bundle ID in Client IDs). The reviewer hit provider_disabled on
    /// 2026-06-10; email auth is the only sign-in until this flips to true.
    static let isAppleSignInEnabled = false

    // Supabase credentials — anon key is intentionally client-visible (same as NEXT_PUBLIC_*).
    // RLS policies enforce data isolation; the anon key alone grants no elevated access.
    static let supabaseURL = URL(string: "https://brtdyamysfmctrhuankn.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJydGR5YW15c2ZtY3RyaHVhbmtuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcyNDYwODQsImV4cCI6MjA3MjgyMjA4NH0.x7IhVevlwHqrhJOVtcLeX8U-fN-tSZn-0AcC1dsXuyU"

    static var apiBaseURL: URL {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !rawValue.isEmpty,
              let url = URL(string: rawValue) else {
            preconditionFailure("Missing or invalid API_BASE_URL in Info.plist")
        }
        return url
    }

    static var postHogAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return key
    }

    static var postHogHost: URL? {
        if let host = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String,
           let url = URL(string: host), !host.isEmpty {
            return url
        }
        return URL(string: "https://us.i.posthog.com")
    }

    static var isPostHogEnabled: Bool { postHogAPIKey != nil }
}
