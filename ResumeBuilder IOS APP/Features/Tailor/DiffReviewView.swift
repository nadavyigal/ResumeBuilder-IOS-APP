import SwiftUI
import Observation

struct DiffReviewView: View {
    @Environment(AppState.self) private var appState
    let reviewId: String
    @State private var viewModel = DiffReviewViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Loading review...")
            }

            if let review = viewModel.review {
                Text(review.jobDescription?.title ?? "Optimization Review")
                    .font(.title2.bold())
                Text([review.jobDescription?.company, review.jobDescription?.sourceURL].compactMap { $0 }.joined(separator: " • "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let score = viewModel.afterScore {
                    ATSDial(score: score)
                        .frame(height: 120)
                }

                ForEach(viewModel.changeGroups) { group in
                    BulletDiffRow(
                        original: group.original,
                        optimized: group.optimized,
                        onAccept: { viewModel.accept(group.id) },
                        onReject: { viewModel.reject(group.id) }
                    )
                }

                if viewModel.changeGroups.isEmpty {
                    ResumePreviewCard(snapshot: viewModel.resumeSnapshot)
                }

                Button {
                    Task { await viewModel.apply(token: appState.session?.accessToken) }
                } label: {
                    if viewModel.isApplying {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Apply Accepted Changes")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isApplying || viewModel.acceptedGroupIds.isEmpty)
            }

            if let optimizationId = viewModel.appliedOptimizationId {
                NavigationLink("Design Optimized Resume") {
                    DesignTemplatesView(optimizationId: optimizationId, snapshot: viewModel.resumeSnapshot)
                }
                .buttonStyle(.bordered)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .task(id: reviewId) {
            await viewModel.load(reviewId: reviewId, token: appState.session?.accessToken)
        }
    }
}

struct ReviewChangeGroup: Identifiable, Sendable {
    let id: String
    let original: String
    let optimized: String
}

@Observable
@MainActor
final class DiffReviewViewModel {
    var review: OptimizationReviewResponse?
    var changeGroups: [ReviewChangeGroup] = []
    var acceptedGroupIds: Set<String> = []
    var rejectedGroupIds: Set<String> = []
    var isLoading = false
    var isApplying = false
    var appliedOptimizationId: String?
    var errorMessage: String?

    private let apiClient = APIClient()
    private var reviewId: String?

    var afterScore: Int? {
        guard let object = review?.review.atsPreviewJSON?.objectValue else { return nil }
        return object["after"]?.intValue ?? object["optimized"]?.intValue
    }

    var resumeSnapshot: ResumeSnapshot {
        ResumeSnapshot(
            id: appliedOptimizationId ?? reviewId ?? UUID().uuidString,
            title: review?.jobDescription?.title ?? "Optimized Resume",
            subtitle: review?.jobDescription?.company ?? "Resume preview",
            matchScore: afterScore,
            json: review?.review.optimizedResumeJSON
        )
    }

    func load(reviewId: String, token: String?) async {
        guard let token else {
            errorMessage = "Please sign in first."
            return
        }
        self.reviewId = reviewId
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: OptimizationReviewResponse = try await apiClient.get(endpoint: .optimizationReview(reviewId), token: token)
            review = response
            changeGroups = Self.extractChangeGroups(from: response.review.groupedChangesJSON)
            acceptedGroupIds = Set(changeGroups.map(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func accept(_ id: String) {
        rejectedGroupIds.remove(id)
        acceptedGroupIds.insert(id)
    }

    func reject(_ id: String) {
        acceptedGroupIds.remove(id)
        rejectedGroupIds.insert(id)
    }

    func apply(token: String?) async {
        guard let token, let reviewId else {
            errorMessage = "Please sign in first."
            return
        }

        struct ApplyRequest: Encodable {
            let approvedGroupIds: [String]
        }

        isApplying = true
        errorMessage = nil
        defer { isApplying = false }

        do {
            let response: ApplyReviewResponse = try await apiClient.postCodable(
                endpoint: .applyOptimizationReview(reviewId),
                body: ApplyRequest(approvedGroupIds: Array(acceptedGroupIds)),
                token: token
            )
            appliedOptimizationId = response.optimizationId
            if appliedOptimizationId == nil {
                errorMessage = response.error ?? "Apply completed without an optimization id."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func extractChangeGroups(from json: JSONValue?) -> [ReviewChangeGroup] {
        guard let json else { return [] }
        let values: [JSONValue]
        if let array = json.arrayValue {
            values = array
        } else if let object = json.objectValue {
            values = object.values.flatMap { $0.arrayValue ?? [$0] }
        } else {
            values = []
        }

        return values.enumerated().compactMap { index, value in
            guard let object = value.objectValue else { return nil }
            let id = object["id"]?.stringValue ?? object["groupId"]?.stringValue ?? "group-\(index)"
            let original = object["original"]?.stringValue
                ?? object["before"]?.stringValue
                ?? object["current"]?.stringValue
                ?? "Original resume content"
            let optimized = object["optimized"]?.stringValue
                ?? object["after"]?.stringValue
                ?? object["suggested"]?.stringValue
                ?? "Optimized resume content"
            return ReviewChangeGroup(id: id, original: original, optimized: optimized)
        }
    }
}
