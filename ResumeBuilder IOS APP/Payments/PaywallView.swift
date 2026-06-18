// ResumeBuilder IOS APP/Payments/PaywallView.swift
// Plan 3: StoreKit Paywall — purchase sheet presented at export
//
// SKELETON — implement when gate opens (EXD-009).
//
// UX spec:
//   - Presented as .sheet from the export button tap
//   - 4 tier cards (singleExport, pack5, pack10, unlimitedMonthly) in vertical scroll
//   - pack5 card shows "MOST POPULAR" badge
//   - Prices loaded from StoreKit product.displayPrice — NEVER hardcoded
//   - "Restore Purchases" link at bottom
//   - Dismiss (X) button top right
//   - On purchase success: dismiss sheet, proceed with export

import SwiftUI
import StoreKit

struct StoreKitPaywallDraftView: View {
    @Environment(StoreManager.self) private var storeManager
    var onPurchaseComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // TODO: Implement
        Text("Paywall — coming soon")
    }
}
