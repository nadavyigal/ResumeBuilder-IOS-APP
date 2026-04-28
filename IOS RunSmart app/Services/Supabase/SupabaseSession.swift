import Foundation
import Combine
import Supabase
import AuthenticationServices
import CryptoKit

// MARK: - Session

@MainActor
final class SupabaseSession: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasCompletedOnboarding = false
    @Published var profile: DBProfile?
    @Published var displayName: String = ""
    @Published var isLoading = true

    let supabase = SupabaseManager.client

    private(set) var onboardingProfile: OnboardingProfile = .empty

    init() {
        Task { await initialize() }
    }

    var currentUserID: UUID? { supabase.auth.currentUser?.id }

    var profileID: UUID? { profile?.id }

    func initialize() async {
        defer { isLoading = false }
        if let user = supabase.auth.currentUser {
            isAuthenticated = true
            await loadProfile(userID: user.id)
        }
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                isAuthenticated = true
                if let uid = session?.user.id {
                    await loadProfile(userID: uid)
                }
            case .signedOut:
                isAuthenticated = false
                hasCompletedOnboarding = false
                profile = nil
                displayName = ""
            default:
                break
            }
        }
    }

    func loadProfile(userID: UUID) async {
        do {
            let rows: [DBProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("auth_user_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value
            if let p = rows.first {
                profile = p
                hasCompletedOnboarding = p.onboardingComplete
                displayName = p.name ?? ""
                onboardingProfile = OnboardingProfile(
                    displayName: p.name ?? "",
                    goal: p.goal,
                    experience: p.experience,
                    weeklyRunDays: p.daysPerWeek,
                    preferredDays: p.preferredTimes,
                    units: "Metric",
                    coachingTone: p.coachingStyle ?? "Motivating",
                    notificationsEnabled: false
                )
            }
        } catch {
            print("[SupabaseSession] loadProfile error:", error)
        }
    }

    func completeOnboarding(_ onboarding: OnboardingProfile) async {
        guard let userID = currentUserID else { return }
        onboardingProfile = onboarding
        let insert = DBProfileInsert(
            authUserId: userID.uuidString,
            name: onboarding.displayName,
            goal: onboarding.supabaseGoal,
            experience: onboarding.supabaseExperience,
            preferredTimes: onboarding.preferredDays,
            daysPerWeek: onboarding.weeklyRunDays,
            coachingStyle: onboarding.supabaseCoachingStyle,
            onboardingComplete: true
        )
        do {
            let rows: [DBProfile] = try await supabase
                .from("profiles")
                .upsert(insert, onConflict: "auth_user_id")
                .select()
                .execute()
                .value
            if let p = rows.first {
                profile = p
                hasCompletedOnboarding = true
                displayName = p.name ?? onboarding.displayName
            }
        } catch {
            print("[SupabaseSession] completeOnboarding error:", error)
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
