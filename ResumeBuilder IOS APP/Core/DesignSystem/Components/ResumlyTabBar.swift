import SwiftUI

// MARK: - Tab Definition

enum ResumlyTab: Int, CaseIterable {
    case tailor    = 0
    case optimized = 1
    case design    = 2
    case expert    = 3
    case me        = 4

    var icon: String {
        switch self {
        case .tailor:    return "house.fill"
        case .optimized: return "doc.richtext.fill"
        case .design:    return "paintbrush.fill"
        case .expert:    return "rectangle.stack.badge.person.crop"
        case .me:        return "person.crop.circle"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .tailor:    return "Home"
        case .optimized: return "Optimized"
        case .design:    return "Design"
        case .expert:    return "Expert"
        case .me:        return "Me"
        }
    }

    var accessibilityValue: LocalizedStringKey {
        switch self {
        case .tailor: return "Activation home tab"
        case .optimized: return "Optimized resume tab"
        case .design: return "Design templates tab"
        case .expert: return "Expert tools tab"
        case .me: return "Account tab"
        }
    }
}

// MARK: - Custom Tab Bar

struct ResumlyTabBar: View {
    @Binding var selection: ResumlyTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ResumlyTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(barBackground)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func tabButton(_ tab: ResumlyTab) -> some View {
        let isActive = selection == tab

        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            if reduceMotion {
                selection = tab
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    selection = tab
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .frame(height: 20)
                Text(tab.label)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(isActive ? Color.white : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isActive {
                    Capsule()
                        .fill(AppGradients.cta)
                        .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72), value: selection)
        .accessibilityLabel(Text(tab.label))
        .accessibilityValue(tab.accessibilityValue)
        .accessibilityShowsLargeContentViewer()
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var barBackground: some View {
        Capsule()
            .fill(Theme.bgCard.opacity(0.96))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
    }
}

#Preview {
    ZStack {
        Theme.bgPrimary.ignoresSafeArea()
        VStack {
            Spacer()
            ResumlyTabBar(selection: .constant(.tailor))
        }
    }
}
