import Foundation

enum ResumeSectionType: String, Codable, Sendable, CaseIterable {
    case summary, experience, skills, education, additional

    var displayName: String {
        switch self {
        case .summary:    return "Summary"
        case .experience: return "Experience"
        case .skills:     return "Skills"
        case .education:  return "Education"
        case .additional: return "Additional"
        }
    }

    var icon: String {
        switch self {
        case .summary:    return "person.text.rectangle"
        case .experience: return "briefcase.fill"
        case .skills:     return "star.fill"
        case .education:  return "graduationcap.fill"
        case .additional: return "ellipsis.circle.fill"
        }
    }
}

struct OptimizedResumeSection: Identifiable, Codable, Sendable {
    let id: String
    let type: ResumeSectionType
    var body: String
    var status: String      // "optimized" | "improved" | "original"
    var aiNote: String?

    private enum CodingKeys: String, CodingKey {
        case id, type, body = "content", status
        case aiNote = "ai_note"
    }

    var sectionStatus: SectionStatus {
        switch status.lowercased() {
        case "optimized": return .optimized
        case "improved":  return .improved
        default:          return .original
        }
    }
}
