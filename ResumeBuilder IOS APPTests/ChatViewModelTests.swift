import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ChatViewModelTests: XCTestCase {
    func testBootstrapSessionPopulatesSessionAndHistory() async throws {
        let message = try JSONDecoder().decode(
            ChatMessageRecord.self,
            from: Data(#"{"id":"msg-1","session_id":"sess-1","sender":"user","content":"Prior question"}"#.utf8)
        )
        let mock = MockChatMessaging(
            activeSession: ChatSessionRecord(
                id: "sess-1",
                optimizationId: "opt-1",
                status: "active",
                createdAt: nil,
                lastActivityAt: nil
            ),
            messages: [message]
        )
        let vm = ChatViewModel(optimizationId: "opt-1", chatService: mock)

        await vm.bootstrapSession(token: "token")

        XCTAssertEqual(vm.sessionId, "sess-1")
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.text, "Prior question")
        XCTAssertEqual(mock.fetchActiveSessionCalls, 1)
        XCTAssertEqual(mock.getMessagesCalls, 1)
    }

    func testSendMessageRejectsOversizedInput() async {
        let vm = ChatViewModel(optimizationId: "opt-1")
        let oversized = String(repeating: "a", count: ChatViewModel.maxMessageLength + 1)

        await vm.sendMessage(text: oversized, token: "token")

        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertEqual(
            vm.errorMessage,
            "Message is too long (max \(ChatViewModel.maxMessageLength) characters)."
        )
    }
}

private final class MockChatMessaging: ChatMessaging, @unchecked Sendable {
    var activeSession: ChatSessionRecord?
    var messages: [ChatMessageRecord]
    private(set) var fetchActiveSessionCalls = 0
    private(set) var getMessagesCalls = 0

    init(activeSession: ChatSessionRecord? = nil, messages: [ChatMessageRecord] = []) {
        self.activeSession = activeSession
        self.messages = messages
    }

    func fetchActiveSession(optimizationId: String, token: String?) async throws -> ChatSessionRecord? {
        fetchActiveSessionCalls += 1
        return activeSession
    }

    func getMessages(sessionId: String, token: String?) async throws -> [ChatMessageRecord] {
        getMessagesCalls += 1
        return messages
    }

    func sendMessage(
        sessionId: String?,
        optimizationId: String,
        content: String,
        token: String?
    ) async throws -> (stream: AsyncThrowingStream<String, Error>, pendingChanges: [ChatPendingChange]?, resolvedSessionId: String?) {
        XCTFail("sendMessage should not be called in bootstrap tests")
        return (AsyncThrowingStream { $0.finish() }, nil, nil)
    }

    func approveChange(
        optimizationId: String,
        suggestionId: String,
        affectedFields: [ChatAffectedField]?,
        token: String?
    ) async throws -> ChatApproveChangeResponseDTO {
        throw ChatServiceError.missingToken
    }

    func rejectChange(sessionId: String, changeId: String, token: String?) {}
}
