import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class FitCheckServiceTests: XCTestCase {
    func testFitVerdictDecodesSnakeCasePayloadAndClampsScore() throws {
        let json = """
        {
          "verdict": "strong",
          "score": 142,
          "score_note": "Estimated fit vs this job.",
          "top_gaps": [
            {
              "title": "No cloud infra experience",
              "detail": "JD lists AWS in must-have; not found in resume",
              "severity": "critical"
            }
          ],
          "missing_keywords": [
            {
              "keyword": "Terraform",
              "importance": "required",
              "reason": "Must-have infrastructure tool."
            }
          ]
        }
        """.data(using: .utf8)!

        let verdict = try JSONDecoder().decode(FitVerdict.self, from: json)

        XCTAssertEqual(verdict.band, .strong)
        XCTAssertEqual(verdict.score, 100)
        XCTAssertEqual(verdict.scoreNote, "Estimated fit vs this job.")
        XCTAssertEqual(verdict.topGaps.first?.title, "No cloud infra experience")
        XCTAssertEqual(verdict.topGaps.first?.explanation, "JD lists AWS in must-have; not found in resume")
        XCTAssertEqual(verdict.topGaps.first?.severity, .high)
        XCTAssertEqual(verdict.missingKeywords.first?.keyword, "Terraform")
        XCTAssertEqual(verdict.missingKeywords.first?.importance, .high)
    }

    func testATSScoreResultMapsCamelCaseFitBlock() throws {
        let json = """
        {
          "success": true,
          "score": { "overall": 68, "timestamp": "2026-06-23T00:00:00Z" },
          "checksRemaining": 4,
          "sessionId": "session-123",
          "fit": {
            "verdict": "stretch",
            "scoreNote": "Estimated fit vs this job, not a hiring guarantee.",
            "topGaps": [
              {
                "title": "Leadership scope needs metrics",
                "explanation": "The job asks for measurable team outcomes.",
                "severity": "medium"
              }
            ],
            "missingKeywords": [
              {
                "keyword": "Lifecycle marketing",
                "importance": "medium"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ATSScoreResult.self, from: json)
        let result = try FitCheckService.map(response)

        XCTAssertEqual(result.verdict.band, .stretch)
        XCTAssertEqual(result.verdict.score, 68)
        XCTAssertEqual(result.verdict.topGaps.count, 1)
        XCTAssertEqual(result.verdict.missingKeywords.first?.keyword, "Lifecycle marketing")
        XCTAssertEqual(result.sessionId, "session-123")
        XCTAssertEqual(result.checksRemaining, 4)
    }

    func testBandDerivesFromOverallOnlyWhenFitVerdictIsAbsent() throws {
        let json = """
        {
          "score": { "overall": 82 },
          "fit": {
            "score_note": "Estimated fit vs this job.",
            "top_gaps": [],
            "missing_keywords": []
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ATSScoreResult.self, from: json)
        let result = try FitCheckService.map(response)

        XCTAssertEqual(result.verdict.band, .strong)
        XCTAssertEqual(result.verdict.score, 82)
    }

    func testServerVerdictWinsOverFallbackScoreBand() throws {
        let json = """
        {
          "score": { "overall": 91 },
          "fit": {
            "verdict": "stretch",
            "score_note": "Server-owned band.",
            "top_gaps": [],
            "missing_keywords": []
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ATSScoreResult.self, from: json)
        let result = try FitCheckService.map(response)

        XCTAssertEqual(result.verdict.band, .stretch)
        XCTAssertEqual(result.verdict.score, 91)
    }

    func testMissingFitBlockMapsToServiceError() throws {
        let json = """
        {
          "score": { "overall": 74 },
          "checks_remaining": 3,
          "session_id": "session-456"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ATSScoreResult.self, from: json)

        XCTAssertThrowsError(try FitCheckService.map(response)) { error in
            XCTAssertEqual(error as? FitCheckServiceError, .missingFitBlock)
        }
    }

    func testMockFitCheckServiceReturnsInjectedResult() async throws {
        let expected = FitCheckResult(
            verdict: FitVerdict(
                band: .skip,
                score: 34,
                scoreNote: "Low fit for now.",
                topGaps: [],
                missingKeywords: []
            ),
            sessionId: "mock-session",
            checksRemaining: 2
        )
        let service = MockFitCheckService(result: expected)

        let result = try await service.checkFit(
            resumeId: "resume-1",
            jobDescription: "Build iOS apps",
            jobDescriptionURL: nil,
            accessToken: "token-1",
            sessionId: nil
        )

        XCTAssertEqual(result, expected)
    }
}
