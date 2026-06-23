import Foundation

enum BackendConfig {
    /// Fit-First Triage — paste a JD before optimizing, get a Strong/Stretch/Skip verdict.
    /// Default OFF; flip in a future build once QA passes on both iPhone 17 and SE.
    /// TODO(WP-12-FIT): enable after simulator smoke + A/B gate decision.
    static let isFitCheckEnabled = true

    /// Stage 1 ships without monetization. Flip to `true` once the backend
    /// credit ledger and StoreKit IAP wiring land in Stage 2.
    /// TODO(Stage2-RES-MONETIZATION): enable after sandbox IAP QA passes.
    static let isMonetizationEnabled = false

    /// Sign in with Apple is hidden until the Apple provider is enabled in the
    /// Supabase dashboard (Authentication -> Providers -> Apple, with this
    /// app's bundle ID in Client IDs). The reviewer hit provider_disabled on
    /// 2026-06-10; email auth is the only sign-in until this flips to true.
    static let isAppleSignInEnabled = false

    static let supabaseURL = URL(string: "https://brtdyamysfmctrhuankn.supabase.co")!

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            preconditionFailure("Missing or invalid SUPABASE_ANON_KEY in Info.plist")
        }
        return key
    }

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
