// ResumeBuilder IOS APP/Ambassador/AmbassadorBanner.swift
// Plan 4: Ambassador Flow — in-app banner shown at top of home screen
//
// SKELETON — implement when gate opens.
//
// UX spec:
//   - NOT a modal — dismissible without commitment, shown at top of home screen
//   - Copy: "Did you land the interview? 🎯"
//   - Two action buttons: "Yes!" and "Not yet"
//   - "Yes!" → opens AmbassadorSuccessView as a sheet
//   - "Not yet" → dismisses banner, marks not_yet, no follow-up for 7 days

import SwiftUI

struct AmbassadorBanner: View {
    @Environment(AmbassadorManager.self) private var ambassadorManager
    var exportID: String
    var userID: String
    @State private var showSuccessView = false

    var body: some View {
        // TODO: Implement
        VStack {
            Text("Did this application move forward? 🎯")
            HStack {
                Button("Yes!") {
                    showSuccessView = true
                }
                Button("Not yet") {
                    Task { await ambassadorManager.markNotYet(exportID: exportID, userID: userID) }
                }
            }
        }
        .sheet(isPresented: $showSuccessView) {
            AmbassadorSuccessView(exportID: exportID, userID: userID)
        }
    }
}
