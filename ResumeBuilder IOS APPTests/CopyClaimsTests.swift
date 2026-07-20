import XCTest
import SwiftUI
@testable import ResumeBuilder_IOS_APP

/// Guards the ATS-claim copy decisions (DECISIONS.md 2026-06-20): user-facing
/// copy uses the branded Resumely Match Score / Match language, keeps ATS only
/// in process-descriptive form (ATS-friendly), and never presents an "ATS score"
/// or "Free ATS Check" as the product's own metric.
@MainActor
final class CopyClaimsTests: XCTestCase {

    /// Phrases that must not appear in the surveyed user-facing copy.
    /// "ATS-friendly" stays allowed, so fragments are chosen to not match it.
    private let bannedFragments = [
        "ATS check",
        "ATS Check",
        "ATS score",
        "ATS Score",
        "Free ATS",
        "Improve ATS",
        "Improving ATS",
        "ATS insights",
        "ATS-safe",
        "pass ATS",
        "ATS Deep Report",
        "the way an ATS does"
    ]

    private func extractKey(_ key: LocalizedStringKey) -> String {
        for child in Mirror(reflecting: key).children where child.label == "key" {
            if let value = child.value as? String { return value }
        }
        XCTFail("Could not extract key from LocalizedStringKey")
        return ""
    }

    private func assertClean(_ text: String, context: String) {
        for fragment in bannedFragments {
            XCTAssertFalse(
                text.contains(fragment),
                "\(context) contains banned fragment \"\(fragment)\": \(text)"
            )
        }
    }

    // MARK: - Home activation states

    func testActivationHeadlinesUseMatchLanguage() async {
        let states: [HomeActivationState] = [
            .noResume, .resumeNoJob, .readyForFreeATS, .readyToOptimize,
            .atsComplete, .optimizing, .optimizedReady, .exportComplete
        ]
        for state in states {
            assertClean(extractKey(state.headline), context: "headline for \(state)")
            assertClean(extractKey(state.subheadline), context: "subheadline for \(state)")
        }
        XCTAssertEqual(extractKey(HomeActivationState.readyForFreeATS.headline),
                       "Ready for a free Match check")
    }

    // MARK: - Expert workflow copy

    func testExpertWorkflowCopyUsesMatchLanguage() async {
        for workflow in ExpertWorkflowType.allCases {
            assertClean(workflow.displayTitle, context: "displayTitle for \(workflow)")
            assertClean(workflow.cardDescription, context: "cardDescription for \(workflow)")
            assertClean(workflow.purposeText, context: "purposeText for \(workflow)")
        }
        XCTAssertEqual(ExpertWorkflowType.atsOptimizationReport.displayTitle,
                       "Match Deep Report")
        XCTAssertTrue(ExpertWorkflowType.fullResumeRewrite.cardDescription.contains("ATS-friendly"))
    }
}
