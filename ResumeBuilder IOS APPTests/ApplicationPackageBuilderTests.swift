import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story 2 of the export-package spec: Export delivers the résumé plus whatever expert
/// artifacts already exist, and never fails because one of them could not be produced.
@MainActor
final class ApplicationPackageBuilderTests: XCTestCase {
    private var resumeURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        resumeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("package-tests-resume-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4 stub".utf8).write(to: resumeURL)
    }

    override func tearDown() async throws {
        if let resumeURL { try? FileManager.default.removeItem(at: resumeURL) }
        try await super.tearDown()
    }

    // MARK: - Filenames

    func testFilenamesUseCandidateAndCompanyWhenKnown() {
        XCTAssertEqual(
            ApplicationPackageBuilder.filename(for: .resume, candidateName: "Jane Doe", company: "Acme"),
            "Jane Doe - Resume - Acme.pdf"
        )
        XCTAssertEqual(
            ApplicationPackageBuilder.filename(for: .coverLetter, candidateName: "Jane Doe", company: "Acme"),
            "Jane Doe - Cover Letter - Acme.pdf"
        )
        XCTAssertEqual(
            ApplicationPackageBuilder.filename(for: .screeningAnswers, candidateName: "Jane Doe", company: "Acme"),
            "Screening Answers - Acme.txt"
        )
    }

    /// Unknown metadata is dropped, never replaced with a placeholder: `Resume.pdf` is
    /// honest, `Unknown - Resume - Unknown.pdf` is not.
    func testFilenamesDropUnknownComponents() {
        XCTAssertEqual(
            ApplicationPackageBuilder.filename(for: .resume, candidateName: nil, company: nil),
            "Resume.pdf"
        )
        XCTAssertEqual(
            ApplicationPackageBuilder.filename(for: .coverLetter, candidateName: "  ", company: "Acme"),
            "Cover Letter - Acme.pdf"
        )
        XCTAssertEqual(
            ApplicationPackageBuilder.filename(for: .screeningAnswers, candidateName: nil, company: nil),
            "Screening Answers.txt"
        )
    }

    func testFilenamesStripPathSeparatorsAndCollapseWhitespace() {
        let name = ApplicationPackageBuilder.filename(
            for: .resume,
            candidateName: "Jane/Doe",
            company: "Acme:  R&D\nLabs"
        )
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(":"))
        XCTAssertFalse(name.contains("\n"))
        XCTAssertTrue(name.hasSuffix(".pdf"))
        XCTAssertEqual(name, "Jane Doe - Resume - Acme R&D Labs.pdf")
    }

    // MARK: - Screening answers text

    func testScreeningAnswersTextIsPasteReady() {
        let text = ApplicationPackageBuilder.screeningAnswersText(
            [
                answer(id: 0, question: "Why this role?", answer: "Aligns with my goals.", evidence: ["Led migration"]),
                answer(id: 1, question: "Expected salary?", answer: "Market rate.", note: "Adjust to your range."),
            ],
            jobTitle: "Product Manager",
            company: "Acme"
        )

        XCTAssertTrue(text.contains("Product Manager"))
        XCTAssertTrue(text.contains("Acme"))
        XCTAssertTrue(text.contains("Why this role?"))
        XCTAssertTrue(text.contains("Aligns with my goals."))
        XCTAssertTrue(text.contains("Led migration"))
        XCTAssertTrue(text.contains("Adjust to your range."))
        guard let first = text.range(of: "Why this role?"),
              let second = text.range(of: "Expected salary?") else {
            return XCTFail("both questions should be present")
        }
        XCTAssertTrue(first.lowerBound < second.lowerBound, "answers keep their order")
    }

    func testScreeningAnswersTextSkipsEmptyAnswers() {
        let text = ApplicationPackageBuilder.screeningAnswersText(
            [
                answer(id: 0, question: "Answered", answer: "Yes."),
                answer(id: 1, question: "Unanswered", answer: "   "),
            ],
            jobTitle: nil,
            company: nil
        )

        XCTAssertTrue(text.contains("Answered"))
        XCTAssertFalse(text.contains("Unanswered"))
    }

    // MARK: - Cover letter rendering

    func testCoverLetterHTMLEscapesMarkupAndKeepsParagraphs() {
        let html = ApplicationPackageBuilder.coverLetterHTML(
            "Dear <Hiring Manager> & team,\n\nI build A/B tests.\nSincerely,\nJane"
        )

        XCTAssertTrue(html.contains("&lt;Hiring Manager&gt;"))
        XCTAssertTrue(html.contains("&amp; team"))
        XCTAssertFalse(html.contains("<Hiring Manager>"))
        XCTAssertEqual(html.components(separatedBy: "<p>").count - 1, 2, "blank lines separate paragraphs")
        XCTAssertTrue(html.contains("<br />"), "single newlines are preserved inside a paragraph")
    }

    // MARK: - Package assembly

    func testPackageWithNoArtifactsIsResumeOnly() async {
        let package = await ApplicationPackageBuilder.build(
            inputs(coverLetterText: nil, answers: []),
            renderPDF: { _, _ in XCTFail("no cover letter to render"); throw CancellationError() }
        )

        XCTAssertEqual(package.fileURLs.count, 1)
        XCTAssertEqual(package.fileURLs.first?.lastPathComponent, "Jane Doe - Resume - Acme.pdf")
        XCTAssertFalse(package.includedCoverLetter)
        XCTAssertFalse(package.includedScreeningAnswers)
        XCTAssertFalse(package.coverLetterFailed)
    }

    func testPackageIncludesCoverLetterAndAnswersWhenTheyExist() async {
        var renderedFilename: String?
        let package = await ApplicationPackageBuilder.build(
            inputs(coverLetterText: "Dear Hiring Manager,", answers: [answer(id: 0, question: "Why?", answer: "Fit.")]),
            renderPDF: { _, filename in
                renderedFilename = filename
                return try Self.stubFile(named: filename)
            }
        )

        XCTAssertEqual(renderedFilename, "Jane Doe - Cover Letter - Acme.pdf")
        XCTAssertEqual(
            package.fileURLs.map(\.lastPathComponent),
            [
                "Jane Doe - Resume - Acme.pdf",
                "Jane Doe - Cover Letter - Acme.pdf",
                "Screening Answers - Acme.txt",
            ]
        )
        XCTAssertTrue(package.includedCoverLetter)
        XCTAssertTrue(package.includedScreeningAnswers)
        XCTAssertFalse(package.coverLetterFailed)

        let answersURL = try? XCTUnwrap(package.fileURLs.last)
        let written = answersURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        XCTAssertEqual(written?.contains("Fit."), true)
    }

    /// The résumé is the export. A cover letter that cannot be rendered degrades the
    /// package, it never fails it.
    func testCoverLetterRenderFailureStillShipsTheResume() async {
        let package = await ApplicationPackageBuilder.build(
            inputs(coverLetterText: "Dear Hiring Manager,", answers: []),
            renderPDF: { _, _ in throw HTMLPDFExporterError.timedOut }
        )

        XCTAssertEqual(package.fileURLs.map(\.lastPathComponent), ["Jane Doe - Resume - Acme.pdf"])
        XCTAssertFalse(package.includedCoverLetter)
        XCTAssertTrue(package.coverLetterFailed)
    }

    func testWhitespaceOnlyCoverLetterIsNotRendered() async {
        let package = await ApplicationPackageBuilder.build(
            inputs(coverLetterText: "  \n ", answers: []),
            renderPDF: { _, _ in XCTFail("empty text must not reach the renderer"); throw CancellationError() }
        )

        XCTAssertEqual(package.fileURLs.count, 1)
        XCTAssertFalse(package.includedCoverLetter)
        XCTAssertFalse(package.coverLetterFailed, "nothing to render is not a failure")
    }

    func testPackageAlwaysShipsTheResumeEvenWhenItCannotBeRenamed() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("package-tests-missing-\(UUID().uuidString).pdf")
        let package = await ApplicationPackageBuilder.build(
            ApplicationPackageInputs(
                optimizationId: "opt-1",
                resumePDFURL: missing,
                candidateName: "Jane Doe",
                jobTitle: "Product Manager",
                company: "Acme",
                coverLetterText: nil,
                screeningAnswers: []
            ),
            renderPDF: { _, _ in throw CancellationError() }
        )

        XCTAssertEqual(package.fileURLs, [missing], "falls back to the original résumé URL")
    }

    // MARK: - Helpers

    private func inputs(
        coverLetterText: String?,
        answers: [SubmitPackageCachedScreeningAnswer]
    ) -> ApplicationPackageInputs {
        ApplicationPackageInputs(
            optimizationId: "opt-1",
            resumePDFURL: resumeURL,
            candidateName: "Jane Doe",
            jobTitle: "Product Manager",
            company: "Acme",
            coverLetterText: coverLetterText,
            screeningAnswers: answers
        )
    }

    private func answer(
        id: Int,
        question: String,
        answer: String,
        evidence: [String] = [],
        note: String? = nil
    ) -> SubmitPackageCachedScreeningAnswer {
        SubmitPackageCachedScreeningAnswer(
            id: id,
            question: question,
            answer: answer,
            evidenceUsed: evidence,
            confidenceNote: note
        )
    }

    private static func stubFile(named filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("package-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(filename)
        try Data("%PDF-1.4 stub".utf8).write(to: file)
        return file
    }
}
