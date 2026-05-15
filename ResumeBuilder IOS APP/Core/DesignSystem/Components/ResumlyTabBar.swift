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
        case .tailor:    return "wand.and.stars"
        case .optimized: return "doc.richtext.fill"
        case .design:    return "paintbrush.fill"
        case .expert:    return "rectangle.stack.badge.person.crop"
        case .me:        return "person.crop.circle"
        }
    }

    var label: String {
        switch self {
        case .tailor:    return "Tailor"
        case .optimized: return "Optimized"
        case .design:    return "Design"
        case .expert:    return "Expert"
        case .me:        return "Me"
        }
    }
}

// MARK: - Custom Tab Bar

struct ResumlyTabBar: View {
    @Binding var selection: ResumlyTab
    @Namespace private var pill

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
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                selection = tab
            }
        } label: {
            HStack(spacing: isActive ? 6 : 0) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .frame(width: 20, height: 20)

                if isActive {
                    Text(tab.label)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.7).combined(with: .opacity),
                                removal: .scale(scale: 0.7).combined(with: .opacity)
                            )
                        )
                }
            }
            .foregroundStyle(isActive ? Color.white : Theme.textTertiary)
            .padding(.vertical, 10)
            .padding(.horizontal, isActive ? 14 : 10)
            .frame(minWidth: 44, maxWidth: isActive ? .infinity : nil)
            .background {
                if isActive {
                    Capsule()
                        .fill(Theme.brandGradient)
                        .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: selection)
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
