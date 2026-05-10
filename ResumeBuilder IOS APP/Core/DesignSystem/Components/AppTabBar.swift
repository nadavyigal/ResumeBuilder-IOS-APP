import SwiftUI

enum AppTab: Int, CaseIterable {
    case home, scan, improve, design, history, profile

    var title: String {
        switch self {
        case .home:    return "Home"
        case .scan:    return "Scan"
        case .improve: return "Improve"
        case .design:  return "Design"
        case .history: return "History"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .scan:    return "doc.viewfinder.fill"
        case .improve: return "wand.and.stars"
        case .design:  return "paintbrush.fill"
        case .history: return "clock.arrow.circlepath"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? AnyShapeStyle(AppGradients.primary)
                                    : AnyShapeStyle(AppColors.textSecondary)
                            )
                            .scaleEffect(selectedTab == tab ? 1.1 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)

                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                selectedTab == tab ? AppColors.textPrimary : AppColors.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: AppRadii.glass, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.glass, style: .continuous)
                        .fill(AppColors.glassTint)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.glass, style: .continuous)
                        .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        }
        .glassShadow()
    }
}

#Preview {
    @Previewable @State var tab: AppTab = .home
    AppTabBar(selectedTab: $tab)
        .screenBackground()
}
