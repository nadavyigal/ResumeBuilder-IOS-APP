import XCTest
@testable import ResumeBuilder_IOS_APP

/// Guards the live keyword-suggestion preview and approve path on the Optimized
/// tab (`OptimizedResumeViewModel.previewKeyword` / `approveKeyword`). Its only
/// indirect coverage was `ChatViewModelTests`, deleted with the unused chat
/// screen on 2026-11-13.
@MainActor
final class KeywordSuggestionFlowTests: XCTestCase {

    private struct StubChat: ChatMessaging {
        var preview: Result<KeywordSuggestionPreviewDTO, Error>
        var approve: Result<ChatApproveChangeResponseDTO, Error>

        func fetchActiveSession(optimizationId: String, token: String?) async throws -> ChatSessionRecord? { nil }
        func getMessages(sessionId: String, token: String?) async throws -> [ChatMessageRecord] { [] }
        func sendMessage(
            sessionId: String?,
            optimizationId: String,
            content: String,
            token: String?
        ) async throws -> (stream: AsyncThrowingStream<String, Error>, pendingChanges: [ChatPendingChange]?, resolvedSessionId: String?) {
            throw URLError(.unsupportedURL)
        }
        func approveChange(
            optimizationId: String,
            suggestionId: String,
            affectedFields: [ChatAffectedField]?,
            token: String?
        ) async throws -> ChatApproveChangeResponseDTO {
            try approve.get()
        }
        func previewKeywordSuggestion(
            optimizationId: String,
            suggestionId: String,
            token: String?
        ) async throws -> KeywordSuggestionPreviewDTO {
            try preview.get()
        }
        func rejectChange(sessionId: String, changeId: String, token: String?) {}
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private func makeViewModel(chat: StubChat) -> OptimizedResumeViewModel {
        OptimizedResumeViewModel(
            optimizationId: "opt-kw",
            sections: [OptimizedResumeSection(id: "summary", type: .summary, body: "Old summary", status: "optimized")],
            optimizationService: MockResumeOptimizationService(),
            chatService: chat
        )
    }

    private func previewDTO() throws -> KeywordSuggestionPreviewDTO {
        try decode(KeywordSuggestionPreviewDTO.self, """
        {"suggestion_id":"kw-1","affected_fields":[{"section_id":"summary","field":"summary","original_value":"Old summary","new_value":"Summary with Kubernetes"}]}
        """)
    }

    func testPreviewStoresTheAffectedFields() async throws {
        let vm = makeViewModel(chat: StubChat(
            preview: .success(try previewDTO()),
            approve: .failure(URLError(.badServerResponse))
        ))

        await vm.previewKeyword(suggestionId: "kw-1", token: "token")

        XCTAssertEqual(vm.keywordPreviews["kw-1"]?.first?.sectionId, "summary")
        XCTAssertNil(vm.keywordPreviewErrors["kw-1"])
        XCTAssertFalse(vm.keywordsBeingPreviewed.contains("kw-1"))
    }

    func testAStaleSuggestionSaysSoInsteadOfTheRawServerError() async {
        let vm = makeViewModel(chat: StubChat(
            preview: .failure(APIClientError.serverError(status: 404, message: "Suggestion not found")),
            approve: .failure(URLError(.badServerResponse))
        ))

        await vm.previewKeyword(suggestionId: "kw-1", token: "token")

        let message = vm.keywordPreviewErrors["kw-1"] ?? ""
        XCTAssertFalse(message.contains("Suggestion not found"), message)
        XCTAssertTrue(message.contains("out of date"), message)
        XCTAssertNil(vm.keywordPreviews["kw-1"])
    }

    func testApproveMergesTheUpdatedResumeAndMarksTheSuggestion() async throws {
        let approved = try decode(ChatApproveChangeResponseDTO.self, """
        {"success":true,"updated_resume":{"summary":"Summary with Kubernetes"}}
        """)
        let vm = makeViewModel(chat: StubChat(preview: .success(try previewDTO()), approve: .success(approved)))

        await vm.previewKeyword(suggestionId: "kw-1", token: "token")
        await vm.approveKeyword(suggestionId: "kw-1", token: "token")

        XCTAssertTrue(vm.keywordsApproved.contains("kw-1"))
        XCTAssertEqual(vm.sections.first(where: { $0.type == .summary })?.body, "Summary with Kubernetes")
    }

    func testApproveWithoutAPreviewDoesNothing() async throws {
        let approved = try decode(ChatApproveChangeResponseDTO.self, #"{"success":true}"#)
        let vm = makeViewModel(chat: StubChat(preview: .success(try previewDTO()), approve: .success(approved)))

        await vm.approveKeyword(suggestionId: "kw-1", token: "token")

        XCTAssertFalse(vm.keywordsApproved.contains("kw-1"))
        XCTAssertEqual(vm.sections.first?.body, "Old summary")
    }
}
