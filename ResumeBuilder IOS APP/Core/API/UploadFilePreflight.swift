import Foundation

struct UploadFileDescriptor: Sendable {
    let filename: String
    let data: Data
    let mimeType: String
}

enum UploadFilePreflightError: LocalizedError, Equatable, Sendable {
    case missingFile
    case emptyFile
    case unsupportedFileType

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Selected resume file could not be found. Please choose it again from Files."
        case .emptyFile:
            return "Selected resume file is empty. Please choose a freshly exported PDF."
        case .unsupportedFileType:
            return "Choose a PDF resume exported from your word processor, not a scanned image or shortcut file."
        }
    }
}

enum UploadFilePreflight {
    nonisolated static func loadResumeFile(_ fileURL: URL) throws -> UploadFileDescriptor {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw UploadFilePreflightError.missingFile
        }
        guard mimeType(for: fileURL) != nil else {
            throw UploadFilePreflightError.unsupportedFileType
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            throw UploadFilePreflightError.emptyFile
        }
        return UploadFileDescriptor(
            filename: fileURL.lastPathComponent,
            data: data,
            mimeType: mimeType(for: fileURL) ?? "application/octet-stream"
        )
    }

    nonisolated static func mimeType(for fileURL: URL) -> String? {
        switch fileURL.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            return nil
        }
    }
}
