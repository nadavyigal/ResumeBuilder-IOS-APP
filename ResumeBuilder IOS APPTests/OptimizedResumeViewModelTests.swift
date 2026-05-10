import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class OptimizedResumeViewModelTests: XCTestCase {

    // MARK: - loadSections

    func testLoadSectionsIsNoOpWhenSectionsAlreadyPresent() async {
        let existing = OptimizedResumeSection(id: "s1", type: .summary, body: "Existing", status: "optimized")
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [existing],
            optimizationService: MockResumeOptimizationService()
        )
        // token is nil → guard fails, but sections are non-empty → guard fails first
        await vm.loadSections(token: "tok")
        XCTAssertEqual(vm.sections.count, 1, "Should not overwrite existing sections")
    }

    func testLoadSectionsIsNoOpWithNilToken() async {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            optimizationService: MockResumeOptimizationService()
        )
        XCTAssertTrue(vm.sections.isEmpty)
        await vm.loadSections(token: nil)
        // Guard exits early — no network call, no error
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadSectionsIsNoOpWithNilOptimizationId() async {
        let vm = OptimizedResumeViewModel(
            optimizationId: nil,
            optimizationService: MockResumeOptimizationService()
        )
        await vm.loadSections(token: "tok")
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - plainTextResume

    func testPlainTextResumeJoinsSections() {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            sections: [
                OptimizedResumeSection(id: "s1", type: .summary, body: "Great engineer.", status: "optimized"),
                OptimizedResumeSection(id: "s2", type: .skills, body: "Swift, iOS", status: "optimized"),
            ],
            optimizationService: MockResumeOptimizationService()
        )
        let text = vm.plainTextResume
        XCTAssertTrue(text.contains("SUMMARY"))
        XCTAssertTrue(text.contains("Great engineer."))
        XCTAssertTrue(text.contains("SKILLS"))
        XCTAssertTrue(text.contains("Swift, iOS"))
    }

    // MARK: - rejectRefine

    func testRejectRefineClearsPendingState() {
        let vm = OptimizedResumeViewModel(
            optimizationId: "opt-1",
            optimizationService: MockResumeOptimizationService()
        )
        vm.pendingRefine = (original: "old", suggested: "new")
        vm.activeSectionId = "s1"
        vm.rejectRefine()
        XCTAssertNil(vm.pendingRefine)
        XCTAssertNil(vm.activeSectionId)
    }
}
