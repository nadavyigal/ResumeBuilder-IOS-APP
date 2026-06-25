import SwiftUI

enum UploadFailureReason: Equatable, Sendable {
    case scannedImage
    case wrongType
    case tooLarge
    case generic

    init(error: Error) {
        guard let preflight = error as? UploadFilePreflightError else {
            self = .generic
            return
        }
        switch preflight {
        case .unreadablePDF:
            self = .scannedImage
        case .unsupportedFileType:
            self = .wrongType
        case .fileTooLarge:
            self = .tooLarge
        case .missingFile, .emptyFile:
            self = .generic
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .scannedImage:
            return "We couldn't read that résumé"
        case .wrongType:
            return "That file won't work yet"
        case .tooLarge:
            return "That résumé is too large"
        case .generic:
            return "We couldn't add that résumé"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .scannedImage:
            return "It looks like a scanned image — there's no selectable text, so an ATS can't read it either."
        case .wrongType:
            return "Choose a PDF or DOCX résumé so we can read it reliably."
        case .tooLarge:
            return "Files must be 5 MB or smaller. Export a lighter PDF or DOCX and try again."
        case .generic:
            return "Choose another PDF or DOCX from Files and we'll try again."
        }
    }

    var fileDetail: LocalizedStringKey {
        switch self {
        case .scannedImage:
            return "Image-only · no text layer"
        case .wrongType:
            return "Unsupported type"
        case .tooLarge:
            return "Over 5 MB"
        case .generic:
            return "Needs another try"
        }
    }
}

struct UploadFailureView: View {
    let reason: UploadFailureReason
    let filename: String?
    let onChooseAnother: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                Text("Upload")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: "FFD479"))
                    .frame(width: 64, height: 64)
                    .background(Color(hex: "FFD479").opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))

                Text(reason.title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(reason.message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.accentSky)
                    .frame(width: 38, height: 38)
                    .background(AppColors.accentSky.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(filename ?? "Selected résumé")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(reason.fileDetail)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "FFD479"))
                }
                Spacer()
            }
            .padding(14)
            .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                    .strokeBorder(Color(hex: "FFD479").opacity(0.22), lineWidth: 1)
            )

            VStack(spacing: AppSpacing.sm) {
                disabledAction("Paste the text instead", systemImage: "doc.on.clipboard.fill")

                HStack(spacing: AppSpacing.sm) {
                    Button(action: onChooseAnother) {
                        Label("Choose another file", systemImage: "folder.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    disabledAction("Try a sample", systemImage: "sparkles")
                }
            }

            Text("Tip: in most apps, Export as PDF keeps the text readable.")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: "FFD479").opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func disabledAction(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(AppColors.textTertiary)
            .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Text("Soon")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppColors.backgroundMid, in: Capsule())
                    .offset(x: -6, y: -6)
            }
            .opacity(0.72)
            .accessibilityHint("Coming soon")
    }
}
