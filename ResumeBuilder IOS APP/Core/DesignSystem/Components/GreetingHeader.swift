import SwiftUI

struct GreetingHeader: View {
    let name: String
    let screenTitle: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi \(name) 👋")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Text(screenTitle)
                    .font(.appTitle)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()

            Circle()
                .fill(AppColors.gradientMid.opacity(0.25))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(name.prefix(1).uppercased())
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.gradientMid)
                )
        }
    }
}

#Preview {
    GreetingHeader(name: "Nadav", screenTitle: "Your Resume")
        .padding()
        .screenBackground()
}
