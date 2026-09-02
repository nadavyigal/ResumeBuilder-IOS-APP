import Foundation

enum ExpertWorkflowServiceError: LocalizedError, Sendable {
    case missingToken
    case missingOptimizationId
    case emptyRunId
    case premiumRequired(String)
    case applyFailed(String)
    /// The run would have lowered the match score, so **nothing was applied**.
    /// Not an error the user should just be shown — a decision they should be
    /// offered. Re-call `apply` with `acceptScoreDecrease: true` to commit it.
    case scoreWouldDecrease(kept: Double?, measured: Double)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return NSLocalizedString("Sign in required.", comment: "")
        case .missingOptimizationId:
            return NSLocalizedString("Optimization is not ready yet.", comment: "")
        case .emptyRunId:
            return NSLocalizedString("Expert run id missing from server response.", comment: "")
        case .premiumRequired(let message):
            return message
        case .applyFailed(let message):
            return message
        case .scoreWouldDecrease(let kept, let measured):
            return String(
                format: NSLocalizedString(
                    "This change would lower your match score from %d%% to %d%%.",
                    comment: "Expert run refused because it would reduce the score"
                ),
                // NOT `displayPercent`: `kept`/`measured` are siblings of
                // `before`/`after` in `ExpertAtsImpactResult` and have always
                // been rendered unscaled. Folding in the 0...1 rule would
                // report a genuine score of 1.0 as "100%" inside a dialog the
                // user makes a decision on. `?? 0` only differs from the old
                // `Int(_:)` where that used to trap.
                (kept ?? 0).safeRoundedInt ?? 0,
                measured.safeRoundedInt ?? 0
            )
        }
    }
}

/// Client for `/api/v1/expert-workflows/*`.
protocol ExpertWorkflowServiceProtocol: Sendable {
    func run(type: ExpertWorkflowType, optimizationId: String, token: String?, evidenceInputs: [String: JSONValue]) async throws -> ExpertWorkflowRunCreateResponseDTO
    func getStatus(runId: String, token: String?) async throws -> ExpertWorkflowRunSnapshot
    func apply(
        runId: String,
        workflowType: ExpertWorkflowType,
        token: String?,
        selectionIndex: Int?,
        screeningSelectedIndices: [Int]?,
        selectedFields: [String]?,
        acceptScoreDecrease: Bool
    ) async throws -> ExpertWorkflowApplyResponseDTO
}

/// Client for `/api/v1/expert-workflows/*`.
struct ExpertWorkflowService: ExpertWorkflowServiceProtocol, Sendable {
    var apiClient: APIClient = RuntimeServices.sharedAPIClient

    /// Begins a surfaced expert workflow for the given optimization.
    func run(
        type: ExpertWorkflowType,
        optimizationId: String,
        token: String?,
        evidenceInputs: [String: JSONValue] = [:]
    ) async throws -> ExpertWorkflowRunCreateResponseDTO {
        try await runInternal(
            type: type,
            optimizationId: optimizationId,
            token: token,
            evidenceInputs: evidenceInputs
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
        screeningSelectedIndices: [Int]? = nil,
        selectedFields: [String]? = nil,
        /// Set only after the user has been shown the drop and chosen to apply
        /// anyway. Without it the server writes nothing when the score falls.
        acceptScoreDecrease: Bool = false
    ) async throws -> ExpertWorkflowApplyResponseDTO {
        guard let token else { throw ExpertWorkflowServiceError.missingToken }
        guard !runId.isEmpty else { throw ExpertWorkflowServiceError.emptyRunId }

        let applyMode = Self.applyMode(for: workflowType)
        var body: [String: Any] = ["apply_mode": applyMode]
        if acceptScoreDecrease {
            body["accept_score_decrease"] = true
        }
        if workflowType == .professionalSummaryLab || workflowType == .coverLetterArchitect {
            if let selectionIndex {
                body["selection_index"] = selectionIndex
            }
        }
        if workflowType == .screeningAnswerStudio, let screeningSelectedIndices {
            body["selected_indices"] = screeningSelectedIndices
        }
        if workflowType == .fullResumeRewrite, let selectedFields {
            body["selected_fields"] = selectedFields
        }

        let dto: ExpertWorkflowApplyResponseDTO = try await apiClient.postJSONObject(
            endpoint: .expertWorkflowApply(runId: runId),
            bodyObject: body,
            token: token,
            timeout: 120
        )
        // A refused run also comes back with `success: false`, but it is not a
        // failure — nothing was applied *on purpose*, and the user gets to
        // decide. Surfaced as its own case so a caller cannot accidentally
        // report it as an error.
        if let decrease = dto.atsImpact?.decreaseBlocked {
            throw ExpertWorkflowServiceError.scoreWouldDecrease(
                kept: decrease.kept,
                measured: decrease.measured
            )
        }
        guard dto.success != false else {
            throw ExpertWorkflowServiceError.applyFailed(dto.error ?? NSLocalizedString("Apply failed.", comment: ""))
        }
        return dto
    }

    // MARK: - Internals

    private func runInternal(
        type: ExpertWorkflowType,
        optimizationId: String,
        token: String?,
        evidenceInputs: [String: JSONValue]
    ) async throws -> ExpertWorkflowRunCreateResponseDTO {
        guard let token else { throw ExpertWorkflowServiceError.missingToken }
        guard !optimizationId.isEmpty else { throw ExpertWorkflowServiceError.missingOptimizationId }
        let body: [String: Any] = [
            "optimization_id": optimizationId,
            "workflow_type": type.rawValue,
            "options": [String: Any](),
            "evidence_inputs": evidenceInputs.mapValues(Self.jsonObject(from:)),
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
            if case .serverError(let status, let message) = api {
                if status == 402 {
                    throw ExpertWorkflowServiceError.premiumRequired(
                        Self.extractLockedPreview(fromJSONString: message)
                            ?? Self.fallbackPremiumHint
                    )
                }
                if status >= 500 {
                    let lower = message.lowercased()
                    if lower.contains("not found") || lower.contains("access denied") {
                        throw ExpertWorkflowServiceError.missingOptimizationId
                    }
                }
            }
            throw api
        }
    }

    private static let fallbackPremiumHint = NSLocalizedString("Premium subscription required to run expert modes.", comment: "")

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

    private static func jsonObject(from value: JSONValue) -> Any {
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            return number
        case .bool(let bool):
            return bool
        case .object(let object):
            return object.mapValues(jsonObject(from:))
        case .array(let array):
            return array.map(jsonObject(from:))
        case .null:
            return NSNull()
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
