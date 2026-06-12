import Foundation
import UIKit

@MainActor
struct PDFExporter {
    static func presentShareSheet(fileURL: URL, from controller: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.present(activityVC, animated: true)
    }

    static func downloadPDF(optimizationId: String, token: String) async throws -> URL {
        let response = try await RuntimeServices.sharedAPIClient.getDataResponse(
            endpoint: .download(id: optimizationId),
            token: token
        )
        try PDFDownloadValidator.validatePDFData(response.data, statusCode: response.statusCode)
        return try ExportFileStore.writePDFData(response.data, optimizationId: optimizationId)
    }

    static func downloadPDFData(optimizationId: String, token: String) async throws -> Data {
        let response = try await RuntimeServices.sharedAPIClient.getDataResponse(
            endpoint: .download(id: optimizationId),
            token: token
        )
        try PDFDownloadValidator.validatePDFData(response.data, statusCode: response.statusCode)
        return response.data
    }
}
