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
        // Resolve the initial session before entering the infinite auth-change stream
        if let session = try? await supabase.auth.session, !session.isExpired {
            isAuthenticated = true
            await loadProfile(userID: session.user.id)
        }
        isLoading = false  // spinner off before stream — defer never fires on an infinite loop

        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let s = session, !s.isExpired {
                    isAuthenticated = true
                    await loadProfile(userID: s.user.id)
                } else {
                    isAuthenticated = false
                    hasCompletedOnboarding = false
                    profile = nil
                    displayName = ""
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
