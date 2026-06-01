import Foundation

protocol AnalyticsTransport: Sendable {
    func capture(event: String, properties: [String: String], distinctId: String) async throws
}

struct PostHogAnalyticsTransport: AnalyticsTransport, Sendable {
    private let apiKey: String
    private let host: URL
    private let session: URLSession

    init(apiKey: String, host: URL, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.host = host
        self.session = session
    }

    func capture(event: String, properties: [String: String], distinctId: String) async throws {
        var request = URLRequest(url: host.appendingPathComponent("capture"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "distinct_id": distinctId,
            "properties": properties.merging([
                "$lib": "resumely-ios-urlsession",
            ]) { current, _ in current },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AnalyticsError.transportFailed
        }
    }
}

enum AnalyticsError: Error, Equatable {
    case transportFailed
    case disabled
}

enum AnalyticsEvent: Sendable {
    case appLaunched(isAuthenticated: Bool)
    case guestModeStarted
    case resumeUploaded
    case jobAdded(hasURL: Bool, hasPaste: Bool)
    case freeATSCompleted(scoreBucket: String)
    case signInCompleted
    case optimizationStarted
    case optimizationCompleted
    case exportStarted
    case exportSuccess
    case exportFailed(errorCode: String)

    nonisolated var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .guestModeStarted: return "guest_mode_started"
        case .resumeUploaded: return "resume_uploaded"
        case .jobAdded: return "job_added"
        case .freeATSCompleted: return "free_ats_completed"
        case .signInCompleted: return "sign_in_completed"
        case .optimizationStarted: return "optimization_started"
        case .optimizationCompleted: return "optimization_completed"
        case .exportStarted: return "export_started"
        case .exportSuccess: return "export_success"
        case .exportFailed: return "export_failed"
        }
    }

    nonisolated var properties: [String: String] {
        switch self {
        case .appLaunched(let isAuthenticated):
            return ["is_authenticated": isAuthenticated ? "true" : "false"]
        case .guestModeStarted, .resumeUploaded, .signInCompleted,
             .optimizationStarted, .optimizationCompleted, .exportStarted, .exportSuccess:
            return [:]
        case .jobAdded(let hasURL, let hasPaste):
            return [
                "has_url": hasURL ? "true" : "false",
                "has_paste": hasPaste ? "true" : "false",
            ]
        case .freeATSCompleted(let scoreBucket):
            return ["score_bucket": scoreBucket]
        case .exportFailed(let errorCode):
            return ["error_code": errorCode]
        }
    }

    static func scoreBucket(for score: Int) -> String {
        switch score {
        case ...40: return "0-40"
        case 41...60: return "41-60"
        case 61...80: return "61-80"
        default: return "81-100"
        }
    }
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let transport: (any AnalyticsTransport)?
    private let distinctIdProvider: () -> String
    nonisolated static let distinctIdKey = "analytics_distinct_id"

    init(
        transport: (any AnalyticsTransport)? = nil,
        distinctIdProvider: (() -> String)? = nil
    ) {
        if let transport {
            self.transport = transport
        } else if BackendConfig.isPostHogEnabled,
                  let key = BackendConfig.postHogAPIKey,
                  let host = BackendConfig.postHogHost {
            self.transport = PostHogAnalyticsTransport(apiKey: key, host: host)
        } else {
            self.transport = nil
        }
        self.distinctIdProvider = distinctIdProvider ?? {
            if let existing = UserDefaults.standard.string(forKey: AnalyticsService.distinctIdKey),
               !existing.isEmpty {
                return existing
            }
            let created = UUID().uuidString
            UserDefaults.standard.set(created, forKey: AnalyticsService.distinctIdKey)
            return created
        }
    }

    var isEnabled: Bool { transport != nil }

    func setDistinctId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.distinctIdKey)
    }

    func track(_ event: AnalyticsEvent) {
        guard let transport else { return }
        let distinctId = distinctIdProvider()
        let payload = event.properties
        // Guard PII at the call site — fire in debug builds so new event cases
        // are caught during development before any key ever reaches the network.
        assert(
            Set(payload.keys).isDisjoint(with: Self.forbiddenPropertyKeys),
            "[Analytics] Event '\(event.name)' contains a forbidden property key. Remove PII before shipping."
        )
        #if DEBUG
        print("Analytics captured: \(event.name)")
        #endif
        Task {
            do {
                try await transport.capture(
                    event: event.name,
                    properties: payload,
                    distinctId: distinctId
                )
            } catch {
                // Analytics must never block user flows.
            }
        }
    }

    nonisolated static func buildCapturePayload(
        apiKey: String,
        event: AnalyticsEvent,
        distinctId: String
    ) -> [String: Any] {
        [
            "api_key": apiKey,
            "event": event.name,
            "distinct_id": distinctId,
            "properties": event.properties.merging(["$lib": "resumely-ios-urlsession"]) { current, _ in current },
        ]
    }

    nonisolated static let forbiddenPropertyKeys: Set<String> = [
        "email", "name", "resume", "job", "job_description", "resume_text", "file_name",
    ]
}
