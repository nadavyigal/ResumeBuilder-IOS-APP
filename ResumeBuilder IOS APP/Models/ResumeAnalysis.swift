import Foundation

struct ResumeAnalysis: Codable, Sendable {
    let overall: Int
    let ats: Int
    let content: Int
    let design: Int
    let missingKeywords: [String]

    private enum CodingKeys: String, CodingKey {
        case overall, ats, content, design
        case missingKeywords = "missing_keywords"
    }

    static let empty = ResumeAnalysis(overall: 0, ats: 0, content: 0, design: 0, missingKeywords: [])
}

struct ResumeImprovement: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let impact: String   // "high" | "medium" | "low"
    var action: String?

    var impactLevel: ImpactLevel {
        switch impact.lowercased() {
        case "high":   return .high
        case "medium": return .medium
        default:       return .low
        }
    }
}
