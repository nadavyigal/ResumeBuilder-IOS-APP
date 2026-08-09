import Foundation
import OSLog

private let packageLogger = Logger(subsystem: "ResumeBuilder", category: "ApplicationPackage")

struct ApplicationPackageInputs: Sendable {
    let optimizationId: String
    let resumePDFURL: URL
    let candidateName: String?
    let jobTitle: String?
    let company: String?
    let coverLetterText: String?
    let screeningAnswers: [SubmitPackageCachedScreeningAnswer]
}

struct ApplicationPackage: Sendable, Equatable {
    /// Always non-empty, always résumé-first.
    let fileURLs: [URL]
    let includedCoverLetter: Bool
    let includedScreeningAnswers: Bool
    /// A cover letter existed but could not be rendered. The export still shipped, and
    /// the success state says so — this is never surfaced as an export failure.
    let coverLetterFailed: Bool
}

/// Assembles the files a single Export tap hands to the share sheet.
///
/// The formats follow how each artifact is actually used: the cover letter is attached
/// to an application, so it is a PDF; screening answers are pasted into ATS text boxes,
/// so they are plain text.
enum ApplicationPackageBuilder {
    enum ArtifactKind {
        case resume
        case coverLetter
        case screeningAnswers

        var label: String {
            switch self {
            case .resume: return NSLocalizedString("Resume", comment: "export filename component")
            case .coverLetter: return NSLocalizedString("Cover Letter", comment: "export filename component")
            case .screeningAnswers: return NSLocalizedString("Screening Answers", comment: "export filename component")
            }
        }

        var fileExtension: String {
            switch self {
            case .resume, .coverLetter: return "pdf"
            case .screeningAnswers: return "txt"
            }
        }

        /// Screening answers are the candidate's own notes, not a document they send
        /// under their name, so they do not carry it.
        var includesCandidateName: Bool {
            switch self {
            case .resume, .coverLetter: return true
            case .screeningAnswers: return false
            }
        }
    }

    typealias PDFRenderer = @MainActor (_ html: String, _ filename: String) async throws -> URL

    @MainActor
    static func build(
        _ inputs: ApplicationPackageInputs,
        renderPDF: PDFRenderer? = nil
    ) async -> ApplicationPackage {
        let renderPDF: PDFRenderer = renderPDF ?? { html, filename in
            try await HTMLPDFExporter.exportPDF(
                html: html,
                optimizationId: inputs.optimizationId,
                filename: filename
            )
        }
        var files: [URL] = [resumeFile(for: inputs)]
        var includedCoverLetter = false
        var coverLetterFailed = false
        var includedScreeningAnswers = false

        if let letter = inputs.coverLetterText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !letter.isEmpty {
            let filename = filename(
                for: .coverLetter,
                candidateName: inputs.candidateName,
                company: inputs.company
            )
            do {
                files.append(try await renderPDF(coverLetterHTML(letter), filename))
                includedCoverLetter = true
            } catch {
                // The résumé is the export. A letter that will not render costs the
                // user a line of explanation, not their export.
                coverLetterFailed = true
                packageLogger.error(
                    "Cover letter render failed for optimization \(inputs.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        let answersText = screeningAnswersText(
            inputs.screeningAnswers,
            jobTitle: inputs.jobTitle,
            company: inputs.company
        )
        if !answersText.isEmpty {
            do {
                files.append(try ExportFileStore.writeText(
                    answersText,
                    filename: filename(
                        for: .screeningAnswers,
                        candidateName: inputs.candidateName,
                        company: inputs.company
                    )
                ))
                includedScreeningAnswers = true
            } catch {
                packageLogger.error(
                    "Screening answers write failed for optimization \(inputs.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return ApplicationPackage(
            fileURLs: files,
            includedCoverLetter: includedCoverLetter,
            includedScreeningAnswers: includedScreeningAnswers,
            coverLetterFailed: coverLetterFailed
        )
    }

    // MARK: - Filenames

    /// `Jane Doe - Resume - Acme.pdf`. Unknown components are dropped rather than
    /// replaced with placeholders, so an unidentified export is `Resume.pdf`.
    static func filename(for kind: ArtifactKind, candidateName: String?, company: String?) -> String {
        var components: [String] = []
        if kind.includesCandidateName, let name = sanitizedComponent(candidateName) {
            components.append(name)
        }
        components.append(kind.label)
        if let company = sanitizedComponent(company) {
            components.append(company)
        }
        return components.joined(separator: " - ") + "." + kind.fileExtension
    }

    /// Keeps a filename human-readable while removing anything that would break a path
    /// or a share target: separators, control characters, and runs of whitespace.
    static func sanitizedComponent(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
            .union(.controlCharacters)
            .union(.newlines)
        let cleaned = String(String.UnicodeScalarView(raw.unicodeScalars.map { forbidden.contains($0) ? " " : $0 }))
        let collapsed = cleaned
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(60))
    }

    // MARK: - Screening answers

    /// Plain text, in the order the expert produced it, ready to paste one answer at a
    /// time into a web form. Returns an empty string when there is nothing to write.
    static func screeningAnswersText(
        _ answers: [SubmitPackageCachedScreeningAnswer],
        jobTitle: String?,
        company: String?
    ) -> String {
        let usable = answers.filter {
            !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usable.isEmpty else { return "" }

        var lines: [String] = [NSLocalizedString("Screening Answers", comment: "export file heading")]
        let context = [jobTitle, company]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !context.isEmpty {
            lines.append(context.joined(separator: " · "))
        }
        lines.append("")

        for (offset, answer) in usable.enumerated() {
            let question = answer.question.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("Q\(offset + 1). \(question)")
            lines.append(answer.answer.trimmingCharacters(in: .whitespacesAndNewlines))
            let evidence = answer.evidenceUsed.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !evidence.isEmpty {
                lines.append(String(
                    format: NSLocalizedString("Evidence: %@", comment: "export file line"),
                    evidence.joined(separator: "; ")
                ))
            }
            if let note = answer.confidenceNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                lines.append(String(format: NSLocalizedString("Note: %@", comment: "export file line"), note))
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Cover letter

    /// A4 page holding the letter body exactly as the expert wrote it. Blank lines start
    /// a new paragraph; single newlines stay as line breaks inside one.
    static func coverLetterHTML(_ text: String) -> String {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                "<p>" + escapeHTML(paragraph).replacingOccurrences(of: "\n", with: "<br />") + "</p>"
            }
            .joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8" />
        <style>
          @page { size: A4; margin: 0; }
          body {
            margin: 0;
            padding: 56px 64px;
            font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
            font-size: 12pt;
            line-height: 1.55;
            color: #1a1a1a;
          }
          p { margin: 0 0 14px 0; }
        </style>
        </head>
        <body>
        \(paragraphs)
        </body>
        </html>
        """
    }

    static func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    // MARK: - Internals

    /// Copies the exported résumé to its display name so the shared files read as one
    /// set. A failed copy is cosmetic, so it falls back to the file we already have.
    private static func resumeFile(for inputs: ApplicationPackageInputs) -> URL {
        let filename = filename(
            for: .resume,
            candidateName: inputs.candidateName,
            company: inputs.company
        )
        do {
            return try ExportFileStore.copyFile(at: inputs.resumePDFURL, filename: filename)
        } catch {
            packageLogger.error(
                "Résumé rename failed for optimization \(inputs.optimizationId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return inputs.resumePDFURL
        }
    }
}
