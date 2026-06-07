// ResumeBuilder IOS APP/Payments/CreditManager.swift
// Plan 3: StoreKit Paywall — local credit cache + Supabase sync
//
// SKELETON — implement when gate opens (EXD-009).
//
// Architecture:
//   - Fetches user_credits row from Supabase on app launch and after purchase
//   - Caches export_credits and is_unlimited locally (@Observable)
//   - hasCredits() → true if export_credits > 0 OR is_unlimited
//   - consumeCredit() → decrements export_credits locally + Supabase (via consume_credit RPC)

import Foundation

@MainActor
@Observable
final class CreditManager {
    var exportCredits: Int = 0
    var isUnlimited: Bool = false
    var unlimitedExpiresAt: Date?

    var hasCredits: Bool {
        isUnlimited || exportCredits > 0
    }

    func fetchCredits(userID: String) async {
        // TODO: Implement
        // Fetch user_credits row from Supabase where user_id = userID
        // Update exportCredits, isUnlimited, unlimitedExpiresAt
    }

    func consumeCredit(userID: String) async -> Bool {
        // TODO: Implement
        // Call Supabase consume_credit RPC
        // On success: decrement exportCredits locally, return true
        // On failure (no credits): return false
        return false
    }
}
