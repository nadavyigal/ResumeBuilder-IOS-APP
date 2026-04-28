import Foundation
import SwiftUI

protocol RunSmartServiceProviding: TodayProviding, PlanProviding, CoachChatting, ProfileProviding, RunLogging {}

extension MockRunSmartServices: RunSmartServiceProviding {}

private struct RunSmartServicesKey: EnvironmentKey {
    static let defaultValue: any RunSmartServiceProviding = MockRunSmartServices()
}

extension EnvironmentValues {
    var runSmartServices: any RunSmartServiceProviding {
        get { self[RunSmartServicesKey.self] }
        set { self[RunSmartServicesKey.self] = newValue }
    }
}
