import Foundation

enum ChatServiceError: LocalizedError, Sendable {
    case missingToken
    case missingOptimizationId
    case noSessionYet
    case encodePayloadFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Sign in required to chat."
        case .missingOptimizationId:
            return "Optimization is not ready yet."
        case .noSessionYet:
            return "Chat session begins after your first message."
        case .encodePayloadFailed:
            return "Could not serialize change fields."
        }
    }
}

/// Native client for authenticated chat (`/api/v1/chat`).
struct ChatService: Sendable {
    var apiClient: APIClient = APIClient()
    var streamingClient: StreamingClient = StreamingClient()

    // MARK: - Session

    /// Best-effort: active backend session tied to `optimization_id`, if present.
    func fetchActiveSession(optimizationId: String, token: String?) async throws -> ChatSessionRecord? {
        guard let token else { throw ChatServiceError.missingToken }
        let list: ChatSessionListEnvelope = try await apiClient.getWithQuery(
            endpoint: .chatSessionsActive,
            token: token
        )
        let sessions = list.sessions ?? []
        return sessions.first { ($0.optimizationId ?? "") == optimizationId && ($0.status ?? "active") == "active" }
    }

    /// Plan alias (`resume_id` unused here — optimization is keyed by optimization id throughout chat APIs).
    func createSession(resumeId: String, optimizationId: String?, token: String?) async throws -> ChatSessionRecord {
        _ = resumeId
        guard let optimizationId else { throw ChatServiceError.missingOptimizationId }
        guard let token else { throw ChatServiceError.missingToken }
        if let existing = try await fetchActiveSession(optimizationId: optimizationId, token: token) {
            return existing
        }
        throw ChatServiceError.noSessionYet
    }

    // MARK: - Messages

    /// Loads history via `/api/v1/chat/sessions/{id}` (same path the web sidebar uses).
    func getMessages(sessionId: String, token: String?) async throws -> [ChatMessageRecord] {
        guard let token else { throw ChatServiceError.missingToken }
        let detail: ChatSessionDetailEnvelope = try await apiClient.get(endpoint: .chatSession(id: sessionId), token: token)
        return detail.messages ?? []
    }

    /// Streams assistant text sequentially (API returns JSON, not SSE). Also returns pending ATS changes if any.
    func sendMessage(
        sessionId: String?,
        optimizationId: String,
        content: String,
        token: String?
    ) async throws -> (stream: AsyncThrowingStream<String, Error>, pendingChanges: [ChatPendingChange]?, resolvedSessionId: String?) {
        guard let token else { throw ChatServiceError.missingToken }

        var body: [String: Any] = [
            "optimization_id": optimizationId,
            "message": content,
        ]
        if let sessionId {
            body["session_id"] = sessionId
        }

        /// Long chats can occasionally exceed default API timeout (~30s server-side scoring).
        let dto: ChatSendMessageResponseDTO = try await apiClient.postJSONObject(
            endpoint: .chatSend,
            bodyObject: body,
            token: token,
            timeout: 120
        )

        let full = dto.aiResponse ?? ""
        let stream = streamingClient.streamDisplayedText(from: full, chunkSize: 10)
        return (stream, dto.pendingChanges, dto.sessionId)
    }

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

    /// Matches web UX: rejecting is client-side only (`ChatSidebar.tsx` removes from local list).
    func rejectChange(sessionId: String, changeId: String, token: String?) {
        _ = sessionId
        _ = changeId
        _ = token
    }

    /// Applies a single persisted amendment (`amendment_requests` row).
    func applyAmendment(sessionId: String, amendmentId: String, token: String?) async throws -> ChatApplyAmendmentResponseDTO {
        guard let token else { throw ChatServiceError.missingToken }
        let body: [String: Any] = ["amendment_id": amendmentId]
        return try await apiClient.postJSONObject(
            endpoint: .chatSessionApply(sessionId: sessionId),
            bodyObject: body,
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
