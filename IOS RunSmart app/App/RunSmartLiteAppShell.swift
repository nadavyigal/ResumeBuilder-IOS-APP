import SwiftUI
import Combine

enum RunSmartSheet: Identifiable {
    case coach(String)
    case secondary(SecondaryDestination)

    var id: String {
        switch self {
        case .coach(let context): "coach-\(context)"
        case .secondary(let dest): "secondary-\(dest.id)"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: RunSmartTab = .today
    @Published var activeSheet: RunSmartSheet?

    func openCoach(context: String) {
        activeSheet = .coach(context)
    }

    func open(_ destination: SecondaryDestination) {
        activeSheet = .secondary(destination)
    }

    func startRun() {
        selectedTab = .run
    }
}

struct RunSmartLiteAppShell: View {
    @StateObject private var router = AppRouter()
    private let services = MockRunSmartServices()

    var body: some View {
        ZStack(alignment: .bottom) {
            RunSmartBackground()

            Group {
                switch router.selectedTab {
                case .today:   TodayTabView()
                case .plan:    PlanTabView()
                case .run:     RunTabView()
                case .profile: ProfileTabView()
                }
            }
            .safeAreaPadding(.bottom, 94)

            CustomTabBar(selectedTab: $router.selectedTab)
        }
        .environmentObject(router)
        .environment(\.runSmartServices, services)
        .preferredColorScheme(.dark)
        .sheet(item: $router.activeSheet) { sheet in
            switch sheet {
            case .coach(let context):
                CoachFlowView(context: context)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .secondary(let destination):
                SecondaryFlowView(destination: destination)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
