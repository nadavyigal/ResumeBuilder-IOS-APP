// ResumeBuilder IOS APP/Ambassador/AmbassadorManager.swift
// Plan 4: Ambassador Flow — trigger, notification scheduling, state management
//
// SKELETON — implement when gate opens (Plan 3 live + cohort 3+ weeks old).
//
// Architecture:
//   - Called from export success handler: schedule(userID:exportID:atsScoreBefore:atsScoreAfter:jobTitle:)
//   - Schedules UNUserNotificationCenter local notification 18 days after export
//   - Notification copy: "Did you land the interview? 🎯"
//   - On app open: checkPendingAmbassador() — show banner if notification window passed
//   - Supabase calls update ambassador_status on user_exports and ambassador_notifications

import Foundation
import UserNotifications

@MainActor
@Observable
final class AmbassadorManager {
    var pendingAmbassadorExportID: String?
    var shouldShowBanner: Bool = false

    static let notificationDelayDays: Int = 18
    static let notificationIdentifierPrefix = "ambassador-"

    func schedule(userID: String, exportID: String, atsScoreBefore: Int, atsScoreAfter: Int, jobTitle: String?) async {
        // TODO: Implement
        // 1. Request UNUserNotificationCenter authorisation if not granted
        // 2. Build UNMutableNotificationContent:
        //    title = "Did you land the interview? 🎯"
        //    body = "Tap to share your win and get a free export credit."
        //    userInfo = ["exportID": exportID, "atsScoreBefore": atsScoreBefore, "atsScoreAfter": atsScoreAfter]
        // 3. Trigger: UNTimeIntervalNotificationTrigger(timeInterval: 18 * 24 * 60 * 60, repeats: false)
        // 4. Schedule via UNUserNotificationCenter.current().add(request)
        // 5. INSERT ambassador_notifications row into Supabase:
        //    { user_id, export_id, scheduled_for: now() + 18 days }
    }

    func checkPendingAmbassador(userID: String) async {
        // TODO: Implement
        // 1. Query ambassador_notifications where user_id = userID
        //    AND scheduled_for <= now()
        //    AND triggered_at IS NULL
        //    AND response IS NULL
        // 2. If row found: set pendingAmbassadorExportID, shouldShowBanner = true
    }

    func markHired(exportID: String, userID: String) async {
        // TODO: Implement — UPDATE user_exports SET ambassador_status = 'yes_hired'
    }

    func markNotYet(exportID: String, userID: String) async {
        // TODO: Implement — UPDATE user_exports SET ambassador_status = 'not_yet'
        // Do not re-trigger for 7 days
    }

    func markDismissed(exportID: String, userID: String) async {
        // TODO: Implement — UPDATE user_exports SET ambassador_status = 'dismissed'
    }
}
