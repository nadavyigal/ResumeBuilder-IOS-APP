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
