import Foundation

enum BackendConfig {
    /// Fit-First Triage — paste a JD before optimizing, get a Strong/Stretch/Skip verdict.
    /// Disabled 2026-07-24 (WP-45 S6). Was enabled 2026-06-24 (v1.1 build 6).
    ///
    /// The Fit screen asked for the same intent twice. The user had already
    /// chosen the role, supplied its data and tapped Analyze; the screen then
    /// repeated the job input, added a second CTA, and delivered a verdict
    /// before the product had done anything for them.
    ///
    /// The verdict was also not fit to carry that decision. Its bands are
    /// strong >= 75 and stretch >= 50, but over 60 days the free checker's mean
    /// was 34.5 with a maximum of 51 — so 76% of users were told to skip the
    /// job, "strong" was never once awarded, and a moderated session on
    /// 2026-07-24 watched a real user meet a 45 before seeing any value.
    ///
    /// With this off, both entry points run the direct path that already
    /// exists below, and analytics report flow_version=direct_optimize_v2.
    /// The Fit surfaces stay in the binary for the public web checker and are
    /// removed once the release readout is clean (WP-45 S10).
    static let isFitCheckEnabled = false

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
