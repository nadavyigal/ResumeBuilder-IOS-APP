import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    var creditsBalance: Int = 0
    var isSigningOut = false

    init() {}
}
