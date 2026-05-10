import Foundation
import OSLog

enum APIClientError: Error, LocalizedError {
    case unauthorized
    case serverError(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized"
        case .serverError(let status, let message):
            return "Server error (\(status)): \(message)"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

struct APIClient {
    var baseURL: URL = BackendConfig.apiBaseURL
    var session: URLSession = .shared
    var requestTimeout: TimeInterval = 30
    private let logger = Logger(subsystem: "ResumeBuilder", category: "APIClient")

    // Long-lived session for upload-resume: AI optimization can take 60-90s.
    private static let uploadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    func supabaseIdentityDebugSummary(session: AuthSession?) -> String {
        let projectRef = BackendConfig.supabaseURL.host?
            .components(separatedBy: ".")
            .first ?? "unknown"
        return "Supabase: \(projectRef)\nUser: \(session?.userId ?? "not signed in")"
    }

    func postJSON<T: Decodable>(
        endpoint: Endpoint,
        body: [String: Any],
        token: String?
    ) async throws -> T {
        var request = URLRequest(url: url(for: endpoint), timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await send(request)
    }

    /// Chat & other endpoints that encode arrays of heterogeneous field objects reliably via `Any`.
    func postJSONObject<T: Decodable>(
        endpoint: Endpoint,
        bodyObject: [String: Any],
        token: String?,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        var request = URLRequest(url: url(for: endpoint), timeoutInterval: timeout ?? requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyObject)
        return try await send(request)
    }

    func get<T: Decodable>(endpoint: Endpoint, token: String?) async throws -> T {
        var request = URLRequest(url: url(for: endpoint), timeoutInterval: requestTimeout)
        request.httpMethod = "GET"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await send(request)
    }

    func getWithQuery<T: Decodable>(endpoint: Endpoint, token: String?) async throws -> T {
        var components = URLComponents(
            url: url(for: endpoint),
            resolvingAgainstBaseURL: false
        )
        let items = endpoint.queryItems
        if !items.isEmpty { components?.queryItems = items }
        let url = components?.url ?? url(for: endpoint)
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "GET"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await send(request)
    }

    func getData(endpoint: Endpoint, token: String?) async throws -> Data {
        var request = URLRequest(url: url(for: endpoint), timeoutInterval: requestTimeout)
        request.httpMethod = "GET"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        if httpResponse.statusCode == 401 { throw APIClientError.unauthorized }
        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIClientError.serverError(status: httpResponse.statusCode, message: message)
        }
        return data
    }

    func deleteJSON<T: Decodable>(
        endpoint: Endpoint,
        body: [String: Any],
        token: String?
    ) async throws -> T {
        var request = URLRequest(url: url(for: endpoint))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await send(request)
    }

    func uploadResume(
        fileURL: URL,
        jobDescription: String? = nil,
        jobDescriptionURL: String? = nil,
        token: String?
    ) async throws -> ResumeUploadResponse {
        try await uploadMultipart(
            endpoint: .uploadResume,
            fileURL: fileURL,
            token: token,
            sessionId: nil,
            fields: [
                "jobDescription": jobDescription,
                "jobDescriptionUrl": jobDescriptionURL,
            ]
        )
    }

    func runPublicATSCheck(
        resumeURL: URL,
        jobDescription: String?,
        jobDescriptionURL: String?,
        sessionId: String?
    ) async throws -> ATSScoreResult {
        try await uploadMultipart(
            endpoint: .publicATSCheck,
            fileURL: resumeURL,
            token: nil,
            sessionId: sessionId,
            fields: [
                "jobDescription": jobDescription,
                "jobDescriptionUrl": jobDescriptionURL,
            ]
        )
    }

    private func uploadMultipart<T: Decodable>(
        endpoint: Endpoint,
        fileURL: URL,
        token: String?,
        sessionId: String?,
        fields: [String: String?]
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(for: endpoint), timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        }

        let filename = fileURL.lastPathComponent
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        let fileData = try await Task.detached(priority: .userInitiated) {
            defer { if didAccess { fileURL.stopAccessingSecurityScopedResource() } }
            return try Data(contentsOf: fileURL)
        }.value

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"resume\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)

        for (name, value) in fields {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
        }
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return try await send(request, using: Self.uploadSession)
    }

    private func send<T: Decodable>(_ request: URLRequest, using urlSession: URLSession? = nil) async throws -> T {
        let activeSession = urlSession ?? session
        logger.info("HTTP start \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "unknown-url")")
        let (data, response) = try await activeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("HTTP invalid response for \(request.url?.absoluteString ?? "unknown-url")")
            throw APIClientError.invalidResponse
        }
        logger.info("HTTP response status=\(httpResponse.statusCode) bytes=\(data.count)")

        if httpResponse.statusCode == 401 {
            throw APIClientError.unauthorized
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("HTTP failure status=\(httpResponse.statusCode) message=\(message)")
            throw APIClientError.serverError(status: httpResponse.statusCode, message: message)
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            logger.info("HTTP decode success for \(request.url?.lastPathComponent ?? "unknown-endpoint")")
            return decoded
        } catch {
            logger.error("HTTP decode failure: \(error.localizedDescription)")
            throw error
        }
    }

    private func url(for endpoint: Endpoint) -> URL {
        URL(string: endpoint.path, relativeTo: baseURL)!.absoluteURL
    }
}
