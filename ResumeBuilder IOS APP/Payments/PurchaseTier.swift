// ResumeBuilder IOS APP/Payments/PurchaseTier.swift
// Plan 3: StoreKit Paywall — purchase tier definitions
//
// Product IDs must be created in App Store Connect → In-App Purchases before this compiles cleanly.
// Prices set in App Store Connect only — never hardcoded here (see PaywallView).

import Foundation

enum PurchaseTier: CaseIterable {
    case singleExport
    case pack5
    case pack10
    case unlimitedMonthly
    case unlimitedAnnual

    var productID: String {
        switch self {
        case .singleExport: return "com.resumely.export.single"
        case .pack5: return "com.resumely.export.pack5"
        case .pack10: return "com.resumely.export.pack10"
        case .unlimitedMonthly: return "com.resumely.unlimited.monthly"
        case .unlimitedAnnual: return "com.resumely.unlimited.annual"
        }
    }

    var displayName: String {
        switch self {
        case .singleExport: return "Single Export"
        case .pack5: return "5-Export Pack"
        case .pack10: return "10-Export Pack"
        case .unlimitedMonthly: return "Unlimited Monthly"
        case .unlimitedAnnual: return "Unlimited Annual"
        }
    }

    var creditsGranted: Int {
        switch self {
        case .singleExport: return 1
        case .pack5: return 5
        case .pack10: return 10
        case .unlimitedMonthly, .unlimitedAnnual: return 0 // unlimited flag, not credits
        }
    }

    var isMostPopular: Bool {
        return self == .pack5
    }

    var isSubscription: Bool {
        return self == .unlimitedMonthly || self == .unlimitedAnnual
    }
}
