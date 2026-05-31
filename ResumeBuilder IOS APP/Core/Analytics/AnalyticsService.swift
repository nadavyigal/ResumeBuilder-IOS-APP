import Foundation

/// Lightweight PostHog event capture via the HTTP /capture/ endpoint.
/// Uses URLSession directly — no SDK dependency required.
/// Mirrors the NEXT_PUBLIC_POSTHOG_KEY used in the web project (Project ID: 270848).
final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()

    private let captureURL: URL?
    private let apiKey: String
    private let session: URLSession

    private init() {
        apiKey = BackendConfig.posthogAPIKey
        captureURL = URL(string: BackendConfig.posthogHost + "/capture/")
        if captureURL == nil {
            assertionFailure("[Analytics] Invalid PostHog host — analytics disabled.")
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func capture(
        event: String,
        distinctId: String,
        properties: [String: Any] = [:]
    ) {
        var merged = baseProperties()
        merged.merge(properties) { _, new in new }

        let payload: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "distinct_id": distinctId,
            "properties": merged,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        guard let captureURL,
              let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: captureURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        session.dataTask(with: request) { _, response, error in
            if let error {
                print("⚠️ [Analytics] capture '\(event)' failed: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("⚠️ [Analytics] capture '\(event)' failed: HTTP \(http.statusCode)")
            }
        }.resume()
    }

    // MARK: - Private

    private func baseProperties() -> [String: Any] {
        let info = Bundle.main.infoDictionary
        return [
            "$os": "iOS",
            "$lib": "resumely-ios-urlsession",
            "app_version": info?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": info?["CFBundleVersion"] as? String ?? "unknown"
        ]
    }
}

// MARK: - Convenience helpers

extension AnalyticsService {
    func captureUploadResumeStarted(distinctId: String, hasJobURL: Bool) {
        capture(
            event: "upload_resume_started",
            distinctId: distinctId,
            properties: ["has_job_url": hasJobURL]
        )
    }

    func captureOptimizationCompleted(distinctId: String, optimizationId: String) {
        capture(
            event: "optimization_completed",
            distinctId: distinctId,
            properties: ["optimization_id": optimizationId]
        )
    }

    func captureExportTriggered(distinctId: String, optimizationId: String) {
        capture(
            event: "export_triggered",
            distinctId: distinctId,
            properties: ["optimization_id": optimizationId]
        )
    }
}
