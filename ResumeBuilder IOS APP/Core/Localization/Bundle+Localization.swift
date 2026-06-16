//
//  Bundle+Localization.swift
//  ResumeBuilder IOS APP
//
//  Runtime language override. Swaps the class of `Bundle.main` to a subclass
//  that resolves `localizedString(forKey:)` against a chosen `.lproj` bundle.
//  This makes `String(localized:)` / NSLocalizedString lookups honor the
//  user-selected language without an app restart. SwiftUI `Text` lookups are
//  additionally driven by `.environment(\.locale, ...)` at the app root.
//

import Foundation
import ObjectiveC

private nonisolated(unsafe) var localizedBundleKey: UInt8 = 0

/// A `Bundle` subclass that forwards localized-string lookups to the bundle of
/// the currently selected language, falling back to the default behavior.
/// Marked `nonisolated` so its implicit initializers match `Bundle`'s
/// nonisolated designated initializers under the module's default actor isolation.
private nonisolated final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard
            let path = objc_getAssociatedObject(self, &localizedBundleKey) as? String,
            let bundle = Bundle(path: path)
        else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Installs the language-override on `Bundle.main` and points it at the
    /// `<language>.lproj` bundle. Idempotent: safe to call on every switch.
    static func setAppLanguage(_ language: String) {
        // Swap the class once so localizedString(forKey:) is intercepted.
        if !(Bundle.main is LocalizedBundle) {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        objc_setAssociatedObject(
            Bundle.main,
            &localizedBundleKey,
            path,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}
