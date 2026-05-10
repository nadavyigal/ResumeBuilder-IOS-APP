import Foundation
import UIKit

@MainActor
struct PDFExporter {
    static func presentShareSheet(fileURL: URL, from controller: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.present(activityVC, animated: true)
    }

    static func downloadPDF(optimizationId: String, token: String) async throws -> URL {
        let data = try await APIClient().getData(endpoint: .download(id: optimizationId), token: token)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-\(optimizationId)")
            .appendingPathExtension("pdf")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
