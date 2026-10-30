import SwiftUI

/// A made-up CV, job and Match Score, bundled in the app (pricing v2, S4). It
/// shows what a check gives you with no upload, no server call and no AI cost,
/// so it is on screen at once. It is labelled as an example everywhere and
/// never counts as the user's own score (it does not mark `PaywallMilestones`).
enum SampleCV {
    static let score = 64

    static let person: LocalizedStringKey = "Dana Cohen · Marketing Coordinator · 3 years"
    static let cvLines: [LocalizedStringKey] = [
        "Ran monthly email campaigns for 12,000 subscribers",
        "Grew Instagram followers from 2,000 to 9,000 in a year",
        "Wrote product pages and blog posts with the sales team",
    ]
    static let job: LocalizedStringKey = "Digital Marketing Manager · Tel Aviv"
    static let matches: [LocalizedStringKey] = [
        "Email campaigns",
        "Social media growth",
        "Content writing",
    ]
    static let gaps: [LocalizedStringKey] = [
        "Paid ads budget (Google, Meta)",
        "Leading a team",
        "Reports from analytics tools",
    ]
}

enum SampleCVCopy {
    static let start: LocalizedStringKey = "Try a sample CV"
    static let badge: LocalizedStringKey = "EXAMPLE"
    static let title: LocalizedStringKey = "Sample Match Score"
    static let note: LocalizedStringKey =
        "A made-up example, so you can see what you get. Your own Match Score is an estimate."
    static let cvHeading: LocalizedStringKey = "The CV"
    static let jobHeading: LocalizedStringKey = "The job"
    static let matchesHeading: LocalizedStringKey = "What already matches"
    static let gapsHeading: LocalizedStringKey = "What's missing for this job"
    static let tryYours: LocalizedStringKey = "Now try with your CV"
    static let close: LocalizedStringKey = "Close"
}

struct SampleCVSheet: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.dismiss) private var dismiss
    /// Runs after the sheet is gone: Home opens the file picker.
    let onTryYours: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .top) {
                    Text(SampleCVCopy.badge)
                        .font(.caption.weight(.black))
                        .kerning(1.1)
                        .foregroundStyle(AppColors.accentSky)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(SampleCVCopy.close))
                    .accessibilityIdentifier("sample.close")
                }

                HStack(alignment: .center, spacing: AppSpacing.lg) {
                    // The dial draws the number and "/ 100" itself.
                    ATSDial(score: SampleCV.score)
                        .frame(width: 140, height: 140)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(SampleCVCopy.title)
                            .font(.title3.weight(.black))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(SampleCVCopy.note)
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("sample.score")

                section(SampleCVCopy.cvHeading, icon: "doc.text") {
                    Text(SampleCV.person).font(.subheadline.weight(.semibold))
                    ForEach(Array(SampleCV.cvLines.enumerated()), id: \.offset) { _, line in
                        bullet(line, icon: "circle.fill", color: AppColors.textTertiary, iconSize: 5)
                    }
                }

                section(SampleCVCopy.jobHeading, icon: "briefcase") {
                    Text(SampleCV.job).font(.subheadline.weight(.semibold))
                }

                section(SampleCVCopy.matchesHeading, icon: "checkmark.seal") {
                    ForEach(Array(SampleCV.matches.enumerated()), id: \.offset) { _, line in
                        bullet(line, icon: "checkmark.circle.fill", color: AppColors.accentTeal)
                    }
                }

                section(SampleCVCopy.gapsHeading, icon: "exclamationmark.triangle") {
                    ForEach(Array(SampleCV.gaps.enumerated()), id: \.offset) { _, line in
                        bullet(line, icon: "plus.circle.fill", color: AppColors.accentSky)
                    }
                }

                Button {
                    dismiss()
                    onTryYours()
                } label: {
                    Text(SampleCVCopy.tryYours)
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.white)
                        .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sample.tryYours")
            }
            .padding(AppSpacing.lg)
        }
        .screenBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // A sheet does not inherit the app root's direction (lessons 2026-10-19).
        .environment(\.layoutDirection, localization.layoutDirection)
        .preferredColorScheme(.dark)
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textTertiary)
            content()
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: AppRadii.md)
    }

    private func bullet(_ text: LocalizedStringKey, icon: String, color: Color, iconSize: CGFloat = 14) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// How to turn a LinkedIn profile into a PDF the upload accepts (plan A4).
/// Text only. The steps still need a check on a real iPhone before release.
enum LinkedInHintCopy {
    static let hint: LocalizedStringKey = "No CV file? Save your LinkedIn profile as PDF."
    static let how: LocalizedStringKey = "How?"
    static let title: LocalizedStringKey = "Save your LinkedIn profile as a PDF"
    static let steps: [LocalizedStringKey] = [
        "Open linkedin.com in Safari (not the LinkedIn app) and go to your profile.",
        "Tap More, then Save to PDF.",
        "Save the file to Files, then come back and tap Choose a file.",
    ]
    static let done: LocalizedStringKey = "Got it"
}

struct LinkedInHowSheet: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(LinkedInHintCopy.title)
                .font(.title3.weight(.black))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(Array(LinkedInHintCopy.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(AppColors.accentSky)
                            .frame(minWidth: 18)
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button { dismiss() } label: {
                Text(LinkedInHintCopy.done)
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("linkedin.done")
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .environment(\.layoutDirection, localization.layoutDirection)
        .preferredColorScheme(.dark)
    }
}
