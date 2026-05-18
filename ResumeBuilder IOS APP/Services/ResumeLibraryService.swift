import Foundation
import UIKit

protocol ResumeLibraryServiceProtocol: Sendable {
    func listSavedResumes(token: String) async throws -> [SavedResume]
    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume
    func deleteResume(id: String, token: String) async throws
    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume
    func downloadResumePDF(id: String, token: String) async throws -> URL
}

final class ResumeLibraryService: ResumeLibraryServiceProtocol, Sendable {
    private let apiClient = APIClient()

    func listSavedResumes(token: String) async throws -> [SavedResume] {
        let response: SavedResumesResponse = try await apiClient.get(endpoint: .savedResumes, token: token)
        return response.resumes
    }

    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        let response: SaveResumeResponse = try await apiClient.postJSON(
            endpoint: .saveResume(id: id),
            body: ["displayName": displayName],
            token: token
        )
        guard let resume = response.resume else {
            throw URLError(.badServerResponse)
        }
        return resume
    }

    func deleteResume(id: String, token: String) async throws {
        let _: APIStatusResponse = try await apiClient.postJSON(
            endpoint: .deleteResume(id: id),
            body: [:] as [String: String],
            token: token
        )
    }

    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        let response: SaveResumeResponse = try await apiClient.postJSON(
            endpoint: .renameResume(id: id),
            body: ["displayName": displayName],
            token: token
        )
        guard let resume = response.resume else {
            throw URLError(.badServerResponse)
        }
        return resume
    }

    func downloadResumePDF(id: String, token: String) async throws -> URL {
        let data = try await apiClient.getData(endpoint: .download(id: id), token: token)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).pdf")
        try data.write(to: tmp)
        return tmp
    }
}

final class MockResumeLibraryService: ResumeLibraryServiceProtocol, Sendable {
    func listSavedResumes(token: String) async throws -> [SavedResume] {
        [
            SavedResume(id: "mock-resume-1", filename: "Senior_Dev_Resume.pdf", displayName: "Senior Dev Resume", createdAt: "2026-05-10T10:00:00Z", sizeBytes: 102_400),
            SavedResume(id: "mock-resume-2", filename: "Product_Manager_Resume.pdf", displayName: nil, createdAt: "2026-05-12T14:30:00Z", sizeBytes: 87_040),
        ]
    }

    func saveResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        SavedResume(id: id, filename: "\(displayName).pdf", displayName: displayName, createdAt: "2026-05-15T00:00:00Z", sizeBytes: nil)
    }

    func deleteResume(id: String, token: String) async throws {}

    func renameResume(id: String, displayName: String, token: String) async throws -> SavedResume {
        SavedResume(id: id, filename: "\(displayName).pdf", displayName: displayName, createdAt: "2026-05-15T00:00:00Z", sizeBytes: nil)
    }

    func downloadResumePDF(id: String, token: String) async throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mock_\(id).pdf")
        // Use UIGraphicsPDFRenderer to produce a structurally valid PDF with real
        // resume text so the backend pdf-parse can extract content without XRef errors.
        let data = await MainActor.run {
            let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
            let renderer = UIGraphicsPDFRenderer(bounds: bounds)
            return renderer.pdfData { ctx in
                ctx.beginPage()
                let text = mockResumeText(for: id)
                text.draw(
                    in: CGRect(x: 50, y: 50, width: 512, height: 692),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 11)]
                )
            }
        }
        try data.write(to: tmp)
        return tmp
    }

    private func mockResumeText(for id: String) -> String {
        switch id {
        case "mock-resume-2":
            return """
            Jane Smith
            Product Manager | San Francisco, CA
            jane.smith@email.com | (555) 987-6543

            SUMMARY
            Product manager with 7 years shipping B2B SaaS products. Scaled two products from 0 to $10M ARR.

            EXPERIENCE
            Senior Product Manager | SaaS Corp | 2021–Present
            • Defined roadmap for core analytics product; grew DAU by 65% in 12 months
            • Led cross-functional team of 12 (engineering, design, data science)

            Product Manager | Growth Stage Co | 2018–2021
            • Launched 3 major features; each reduced churn by 8–15%
            • Ran 40+ A/B experiments, lifting activation rate from 32% to 51%

            EDUCATION
            MBA | Business School | 2018
            B.A. Economics | State University | 2015

            SKILLS
            Product strategy, Roadmapping, SQL, Mixpanel, Figma, JIRA, OKRs
            """
        default:
            return """
            John Doe
            Senior Software Engineer | San Francisco, CA
            john.doe@email.com | (555) 123-4567 | github.com/johndoe

            SUMMARY
            Senior engineer with 8 years building scalable distributed systems. Led teams delivering products to millions of users.

            EXPERIENCE
            Senior Software Engineer | Tech Company Inc. | 2020–Present
            • Architected microservices platform serving 10M+ daily active users
            • Reduced API p99 latency 40% via Redis caching and query optimization
            • Mentored 5 engineers; conducted 200+ code reviews

            Software Engineer | Startup LLC | 2017–2020
            • Built real-time analytics pipeline processing 50K events/second
            • Shipped mobile SDK adopted by 300+ enterprise customers
            • Reduced CI build time from 18 min to 6 min via parallelization

            EDUCATION
            B.S. Computer Science | State University | 2017

            SKILLS
            Swift, Python, Go, Kubernetes, PostgreSQL, Redis, AWS, Terraform, Docker
            """
        }
    }
}
