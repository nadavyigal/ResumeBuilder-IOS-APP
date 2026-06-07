// ResumeBuilder IOS APP/Ambassador/AmbassadorSuccessView.swift
// Plan 4: Ambassador Flow — full success screen with two CTAs
//
// SKELETON — implement when gate opens.
//
// UX spec:
//   - Heading: "Congrats! 🎉 One step closer to the job."
//   - Primary CTA (filled): "Share on LinkedIn" → LinkedInShareComposer
//   - Secondary CTA (outlined): "Leave a review" → SKStoreReviewController.requestReview()
//   - Below CTAs: "Here's a free export for your next application" → ambassador-reward edge function
//   - Dismiss: X button top right
//   - Marks yes_hired in Supabase when screen appears

import SwiftUI
import StoreKit

struct AmbassadorSuccessView: View {
    @Environment(AmbassadorManager.self) private var ambassadorManager
    @Environment(\.dismiss) private var dismiss
    var exportID: String
    var userID: String
    var atsScoreBefore: Int = 0
    var atsScoreAfter: Int = 0
    var jobTitle: String? = nil

    var body: some View {
        // TODO: Implement
        VStack(spacing: 24) {
            Text("Congrats! 🎉 One step closer to the job.")
                .font(.title2).bold()

            Button("Share on LinkedIn") {
                // TODO: Present LinkedInShareComposer
            }

            Button("Leave a review") {
                // TODO: SKStoreReviewController.requestReview()
            }

            Text("Here's a free export for your next application")
                .font(.footnote)
                .onAppear {
                    Task {
                        // TODO: Call ambassador-reward edge function
                    }
                }
        }
        .task {
            await ambassadorManager.markHired(exportID: exportID, userID: userID)
        }
    }
}
