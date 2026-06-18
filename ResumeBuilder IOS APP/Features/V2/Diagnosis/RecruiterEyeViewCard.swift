import SwiftUI

@MainActor
struct RecruiterEyeViewCard: View {
    let review: RecruiterReview

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("Recruiter 7-second view", systemImage: "eye.fill")
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(AppColors.accentTeal)

                Text(review.impression)
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                chipRow(title: "Strengths", icon: "plus.circle.fill", values: review.strengths, color: AppColors.accentTeal)
                chipRow(title: "Concerns", icon: "exclamationmark.circle.fill", values: review.concerns, color: AppColors.accentSky)
            }

            Label(review.nextFix, systemImage: "arrow.forward.circle.fill")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .accessibilityElement(children: .combine)
    }

    private func chipRow(title: String, icon: String, values: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(title, systemImage: icon)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(color)

            FlowLayout(spacing: AppSpacing.xs) {
                ForEach(Array(values.prefix(4).enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 1))
                }
            }
        }
    }
}

struct FlowLayout: Layout, Sendable {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 320, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + item.frame.minY),
                proposal: ProposedViewSize(item.frame.size)
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (items: [(index: Int, frame: CGRect)], size: CGSize) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var items: [(index: Int, frame: CGRect)] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            items.append((index, CGRect(origin: CGPoint(x: x, y: y), size: size)))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (items, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

#Preview {
    RecruiterEyeViewCard(review: ResumeDiagnosis.sample().recruiterReview)
        .padding()
        .screenBackground(showRadialGlow: false)
        .preferredColorScheme(.dark)
}
