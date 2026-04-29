import Foundation
import SwiftUI
import Supabase

// MARK: - SupabaseRunSmartServices

final class SupabaseRunSmartServices: RunSmartServiceProviding {
    static let shared = SupabaseRunSmartServices()

    private let supabase = SupabaseManager.client
    private let planRepo = TrainingPlanRepository()
    private let healthSync = HealthKitSyncService()

    private var currentUserID: UUID? { supabase.auth.currentUser?.id }

    // MARK: TodayProviding

    func todayRecommendation() async -> TodayRecommendation {
        guard let userID = currentUserID else {
            return TodayRecommendation.placeholder
        }

        async let profileTask = fetchProfile(userID: userID)
        async let metricsTask = latestGarminMetrics(userID: userID)
        async let streakTask = fetchStreak(userID: userID)

        let (dbProfile, metrics, streak) = await (profileTask, metricsTask, streakTask)
        guard let profile = dbProfile else { return TodayRecommendation.placeholder }

        // plans/conversations link via auth UUID (plans.profile_id = auth.uid())
        let activePlan = await planRepo.activePlan(profileID: userID)
        let todayWorkout = activePlan?.todayWorkout

        let readiness: Int
        let readinessLabel: String

        if let bb = metrics?.bodyBattery {
            readiness = min(100, bb)
            readinessLabel = bb > 70 ? "Ready to train" : bb > 40 ? "Moderate energy" : "Low energy — easy day"
        } else {
            let weeklyKm = activePlan?.completedKmThisWeek ?? 0
            readiness = min(95, max(55, 72 + min(18, Int(weeklyKm))))
            readinessLabel = readiness > 80 ? "Ready to train" : "Moderate"
        }

        let coachMessage = await latestCoachMessage(profileID: userID)
            ?? "Ready for your next run. Let's make today count."

        let weeklyDone = String(format: "%.1f", activePlan?.completedKmThisWeek ?? 0)
        let weeklyTotal = String(format: "%.1f", activePlan?.totalKmThisWeek ?? 0)
        let streakDays = streak?.currentStreak ?? 0
        let sleepHours = metrics?.sleepDurationS.map { String(format: "%.0fh %02dm", Double($0) / 3600, ($0 % 3600) / 60) } ?? "--"
        let hrvLabel = metrics?.hrv != nil ? (metrics!.hrv! > 50 ? "Stable" : "Lower") : "--"

        return TodayRecommendation(
            readiness: readiness,
            readinessLabel: readinessLabel,
            workoutTitle: todayWorkout?.workoutTitle ?? "Rest Day",
            distance: todayWorkout.map { String(format: "%.1f km", $0.distance) } ?? "--",
            pace: todayWorkout?.paceLabel ?? "--:--",
            elevation: "--",
            coachMessage: coachMessage,
            weeklyProgress: "\(weeklyDone) / \(weeklyTotal) km",
            streak: "\(streakDays) days",
            recovery: sleepHours,
            hrv: hrvLabel
        )
    }

    // MARK: PlanProviding

    func weeklyPlan() async -> [WorkoutSummary] {
        guard let userID = currentUserID else { return [] }
        guard let activePlan = await planRepo.activePlan(profileID: userID) else { return [] }
        return activePlan.currentWeekWorkouts.map { $0.toWorkoutSummary() }
    }

    // MARK: CoachChatting

