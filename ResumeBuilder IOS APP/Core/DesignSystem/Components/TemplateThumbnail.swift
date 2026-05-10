import SwiftUI

struct TemplateThumbnail: View {
    let name: String
    var thumbnailURL: URL? = nil
    var isSelected: Bool = false
    var isPremium: Bool = false

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 104)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? AnyShapeStyle(AppGradients.primary) : AnyShapeStyle(AppColors.glassStroke),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.textTertiary)
                    )

                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.accentViolet)
                        .padding(4)
                        .background(AppColors.accentViolet.opacity(0.2), in: Circle())
                        .offset(x: 4, y: -4)
                }
            }

            Text(name)
                .font(.appCaption)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        TemplateThumbnail(name: "Classic", isSelected: true)
        TemplateThumbnail(name: "Modern", isPremium: true)
        TemplateThumbnail(name: "Creative", isPremium: true)
    }
    .padding()
    .screenBackground()
}
