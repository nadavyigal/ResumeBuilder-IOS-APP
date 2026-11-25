import Foundation

enum ChatServiceError: LocalizedError, Sendable {
    case missingToken
    case missingOptimizationId
    case encodePayloadFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return NSLocalizedString("Sign in required to chat.", comment: "")
        case .missingOptimizationId:
            return NSLocalizedString("Optimization is not ready yet.", comment: "")
        case .encodePayloadFailed:
            return NSLocalizedString("Could not serialize change fields.", comment: "")
        }
    }
}

protocol ChatMessaging: Sendable {
    func approveChange(
        optimizationId: String,
        suggestionId: String,
        affectedFields: [ChatAffectedField]?,
        token: String?
    ) async throws -> ChatApproveChangeResponseDTO
    func previewKeywordSuggestion(
        optimizationId: String,
        suggestionId: String,
        token: String?
    ) async throws -> KeywordSuggestionPreviewDTO
}

/// Native client for authenticated chat (`/api/v1/chat`).
struct ChatService: ChatMessaging, Sendable {
    var apiClient: APIClient = RuntimeServices.sharedAPIClient

    // MARK: - Pending ATS changes

    func approveChange(
        optimizationId: String,
        suggestionId: String,
        affectedFields: [ChatAffectedField]?,
        token: String?
    ) async throws -> ChatApproveChangeResponseDTO {
        guard let token else { throw ChatServiceError.missingToken }
        var body: [String: Any] = [
            "optimization_id": optimizationId,
            "suggestion_id": suggestionId,
        ]
        if let affectedFields, !affectedFields.isEmpty {
            let encoded = try affectedFields.map { try Self.encodeToJSONObject($0) }
            body["affected_fields"] = encoded
        }
        return try await apiClient.postJSONObject(
            endpoint: .chatApproveChange,
            bodyObject: body,
            token: token,
            timeout: 120
        )
    }

    func previewKeywordSuggestion(
        optimizationId: String,
        suggestionId: String,
        token: String?
    ) async throws -> KeywordSuggestionPreviewDTO {
        guard let token else { throw ChatServiceError.missingToken }
        return try await apiClient.postJSONObject(
            endpoint: .keywordSuggestionPreview(optimizationId: optimizationId, suggestionId: suggestionId),
            bodyObject: [:],
            token: token,
            timeout: 60
        )
    }

    // MARK: - Encoding helpers

    private static func encodeToJSONObject<E: Encodable>(_ value: E) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChatServiceError.encodePayloadFailed
        }
        return dict
    }
}
