import SwiftUI

struct UploadSheetView: View {
    let onBrowseFiles: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didProceedToFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.sm)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Add your résumé")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("PDF or DOCX, up to 5 MB. We'll read it the way an ATS does.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                didProceedToFiles = true
                dismiss()
                onBrowseFiles()
            } label: {
                Label("Browse Files", systemImage: "folder.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(.white)
                    .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                    .shadow(color: AppColors.accentSky.opacity(0.42), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the iOS Files picker")

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Résumés usually live in")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(AppColors.textTertiary)

                HStack(spacing: AppSpacing.sm) {
                    uploadLocationChip("iCloud Drive", systemImage: "icloud.fill")
                    uploadLocationChip("Downloads", systemImage: "arrow.down.circle.fill")
                    uploadLocationChip("Mail", systemImage: "envelope.fill")
                }
            }

            dividerLabel("no file handy?")

            VStack(spacing: AppSpacing.sm) {
                disabledRouteRow(
                    title: "Paste résumé text",
                    subtitle: "Copy from anywhere — works great",
                    systemImage: "doc.on.clipboard.fill",
                    tint: AppColors.accentViolet,
                    route: "paste_text"
                )

                disabledRouteRow(
                    title: "Try a sample résumé",
                    subtitle: "See a real diagnosis in 20 seconds",
                    systemImage: "sparkles",
                    tint: AppColors.accentCyan,
                    route: "sample_resume"
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.bottom, AppSpacing.lg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .background(
            LinearGradient(
                colors: [AppColors.backgroundMid, AppColors.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .onDisappear {
            guard !didProceedToFiles else { return }
            AnalyticsService.shared.track(.resumeUploadSheetDismissed(source: "home"))
        }
    }

    private func uploadLocationChip(_ title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.accentSky)
                .frame(height: 24)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                .strokeBorder(AppColors.glassStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityHint("Suggested place to look for your résumé")
    }

    private func dividerLabel(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: AppSpacing.md) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }

    private func disabledRouteRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        route: String
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tint.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppSpacing.sm) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Coming soon")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.18), in: Capsule())
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .strokeBorder(AppColors.glassStroke, lineWidth: 1)
        )
        .opacity(0.72)
        .contentShape(Rectangle())
        .onTapGesture {
            AnalyticsService.shared.track(.resumeUploadComingSoonTapped(route: route))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityHint("Coming soon")
    }
}

#Preview {
    UploadSheetView(onBrowseFiles: {})
}
