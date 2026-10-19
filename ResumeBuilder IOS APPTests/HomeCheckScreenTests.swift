import XCTest
@testable import ResumeBuilder_IOS_APP

/// Story B of the Home redesign: the check is a full-screen cover whose stages
/// advance once and hold on the last one. The old inline loader cycled its status
/// line every 1.7 seconds forever.
@MainActor
final class HomeCheckScreenTests: XCTestCase {

    // MARK: - Stages

    func testFirstStageWaitsForTheUploadOnTheOptimizePath() {
        XCTAssertEqual(HomeCheckStage.at(elapsed: 30, resumeReadAt: nil, tracksUpload: true), .readingResume)
        XCTAssertEqual(HomeCheckStage.at(elapsed: 6.9, resumeReadAt: 6.8, tracksUpload: true), .readingJob)
    }

    func testAnAlreadyUploadedResumeStillShowsTheFirstStageBriefly() {
        XCTAssertEqual(HomeCheckStage.at(elapsed: 0.5, resumeReadAt: 0, tracksUpload: true), .readingResume)
        XCTAssertEqual(
            HomeCheckStage.at(elapsed: HomeCheckStage.minimumResumeRead, resumeReadAt: 0, tracksUpload: true),
            .readingJob
        )
    }

    func testStagesRunOnTimeWithoutAnUpload() {
        let first = HomeCheckStage.timedResumeRead
        XCTAssertEqual(HomeCheckStage.at(elapsed: 0, resumeReadAt: nil, tracksUpload: false), .readingResume)
        XCTAssertEqual(HomeCheckStage.at(elapsed: first, resumeReadAt: nil, tracksUpload: false), .readingJob)
        XCTAssertEqual(
            HomeCheckStage.at(elapsed: first + HomeCheckStage.readingJobDuration, resumeReadAt: nil, tracksUpload: false),
            .comparing
        )
        XCTAssertEqual(
            HomeCheckStage.at(
                elapsed: first + HomeCheckStage.readingJobDuration + HomeCheckStage.comparingDuration,
                resumeReadAt: nil,
                tracksUpload: false
            ),
            .preparingDiagnosis
        )
    }

    func testStagesNeverGoBackAndHoldOnTheLastOne() {
        for (resumeReadAt, tracksUpload) in [(nil, false), (3.0, true), (0.0, true)] as [(TimeInterval?, Bool)] {
            var previous = HomeCheckStage.readingResume
            for tenth in 0...3_000 {
                let stage = HomeCheckStage.at(
                    elapsed: Double(tenth) / 10,
                    resumeReadAt: resumeReadAt,
                    tracksUpload: tracksUpload
                )
                XCTAssertGreaterThanOrEqual(stage, previous)
                previous = stage
            }
            XCTAssertEqual(previous, .preparingDiagnosis, "a 5-minute check ends on the last stage")
        }
    }

    // MARK: - Job label

    func testJobLabelIsTheLinkSiteOrPastedDescription() {
        XCTAssertEqual(
            HomeCheckJobLabel.from(normalizedURL: "https://www.linkedin.com/jobs/view/4012"),
            .site("linkedin.com")
        )
        XCTAssertEqual(HomeCheckJobLabel.from(normalizedURL: "https://jobs.lever.co/acme/1"), .site("jobs.lever.co"))
        XCTAssertEqual(HomeCheckJobLabel.from(normalizedURL: nil), .pastedDescription)
    }

    func testJobLabelUsesTheLinkWhenBothAreGiven() {
        let evaluation = JobInputPolicy.evaluate(
            description: Array(repeating: "requirement", count: 120).joined(separator: " "),
            urlString: "https://www.linkedin.com/jobs/view/4012"
        )
        XCTAssertEqual(HomeCheckJobLabel.from(normalizedURL: evaluation.normalizedURL), .site("linkedin.com"))
    }

    // MARK: - Cancel

    func testCancellationIsNotAnError() {
        XCTAssertTrue(TailorViewModel.isCancellation(CancellationError()))
        XCTAssertTrue(TailorViewModel.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(TailorViewModel.isCancellation(URLError(.notConnectedToInternet)))
        XCTAssertFalse(TailorViewModel.isCancellation(APIClientError.unauthorized))
    }

    // MARK: - Copy

    func testNoScanLineClaimsParserFormattingChecks() {
        let modes: [ResumeOptimizationLoadingView.Mode] = [.optimization, .atsCheck, .diagnosis, .fitCheck]
        for mode in modes {
            for line in mode.statusMessages {
                XCTAssertFalse(line.localizedCaseInsensitiveContains("parser"), "WP-78 removed this claim: \(line)")
            }
        }
    }

    func testCheckScreenStringsHaveHebrewWithoutEmDashes() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "he", ofType: "lproj"))
        let hebrew = try XCTUnwrap(Bundle(path: path))
        let keys = [
            "Checking your fit",
            "Comparing your résumé with the job requirements.",
            "Reading your résumé",
            "Reading the job",
            "Comparing requirements and experience",
            "Preparing the diagnosis",
            "Pasted description",
            "Résumé",
            "Job",
            "Cancel check",
            "Finished",
            "In progress",
            "Not started yet"
        ]
        for key in keys {
            let value = hebrew.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(value, key, "Hebrew falls back to English for \(key)")
            XCTAssertTrue(
                value.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) },
                "No Hebrew in the translation of \(key): \(value)"
            )
            XCTAssertFalse(key.contains("—") || value.contains("—"), "Em dash in \(key)")
        }
    }
}