    func recentMessages() async -> [CoachMessage] {
        guard let userID = currentUserID else { return [] }
        do {
            let conversations: [DBConversation] = try await supabase
                .from("conversations")
                .select()
                .eq("profile_id", value: userID.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let conv = conversations.first else { return [] }

            let messages: [DBMessage] = try await supabase
                .from("conversation_messages")
                .select()
                .eq("conversation_id", value: conv.id.uuidString)
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
                .value

            return messages.reversed().map { msg in
                CoachMessage(
                    text: msg.content,
                    time: formatRelativeTime(msg.createdAt),
                    isUser: msg.role == "user"
                )
            }
        } catch {
            print("[SupabaseServices] recentMessages error:", error)
            return []
        }
    }

    func send(message: String) async -> CoachMessage {
        CoachMessage(text: message, time: "Just now", isUser: true)
    }

    // MARK: ProfileProviding

    func runnerProfile() async -> RunnerProfile {
        guard let userID = currentUserID,
              let profile = await fetchProfile(userID: userID) else {
            return RunnerProfile(name: "Runner", goal: "--", streak: "--", level: "--", totalRuns: 0, totalDistance: 0, totalTime: "--")
        }

        let streak = await fetchStreak(userID: userID)
        let activePlan = await planRepo.activePlan(profileID: userID)
        let totalKm = activePlan?.completedKmThisWeek ?? 0

        return RunnerProfile(
            name: profile.name ?? "Runner",
            goal: profile.goal.capitalized,
            streak: "\(streak?.currentStreak ?? 0) day streak",
            level: profile.experience.capitalized,
            totalRuns: 0,
            totalDistance: Int(totalKm),
            totalTime: "--"
        )
    }

    func achievements() async -> [Achievement] { [] }

    // MARK: RunLogging

    func currentRunMetrics() async -> [MetricTile] { [] }

    func finishRun() async {}

    // MARK: RouteProviding

    func routeSuggestions() async -> [RouteSuggestion] { [] }

    // MARK: DeviceSyncing

    func deviceStatuses() async -> [ConnectedDeviceStatus] {
        guard let userID = currentUserID else {
            return [
                ConnectedDeviceStatus(provider: "Garmin Connect", state: .disconnected, lastSuccessfulSync: nil, permissions: [], message: nil),
                ConnectedDeviceStatus(provider: "HealthKit", state: .disconnected, lastSuccessfulSync: nil, permissions: [], message: "Tap Connect to grant HealthKit access.")
            ]
        }

        let garmin = await fetchGarminConnection(userID: userID)
        let health = ConnectedDeviceStatus(
            provider: "HealthKit",
            state: .disconnected,
            lastSuccessfulSync: nil,
            permissions: [],
            message: "Tap Connect to grant HealthKit access."
        )
        return [garmin, health]
    }

    func connect(provider: String) async -> ConnectedDeviceStatus {
        guard provider == "Garmin Connect" else {
            return await healthSync.requestAccess()
        }
        do {
            try await GarminBridge.shared.connect()
        } catch {
            print("[SupabaseServices] Garmin connect error:", error)
        }
        if let userID = currentUserID {
            return await fetchGarminConnection(userID: userID)
        }
        return ConnectedDeviceStatus(provider: provider, state: .disconnected, lastSuccessfulSync: nil, permissions: [], message: nil)
    }

    func syncNow(provider: String) async -> ConnectedDeviceStatus {
        guard let userID = currentUserID else {
            return ConnectedDeviceStatus(provider: provider, state: .disconnected, lastSuccessfulSync: nil, permissions: [], message: nil)
        }
        if provider == "Garmin Connect" {
            return await fetchGarminConnection(userID: userID)
        }
        return await healthSync.requestAccess()
    }

    func disconnect(provider: String) async -> ConnectedDeviceStatus {
        ConnectedDeviceStatus(provider: provider, state: .disconnected, lastSuccessfulSync: nil, permissions: [], message: "Disconnected")
    }

    // MARK: HealthSyncing

    func requestHealthAccess() async -> ConnectedDeviceStatus {
        await healthSync.requestAccess()
    }

    func saveToHealth(_ run: RecordedRun) async {
        await healthSync.save(run)
    }

    // MARK: Private helpers

    private func fetchProfile(userID: UUID) async -> DBProfile? {
        do {
            let rows: [DBProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("auth_user_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch { return nil }
    }

    private func latestGarminMetrics(userID: UUID) async -> DBGarminDailyMetrics? {
        do {
            let rows: [DBGarminDailyMetrics] = try await supabase
                .from("garmin_daily_metrics")
                .select()
                .eq("auth_user_id", value: userID.uuidString)
                .order("date", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch { return nil }
    }

    private func fetchStreak(userID: UUID) async -> DBUserStreak? {
        do {
            let rows: [DBUserStreak] = try await supabase
                .from("user_streaks")
                .select()
                .eq("auth_user_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch { return nil }
    }

    private func fetchGarminConnection(userID: UUID) async -> ConnectedDeviceStatus {
        do {
            let rows: [DBGarminConnection] = try await supabase
                .from("garmin_connections")
                .select()
                .eq("auth_user_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value

            if let conn = rows.first {
                let lastSync = conn.lastSyncAt.flatMap { parseISO8601Date($0) }
                let state: DeviceConnectionState = conn.status == "connected" ? .connected : .disconnected
                return ConnectedDeviceStatus(
                    provider: "Garmin Connect",
                    state: state,
                    lastSuccessfulSync: lastSync,
                    permissions: conn.scopes ?? [],
                    message: nil
                )
            }
        } catch {}
        return ConnectedDeviceStatus(provider: "Garmin Connect", state: .disconnected, lastSuccessfulSync: nil, permissions: [], message: nil)
    }

    private func latestCoachMessage(profileID: UUID) async -> String? {
        do {
            let conversations: [DBConversation] = try await supabase
                .from("conversations")
                .select()
                .eq("profile_id", value: profileID.uuidString)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let conv = conversations.first else { return nil }

            let messages: [DBMessage] = try await supabase
                .from("conversation_messages")
                .select()
                .eq("conversation_id", value: conv.id.uuidString)
                .eq("role", value: "assistant")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            return messages.first?.content
        } catch { return nil }
    }

    private func formatRelativeTime(_ isoString: String?) -> String {
        guard let str = isoString, let date = parseISO8601Date(str) else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    private func parseISO8601Date(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}

// MARK: - TodayRecommendation with extra stats

extension TodayRecommendation {
    static let placeholder = TodayRecommendation(
        readiness: 0,
        readinessLabel: "Loading",
        workoutTitle: "Loading",
        distance: "--",
        pace: "--:--",
        elevation: "--",
        coachMessage: "Loading your training data…"
    )
}
