//
//  LocalizationManager.swift
//  ResumeBuilder IOS APP
//
//  Owns the app's selected language. On first launch it auto-detects the
//  device language (Hebrew → Hebrew, otherwise English). The user's explicit
//  choice from the Home tab is persisted in UserDefaults and applied at runtime
//  without an app restart.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
        case english = "en"
        case hebrew = "he"

        var id: String { rawValue }

        /// Display name shown in the picker, in the language's own script.
        var displayName: String {
            switch self {
            case .english: return "English"
            case .hebrew: return "עברית"
            }
        }
    }

    private static let storageKey = "app_selected_language"

    /// The active language. Changing it persists the choice and re-applies the
    /// bundle override; SwiftUI re-renders via `@Observable`.
    private(set) var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            Bundle.setAppLanguage(language.rawValue)
        }
    }

    /// Locale to inject into the SwiftUI environment so `Text` catalog lookups
    /// resolve to the selected language.
    var locale: Locale {
        Locale(identifier: language.rawValue)
    }

    /// Layout direction for the SwiftUI environment (RTL for Hebrew).
    var layoutDirection: LayoutDirection {
        language == .hebrew ? .rightToLeft : .leftToRight
    }

    /// Whether the user has explicitly chosen a language (vs. auto-detected).
    var hasExplicitChoice: Bool {
        UserDefaults.standard.string(forKey: Self.storageKey) != nil
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let lang = AppLanguage(rawValue: stored) {
            language = lang
        } else {
            // First launch: default to device language if it is Hebrew.
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("he") ? .hebrew : .english
        }
        Bundle.setAppLanguage(language.rawValue)
    }

    /// Switch the app language live and persist the explicit choice.
    func setLanguage(_ newLanguage: AppLanguage) {
        UserDefaults.standard.set(newLanguage.rawValue, forKey: Self.storageKey)
        language = newLanguage
    }
}
