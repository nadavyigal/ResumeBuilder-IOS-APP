import Foundation
import UIKit

@MainActor
struct PDFExporter {
    static func presentShareSheet(fileURL: URL, from controller: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.present(activityVC, animated: true)
    }

    static func downloadPDF(optimizationId: String, token: String) async throws -> URL {
        let data = try await RuntimeServices.sharedAPIClient.getData(
            endpoint: .download(id: optimizationId),
            token: token
        )
        try PDFDownloadValidator.validatePDFData(data, statusCode: 200)
        return try ExportFileStore.writePDFData(data, optimizationId: optimizationId)
    }

    static func downloadPDFData(optimizationId: String, token: String) async throws -> Data {
        let data = try await RuntimeServices.sharedAPIClient.getData(
            endpoint: .download(id: optimizationId),
            token: token
        )
        try PDFDownloadValidator.validatePDFData(data, statusCode: 200)
        return data
    }
}
