import SwiftUI

enum AIConsentCopy {
    static let title: LocalizedStringKey = "Before we read your résumé"
    static let body: LocalizedStringKey =
        "To check and improve your résumé, Resumely sends your résumé text and the job description to OpenAI, our AI provider. OpenAI processes them to write your results. If you check without an account, we keep the résumé and job text for up to 7 days."
    static let agree: LocalizedStringKey = "Agree and continue"
    static let notNow: LocalizedStringKey = "Not now"
    static let privacyPolicy: LocalizedStringKey = "Privacy Policy"
}

/// Asked once, before the first check sends the résumé and job to OpenAI
/// (`HomeTabView.startCheck`). "Not now", or swiping the sheet away, sends nothing;
/// the next tap asks again.
struct AIConsentSheet: View {
    @Environment(LocalizationManager.self) private var localization
    let onAgree: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.accentTeal)
                    .accessibilityHidden(true)

                Text(AIConsentCopy.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(AIConsentCopy.body)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: LegalLinks.privacyURL(language: localization.language)) {
                    Text(AIConsentCopy.privacyPolicy)
                        .font(.appCaption.weight(.semibold))
                        .underline()
                }
                .foregroundStyle(AppColors.accentSky)
                .accessibilityIdentifier("aiConsent.privacy")

                GradientButton(title: AIConsentCopy.agree, action: onAgree)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityIdentifier("aiConsent.agree")

                Button(action: onNotNow) {
                    Text(AIConsentCopy.notNow)
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("aiConsent.notNow")
            }
            .padding(AppSpacing.lg)
        }
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // A sheet does not inherit the app root's direction (same fix as the check screen).
        .environment(\.layoutDirection, localization.layoutDirection)
        .preferredColorScheme(.dark)
    }
}
