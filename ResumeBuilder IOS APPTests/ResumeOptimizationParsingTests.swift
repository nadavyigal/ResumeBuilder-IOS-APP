import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class ResumeOptimizationParsingTests: XCTestCase {
    func testOptimizeResponseDecodesFlatPayload() throws {
        let json = """
        {
          "success": true,
          "optimization_id": "opt_123",
          "sections": [
            {
              "id": "summary",
              "type": "summary",
              "content": "Updated summary",
              "status": "optimized"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(response.optimizationId, "opt_123")
        XCTAssertEqual(response.sections?.count, 1)
        XCTAssertEqual(response.sections?.first?.body, "Updated summary")
    }

    func testOptimizeResponseDecodesNestedDataPayload() throws {
        let json = """
        {
          "data": {
            "success": true,
            "optimization_id": "opt_456",
            "sections": [
              {
                "id": "skills",
                "type": "skills",
                "content": "Swift, SwiftUI, Combine",
                "status": "improved",
                "ai_note": "Reordered by relevance"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(response.optimizationId, "opt_456")
        XCTAssertEqual(response.sections?.first?.type, .skills)
        XCTAssertEqual(response.sections?.first?.aiNote, "Reordered by relevance")
    }

    func testOptimizeResponseDecodesOptimizedResumeAlias() throws {
        let json = """
        {
          "success": true,
          "optimization_id": "opt_alias",
          "optimized_resume": [
            {
              "id": "experience",
              "type": "experience",
              "content": "Led migration reducing latency by 35%",
              "status": "optimized"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        XCTAssertEqual(response.optimizationId, "opt_alias")
        XCTAssertEqual(response.sections?.first?.type, .experience)
        XCTAssertEqual(response.sections?.first?.sectionStatus, .optimized)
    }

    func testOptimizeResponseDecodesReviewIdInCamelOrSnakeCase() throws {
        let camelJSON = #"{"success":false,"reviewId":"review-camel"}"#.data(using: .utf8)!
        let snakeJSON = #"{"success":false,"review_id":"review-snake"}"#.data(using: .utf8)!

        XCTAssertEqual(try JSONDecoder().decode(OptimizeResponse.self, from: camelJSON).reviewId, "review-camel")
        XCTAssertEqual(try JSONDecoder().decode(OptimizeResponse.self, from: snakeJSON).reviewId, "review-snake")
    }

    func testOptimizationReviewEnvelopeDecodesAppliedOptimizationId() throws {
        let json = """
        {
          "review": {
            "id": "review-1",
            "optimization_id": "opt-applied",
            "grouped_changes_json": [],
            "applied_at": "2026-06-26T14:53:35Z"
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(OptimizationReviewEnvelope.self, from: json)

        XCTAssertEqual(envelope.review.optimizationId, "opt-applied")
        XCTAssertEqual(envelope.review.appliedAt, "2026-06-26T14:53:35Z")
    }

    @MainActor
    func testReviewDestinationStateRetainsItsViewModelForTheSameReview() {
        let state = OptimizationReviewDestinationState(reviewId: "review-1")
        let originalModel = state.viewModel

        state.activate(reviewId: "review-1")

        XCTAssertTrue(originalModel === state.viewModel)

        state.activate(reviewId: "review-2")

        XCTAssertEqual(state.reviewId, "review-2")
        XCTAssertFalse(originalModel === state.viewModel)
        XCTAssertEqual(state.viewModel.reviewId, "review-2")
    }

    func testOptimizationReviewApplyTimeoutRecoversAppliedOptimizationId() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OptimizationReviewMockURLProtocol.self]
        let api = APIClient(
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: config),
            longRunningSession: URLSession(configuration: config),
            requestTimeout: 1
        )
        let viewModel = OptimizationReviewViewModel(reviewId: "review-1", api: api)
        viewModel.includedGroupIds = ["group-1"]

        OptimizationReviewMockURLProtocol.handler = { request in
            if request.httpMethod == "POST" {
                throw URLError(.timedOut)
            }

            let json = """
            {
              "review": {
                "id": "review-1",
                "optimization_id": "opt-after-timeout",
                "grouped_changes_json": [
                  {
                    "id": "group-1",
                    "section": "summary",
                    "title": "Sharpen summary",
                    "summary": "Make the opening more relevant.",
                    "before_excerpt": "Old summary",
                    "after_excerpt": "New summary"
                  }
                ],
                "applied_at": "2026-06-26T14:53:35Z"
              }
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }
        defer { OptimizationReviewMockURLProtocol.handler = nil }

        await viewModel.apply(token: "token")

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.applySuccessOptimizationId, "opt-after-timeout")
        XCTAssertEqual(viewModel.envelope?.review.optimizationId, "opt-after-timeout")
    }

    func testOptimizationReviewApplyFailureKeepsSelectionRetryableWithoutFalseSuccess() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OptimizationReviewMockURLProtocol.self]
        let api = APIClient(
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: config),
            longRunningSession: URLSession(configuration: config),
            requestTimeout: 1
        )
        let viewModel = OptimizationReviewViewModel(reviewId: "review-1", api: api)
        viewModel.includedGroupIds = ["group-1"]

        OptimizationReviewMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, #"{"error":"temporary outage"}"#.data(using: .utf8)!)
        }
        defer { OptimizationReviewMockURLProtocol.handler = nil }

        await viewModel.apply(token: "token")

        XCTAssertNil(viewModel.applySuccessOptimizationId)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.includedGroupIds, ["group-1"])
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertFalse(viewModel.serverRequiresMigration)
    }

    func testOptimizationReviewApplyBodyRejectionSurfacesErrorWithoutFalseSuccess() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OptimizationReviewMockURLProtocol.self]
        let api = APIClient(
            baseURL: URL(string: "https://example.test")!,
            session: URLSession(configuration: config),
            longRunningSession: URLSession(configuration: config),
            requestTimeout: 1
        )
        let viewModel = OptimizationReviewViewModel(reviewId: "review-1", api: api)
        viewModel.includedGroupIds = ["group-1"]

        OptimizationReviewMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, #"{"error":"no credits"}"#.data(using: .utf8)!)
        }
        defer { OptimizationReviewMockURLProtocol.handler = nil }

        await viewModel.apply(token: "token")

        XCTAssertEqual(viewModel.errorMessage, "no credits")
        XCTAssertNil(viewModel.applySuccessOptimizationId)
        XCTAssertEqual(viewModel.includedGroupIds, ["group-1"])
        XCTAssertFalse(viewModel.isSubmitting)
    }

    func testOptimizationDetailDecodesContactAndFlexibleScoreKeys() throws {
        let json = """
        {
          "sections": [
            {
              "id": "summary",
              "type": "summary",
              "content": "Updated summary",
              "status": "optimized"
            }
          ],
          "contact": {
            "name": "Ada Lovelace",
            "email": "ada@example.com",
            "phone": "+1 555 123 4567",
            "location": "London",
            "linkedin": "linkedin.com/in/ada"
          },
          "jobTitle": "iOS Engineer",
          "company": "Analytical Engines",
          "atsScoreBefore": 61,
          "atsScoreAfter": 82
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(OptimizationDetailDTO.self, from: json)

        XCTAssertEqual(detail.contact?.name, "Ada Lovelace")
        XCTAssertEqual(detail.contact?.email, "ada@example.com")
        XCTAssertEqual(detail.contact?.contactLine, "ada@example.com | +1 555 123 4567 | London | linkedin.com/in/ada")
        XCTAssertEqual(detail.jobTitle, "iOS Engineer")
        XCTAssertEqual(detail.atsScoreBefore, 61)
        XCTAssertEqual(detail.atsScoreAfter, 82)
    }
}

private final class OptimizationReviewMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
