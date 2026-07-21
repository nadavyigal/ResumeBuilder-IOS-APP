import Foundation

/// Links to the live legal pages on the product web domain.
/// Derived from `API_BASE_URL` so every environment points at its own host.
enum LegalLinks {

    static func privacyURL(language: LocalizationManager.AppLanguage) -> URL {
        pageURL(path: "privacy", language: language)
    }

    static func termsURL(language: LocalizationManager.AppLanguage) -> URL {
        pageURL(path: "terms", language: language)
    }

    private static func pageURL(path: String, language: LocalizationManager.AppLanguage) -> URL {
        var url = BackendConfig.apiBaseURL
        if language != .english {
            url.append(path: language.rawValue)
        }
        url.append(path: path)
        return url
    }
}
