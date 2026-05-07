import Foundation

enum BackendConfig {
    /// Stage 1 ships without monetization. Flip to `true` once the backend
    /// credit ledger and StoreKit IAP wiring land in Stage 2.
    static let isMonetizationEnabled = false

    // Supabase credentials — anon key is intentionally client-visible (same as NEXT_PUBLIC_*).
    // RLS policies enforce data isolation; the anon key alone grants no elevated access.
    static let supabaseURL = URL(string: "https://brtdyamysfmctrhuankn.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJydGR5YW15c2ZtY3RyaHVhbmtuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcyNDYwODQsImV4cCI6MjA3MjgyMjA4NH0.x7IhVevlwHqrhJOVtcLeX8U-fN-tSZn-0AcC1dsXuyU"

    static var apiBaseURL: URL {
        if let override = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        return URL(string: "https://www.resumelybuilderai.com")!
    }
}
