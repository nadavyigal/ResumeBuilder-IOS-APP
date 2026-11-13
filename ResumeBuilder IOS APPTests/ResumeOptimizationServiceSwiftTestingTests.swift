import Foundation
import Testing
@testable import ResumeBuilder_IOS_APP

struct ResumeOptimizationServiceSwiftTestingTests {
    @Test("OptimizeResponse decodes nested optimized resume payload")
    @MainActor
    func optimizeResponseDecoding() throws {
        let json = """
        {
          "data": {
            "success": true,
            "optimization_id": "opt_nested",
            "optimized_resume": [
              {
                "id": "summary",
                "type": "summary",
                "content": "Updated summary",
                "status": "optimized"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OptimizeResponse.self, from: json)
        #expect(response.optimizationId == "opt_nested")
        #expect(response.sections?.first?.type == .summary)
        #expect(response.sections?.first?.body == "Updated summary")
    }
}
