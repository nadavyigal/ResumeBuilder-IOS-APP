import SwiftUI

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let icon, !isLoading {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.appSubheadline)
                }

                if icon != nil && !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppGradients.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        GradientButton(title: "Analyze Resume", icon: "wand.and.stars") {}
        GradientButton(title: "Loading...", isLoading: true) {}
    }
    .padding()
    .screenBackground()
}
