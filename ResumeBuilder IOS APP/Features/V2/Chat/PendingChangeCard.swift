import SwiftUI

struct PendingChangeCard: View {
    let model: ChatViewModel.PendingUIModel
    let isProcessing: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text("Tip \(model.change.suggestionNumber)")
                    .font(.appCaption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(AppColors.accentViolet.opacity(0.9), in: Capsule())

                Text(model.change.description)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            Text(model.change.suggestionText)
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textPrimary)

            if let preview = DiffPreview(change: model.change, maxLen: 360) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(preview.sectionLabel)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textTertiary)

                    Text(preview.before)
                        .font(.appCaption)
                        .foregroundStyle(Color.red.opacity(0.92))
                        .strikethrough(true, color: Color.red.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(preview.after)
                        .font(.appCaption)
                        .foregroundStyle(Color.green.opacity(0.94))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.sm)
                .glassCard(cornerRadius: AppRadii.md)
            }

            HStack(spacing: AppSpacing.md) {
                Button(role: nil) {
                    onAccept()
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .font(.appCaption)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.accentTeal, in: RoundedRectangle(cornerRadius: AppRadii.sm))
                }
                .buttonStyle(.plain)
                .disabled(disabledInteractions)

                Button(role: nil) {
                    onReject()
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.sm))
                }
                .buttonStyle(.plain)
                .disabled(disabledInteractions)
            }
        }
        .padding(AppSpacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .strokeBorder(AppColors.accentSky.opacity(0.35), lineWidth: 1)
        )
        .opacity(disabledInteractions ? 0.55 : 1)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var disabledInteractions: Bool {
        isProcessing || model.status != .pending
    }
}

// MARK: - Diff preview helpers

private struct DiffPreview {
    let sectionLabel: String
    let before: String
    let after: String

    init?(change: ChatPendingChange, maxLen: Int) {
        guard let first = change.affectedFields?.first else {
            let combined = Self.trim(change.suggestionText, maxLen: maxLen)
            guard !combined.isEmpty else { return nil }
            self.sectionLabel = "Suggested change"
            self.before = "—"
            self.after = combined
            return
        }
        let label = Self.trim(first.sectionId.nilIfBlank ?? "Resume section", maxLen: 80)
        let beforeTxt = Self.jsonSnippet(first.originalValue, maxLen: maxLen)
        let afterTxt = Self.jsonSnippet(first.newValue ?? first.originalValue, maxLen: maxLen)
        guard !beforeTxt.isEmpty || !afterTxt.isEmpty else { return nil }
        sectionLabel = label
        before = beforeTxt.isEmpty ? "—" : beforeTxt
        after = afterTxt.isEmpty ? before : afterTxt
    }

    private static func trim(_ s: String, maxLen: Int) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > maxLen else { return t }
        let idx = t.index(t.startIndex, offsetBy: maxLen)
        return String(t[..<idx]) + "…"
    }

    private static func jsonSnippet(_ v: JSONValue?, maxLen: Int) -> String {
        guard let v else { return "" }
        let raw: String
        switch v {
        case .string(let s): raw = s
        case .array(let rows):
            raw = rows.compactMap { jsonSnippet($0, maxLen: maxLen).nilIfBlank }.joined(separator: "; ")
        case .object(let dict):
            raw = dict
                .sorted(by: { $0.key < $1.key })
                .prefix(6)
                .map { "\($0.key): \(jsonSnippet($0.value, maxLen: 96))" }
                .joined(separator: "; ")
        case .number(let n):
            raw = NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
        case .bool(let b):
            raw = b ? "true" : "false"
        case .null:
            raw = ""
        }
        return trim(raw, maxLen: maxLen)
    }
}

private extension String {
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
