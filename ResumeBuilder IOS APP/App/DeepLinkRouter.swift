import Foundation

enum DeepLinkRouter {
    /// `resumebuilder://signin`, opened by the website after a password reset.
    static func isSignInLink(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "resumebuilder" && url.host?.lowercased() == "signin"
    }

    /// `resumebuilder://share?url=<job posting>`. Only that exact shape, and only
    /// an http(s) job link, becomes a pending shared job. The old check used `||`,
    /// so any URL whose host was `share` passed, whatever its scheme.
    static func parseSharedJobURL(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == "resumebuilder",
              url.host?.lowercased() == "share" else { return nil }

        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value,
              let extractedURL = URL(string: value),
              let scheme = extractedURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }

        return extractedURL
    }
}
