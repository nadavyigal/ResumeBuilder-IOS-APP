import Foundation
import AuthenticationServices
import Supabase
import UIKit

// MARK: - Garmin OAuth bridge

final class GarminBridge: NSObject {
    static let shared = GarminBridge()

    private let supabase = SupabaseManager.client
    private let garminGatewayURL = "https://runsmart-ai.com/garmin/connect"
    private var webAuthSession: ASWebAuthenticationSession?

    func connect() async throws {
        guard let token = try? await supabase.auth.session.accessToken else {
            throw GarminError.notAuthenticated
        }

        var components = URLComponents(string: garminGatewayURL)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        let startURL = components.url!

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: startURL,
                callbackURLScheme: "runsmart"
            ) { callbackURL, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let url = callbackURL,
                      url.host == "garmin",
                      url.path == "/connected" else {
                    continuation.resume()
                    return
                }
                continuation.resume()
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }
    }

    func recentActivities(authUserID: UUID, limit: Int = 10) async -> [DBGarminActivity] {
        do {
            let rows: [DBGarminActivity] = try await supabase
                .from("garmin_activities")
                .select()
                .eq("auth_user_id", value: authUserID.uuidString)
                .order("start_time", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows
        } catch { return [] }
    }

    func latestDailyMetrics(authUserID: UUID) async -> DBGarminDailyMetrics? {
        do {
            let rows: [DBGarminDailyMetrics] = try await supabase
                .from("garmin_daily_metrics")
                .select()
                .eq("auth_user_id", value: authUserID.uuidString)
                .order("date", ascending: false)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch { return nil }
    }

    func connectionStatus(authUserID: UUID) async -> DBGarminConnection? {
        do {
            let rows: [DBGarminConnection] = try await supabase
                .from("garmin_connections")
                .select()
                .eq("auth_user_id", value: authUserID.uuidString)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch { return nil }
    }
}

extension GarminBridge: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow ?? UIWindow()
    }
}

enum GarminError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Sign in before connecting Garmin."
        }
    }
}
