import Foundation

enum ExpertWorkflowServiceError: LocalizedError, Sendable {
    case missingToken
    case missingOptimizationId
    case emptyRunId
    case premiumRequired(String)
    case applyFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Sign in required."
        case .missingOptimizationId:
            return "Optimization is not ready yet."
        case .emptyRunId:
            return "Expert run id missing from server response."
        case .premiumRequired(let message):
            return message
        case .applyFailed(let message):
            return message
        }
    }
}

/// Client for `/api/v1/expert-workflows/*`.
struct ExpertWorkflowService: Sendable {
    var apiClient: APIClient = APIClient()

    /// Begins a surfaced expert workflow for the given optimization.
    func run(
        type: ExpertWorkflowType,
        optimizationId: String,
        token: String?
    ) async throws -> ExpertWorkflowRunCreateResponseDTO {
        try await runInternal(
            type: type,
            optimizationId: optimizationId,
            token: token
        )
    }

    /// Loads persisted run + artifacts (`GET /runs/:id`).
    func getStatus(runId: String, token: String?) async throws -> ExpertWorkflowRunSnapshot {
        guard let token else { throw ExpertWorkflowServiceError.missingToken }
        guard !runId.isEmpty else { throw ExpertWorkflowServiceError.emptyRunId }
        let envelope: ExpertWorkflowRunDetailEnvelope = try await apiClient.get(
            endpoint: .expertWorkflowRunGet(id: runId),
            token: token
        )
        guard let row = envelope.run, !row.id.isEmpty else {
            throw ExpertWorkflowServiceError.emptyRunId
        }
        return ExpertWorkflowRunSnapshot(
            runId: row.id,
            status: row.status ?? "",
            workflowTypeRaw: row.workflowType,
            output: row.outputJson ?? .object([:]),
            missingEvidence: []
        )
    }

    /// Applies server-side merge for a completed run (`POST /runs/:id/apply`).
    func apply(
        runId: String,
        workflowType: ExpertWorkflowType,
        token: String?,
        selectionIndex: Int? = nil,
        screeningSelectedIndices: [Int]? = nil
    ) async throws -> ExpertWorkflowApplyResponseDTO {
        guard let token else { throw ExpertWorkflowServiceError.missingToken }
        guard !runId.isEmpty else { throw ExpertWorkflowServiceError.emptyRunId }

        let applyMode = Self.applyMode(for: workflowType)
        var body: [String: Any] = ["apply_mode": applyMode]
        if workflowType == .professionalSummaryLab || workflowType == .coverLetterArchitect {
            if let selectionIndex {
                body["selection_index"] = selectionIndex
            }
        }
        if workflowType == .screeningAnswerStudio, let screeningSelectedIndices {
            body["selected_indices"] = screeningSelectedIndices
        }

        let dto: ExpertWorkflowApplyResponseDTO = try await apiClient.postJSONObject(
            endpoint: .expertWorkflowApply(runId: runId),
            bodyObject: body,
            token: token,
            timeout: 120
        )
        guard dto.success != false else {
            throw ExpertWorkflowServiceError.applyFailed(dto.error ?? "Apply failed.")
        }
        return dto
    }

    // MARK: - Internals

    private func runInternal(
        type: ExpertWorkflowType,
        optimizationId: String,
        token: String?
    ) async throws -> ExpertWorkflowRunCreateResponseDTO {
        guard let token else { throw ExpertWorkflowServiceError.missingToken }
        guard !optimizationId.isEmpty else { throw ExpertWorkflowServiceError.missingOptimizationId }
        let body: [String: Any] = [
            "optimization_id": optimizationId,
            "workflow_type": type.rawValue,
            "options": [String: Any](),
            "evidence_inputs": [String: Any](),
        ]

        do {
            let dto: ExpertWorkflowRunCreateResponseDTO = try await apiClient.postJSONObject(
                endpoint: .expertWorkflowRunPost,
                bodyObject: body,
                token: token,
                timeout: 120
            )
            if dto.runId.isEmpty {
                throw ExpertWorkflowServiceError.emptyRunId
            }
            return dto
        } catch let api as APIClientError {
            if case .serverError(let status, let message) = api, status == 402 {
                throw ExpertWorkflowServiceError.premiumRequired(
                    Self.extractLockedPreview(fromJSONString: message)
                        ?? Self.fallbackPremiumHint
                )
            }
            throw api
        }
    }

    private static let fallbackPremiumHint = "Premium subscription required to run expert modes."

    private static func extractLockedPreview(fromJSONString raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let preview = obj["locked_preview"] as? String,
              !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return preview
    }

    static func applyMode(for type: ExpertWorkflowType) -> String {
        switch type {
        case .atsOptimizationReport:
            return "skills_only"
        case .coverLetterArchitect:
            return "select_cover_letter_variant"
        case .screeningAnswerStudio:
            return "select_screening_answers"
        default:
            return "default"
        }
    }
}

struct ExpertWorkflowRunSnapshot: Sendable {
    let runId: String
    let status: String
    let workflowTypeRaw: String?
    let output: JSONValue
    let missingEvidence: [String]
}
