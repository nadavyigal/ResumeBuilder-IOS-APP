import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    struct Bubble: Identifiable {
        let id: String
        let role: ChatParticipant
        var text: String

        init(id: String = UUID().uuidString, role: ChatParticipant, text: String) {
            self.id = id
            self.role = role
            self.text = text
        }
    }

    enum PendingUIStatus: Equatable {
        case pending
        case applying
        case approvedLocally
    }

    struct PendingUIModel: Identifiable {
        let suggestionId: String
        let change: ChatPendingChange
        var status: PendingUIStatus
        var id: String { suggestionId }
    }

    var messages: [Bubble] = []
    var pendingChanges: [PendingUIModel] = []
    var sessionId: String?
    var streamingAssistantBuffer: String = ""
    var isStreaming = false
    var showsTypingDots = false
    var errorMessage: String?
    var showPendingReview = false

    let optimizationId: String
    let resumeId: String?

    private let chatService: ChatService

    init(
        optimizationId: String,
        resumeId: String? = nil,
        chatService: ChatService = ChatService()
    ) {
        self.optimizationId = optimizationId
        self.resumeId = resumeId
        self.chatService = chatService
    }

    func sendMessage(text: String, token: String?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard token != nil else {
            errorMessage = ChatServiceError.missingToken.localizedDescription
            return
        }
        errorMessage = nil
        messages.append(Bubble(role: .user, text: trimmed))
        streamingAssistantBuffer = ""
        isStreaming = true
        showsTypingDots = true
        defer {
            isStreaming = false
            showsTypingDots = false
        }

        do {
            let (stream, pending, resolvedSid) = try await chatService.sendMessage(
                sessionId: sessionId,
                optimizationId: optimizationId,
                content: trimmed,
                token: token
            )
            if let resolvedSid {
                sessionId = resolvedSid
            }
            if let pending {
                upsertPending(pending)
            }

            streamingAssistantBuffer = ""
            for try await chunk in stream {
                showsTypingDots = false
                streamingAssistantBuffer.append(chunk)
            }
            let finalText = streamingAssistantBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            streamingAssistantBuffer = ""
            if !finalText.isEmpty {
                messages.append(Bubble(role: .ai, text: finalText))
            }
            await refreshHistory(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertPending(_ incoming: [ChatPendingChange]) {
        var map = Dictionary(uniqueKeysWithValues: pendingChanges.map { ($0.suggestionId, $0) })
        for c in incoming {
            if map[c.suggestionId] == nil {
                map[c.suggestionId] = PendingUIModel(suggestionId: c.suggestionId, change: c, status: .pending)
            }
        }
        pendingChanges = map.values.sorted(by: { $0.change.suggestionNumber < $1.change.suggestionNumber })
    }

    func refreshHistory(token: String?) async {
        guard let token, let sessionId else { return }
        do {
            let rows = try await chatService.getMessages(sessionId: sessionId, token: token)
            messages = rows.compactMap { row in
                let role = row.uiRole
                let text = row.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return Bubble(id: row.id, role: role, text: row.content)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approve(
        suggestionId: String,
        token: String?,
        mergeInto resumeVM: OptimizedResumeViewModel?
    ) async {
        guard let idx = pendingChanges.firstIndex(where: { $0.suggestionId == suggestionId }) else { return }
        guard pendingChanges[idx].status == .pending else { return }
        pendingChanges[idx].status = .applying
        errorMessage = nil
        do {
            let fields = pendingChanges[idx].change.affectedFields
            let dto = try await chatService.approveChange(
                optimizationId: optimizationId,
                suggestionId: suggestionId,
                affectedFields: fields,
                token: token
            )
            pendingChanges[idx].status = .approvedLocally
            resumeVM?.mergeApproveSnapshot(dto.updatedResume)
            pendingChanges.remove(at: idx)
            await refreshHistory(token: token)
        } catch {
            errorMessage = error.localizedDescription
            pendingChanges[idx].status = .pending
        }
    }

    func reject(suggestionId: String) {
        chatService.rejectChange(sessionId: sessionId ?? "", changeId: suggestionId, token: nil)
        pendingChanges.removeAll { $0.suggestionId == suggestionId }
    }
}
