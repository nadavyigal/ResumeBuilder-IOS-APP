import Foundation

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

    func supabaseIdentityDebugSummary(session: AuthSession?) -> String {
        let projectRef = BackendConfig.supabaseURL.host?
            .split(separator: ".")
            .first
            .map(String.init) ?? "unknown"
        let userId = session?.userId ?? "signed-out"
        return "API: \(baseURL.absoluteString) | Supabase project: \(projectRef) | User: \(userId)"
    }

    func postJSON<T: Decodable>(
        endpoint: Endpoint,
        body: [String: Any],
        token: String?
    ) async throws -> T {
        var request = URLRequest(url: url(for: endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await send(request)
    }

    func postCodable<T: Decodable, Body: Encodable>(
        endpoint: Endpoint,
        body: Body,
        token: String?
    ) async throws -> T {
        var request = URLRequest(url: url(for: endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        return try await send(request)
    }

    func get<T: Decodable>(endpoint: Endpoint, token: String?) async throws -> T {
        var request = URLRequest(url: url(for: endpoint))
        request.httpMethod = "GET"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
        var request = URLRequest(url: url(for: endpoint))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let sessionId, !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
        }

        let filename = fileURL.lastPathComponent
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        let fileData = try Data(contentsOf: fileURL)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"resume\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)

        for (name, value) in fields {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
        }
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIClientError.unauthorized
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIClientError.serverError(status: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func url(for endpoint: Endpoint) -> URL {
        URL(string: endpoint.path, relativeTo: baseURL)!.absoluteURL
    }
}
