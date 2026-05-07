import SwiftUI

struct BulletDiffRow: View {
    let original: String
    let optimized: String
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Original ──────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Label("Original", systemImage: "minus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text(original)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Divider()
                .background(Theme.textTertiary.opacity(0.3))

            // ── Suggested ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Label("Suggested", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accentCyan)
                Text(optimized)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            }

            // ── Actions ───────────────────────────────────────────────────────
            HStack(spacing: 12) {
                Button(action: onReject) {
                    Text("Reject")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(.red)
                        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button(action: onAccept) {
                    Text("Accept")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(.white)
                        .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .stroke(Theme.accent.opacity(0.15), lineWidth: 1)
        )
    }
}
