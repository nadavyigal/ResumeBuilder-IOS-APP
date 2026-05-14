import SwiftUI

struct TemplateThumbnail: View {
    let name: String
    let category: String
    var thumbnailURL: URL? = nil
    var isSelected: Bool = false
    var isPremium: Bool = false

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                card
                if isPremium {
                    premiumBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(5)
                }
                if isSelected {
                    checkBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(4)
                }
            }
            .frame(width: 92, height: 122)

            Text(name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Card shell

    private var card: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97)

            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        MiniResumeCanvas(category: category)
                    }
                }
            } else {
                MiniResumeCanvas(category: category)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? AnyShapeStyle(AppGradients.primary)
                        : AnyShapeStyle(Color.white.opacity(0.12)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(
            color: isSelected ? AppColors.gradientStart.opacity(0.5) : Color.black.opacity(0.22),
            radius: isSelected ? 12 : 4,
            x: 0, y: 2
        )
    }

    private var premiumBadge: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(5)
            .background(AppColors.accentViolet, in: Circle())
            .offset(x: 4, y: -4)
    }

    private var checkBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 17, height: 17)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(AppColors.gradientStart)
        }
        .offset(x: 4, y: 4)
    }
}

// MARK: - Mini Resume Canvas

/// Abstract line-art preview representing a resume template category.
/// Used when no server thumbnail URL is available.
private struct MiniResumeCanvas: View {
    let category: String

    // Light-mode resume palette (on off-white paper background)
    private let dark   = Color(red: 0.12, green: 0.12, blue: 0.20)
    private let mid    = Color(red: 0.48, green: 0.48, blue: 0.58).opacity(0.55)
    private let light  = Color(red: 0.58, green: 0.58, blue: 0.66).opacity(0.35)
    private let violet = Color(hex: "6C63FF")
    private let teal   = Color(hex: "40E0D0")
    private let sky    = Color(hex: "4EA8FF")

    var body: some View {
        Group {
            switch category.lowercased() {
            case "modern":                         modern
            case "creative":                       creative
            case "corporate":                      corporate
            case "traditional", "ats_safe", "ats-safe": traditional
            default:                               traditional
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Layouts

    private var traditional: some View {
        VStack(spacing: 0) {
            // Centred name + title
            VStack(spacing: 2) {
                fixedBar(w: 54, h: 5, color: dark)
                fixedBar(w: 40, h: 3, color: mid)
                fixedBar(w: 48, h: 2.5, color: light)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 5)

            hRule(mid)
            Spacer().frame(height: 5)
            sectionBlock(accent: violet.opacity(0.7))
            Spacer().frame(height: 5)
            hRule(light)
            Spacer().frame(height: 5)
            sectionBlock(accent: violet.opacity(0.7))
            Spacer()
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modern: some View {
        HStack(spacing: 0) {
            // Accent sidebar
            LinearGradient(colors: [violet, teal], startPoint: .top, endPoint: .bottom)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 0) {
                fullBar(h: 5, color: dark)
                Spacer().frame(height: 2)
                fixedBar(w: 42, h: 3, color: mid)
                Spacer().frame(height: 5)
                hRule(light)
                Spacer().frame(height: 5)
                bodyLines(3)
                Spacer().frame(height: 5)
                hRule(light)
                Spacer().frame(height: 5)
                bodyLines(2)
                Spacer()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var creative: some View {
        VStack(spacing: 0) {
            // Bold gradient header
            ZStack {
                LinearGradient(
                    colors: [violet, sky, teal],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                VStack(spacing: 2) {
                    fixedBar(w: 50, h: 5, color: .white.opacity(0.9))
                    fixedBar(w: 36, h: 2.5, color: .white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)

            // Body with coloured section labels
            VStack(alignment: .leading, spacing: 3) {
                Spacer().frame(height: 3)
                fixedBar(w: 26, h: 3.5, color: violet.opacity(0.85))
                bodyLines(2)
                Spacer().frame(height: 3)
                fixedBar(w: 26, h: 3.5, color: teal.opacity(0.85))
                bodyLines(2)
                Spacer()
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var corporate: some View {
        VStack(spacing: 0) {
            HStack {
                fixedBar(w: 50, h: 5, color: dark)
                Spacer()
                fixedBar(w: 20, h: 3, color: mid)
            }
            .padding(.bottom, 4)

            hRule(dark.opacity(0.2))
            Spacer().frame(height: 5)

            HStack(alignment: .top, spacing: 5) {
                VStack(alignment: .leading, spacing: 3) {
                    fixedBar(w: 24, h: 3.5, color: violet.opacity(0.7))
                    bodyLines(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(light).frame(width: 0.5)

                VStack(alignment: .leading, spacing: 3) {
                    fixedBar(w: 24, h: 3.5, color: violet.opacity(0.7))
                    bodyLines(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Drawing helpers

    private func fixedBar(w: CGFloat, h: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: w, height: h)
    }

    private func fullBar(h: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: h)
    }

    private func hRule(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }

    private func bodyLines(_ count: Int) -> some View {
        VStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { i in
                Group {
                    if i == count - 1 {
                        fixedBar(w: 42, h: 2.5, color: light)
                    } else {
                        fullBar(h: 2.5, color: light)
                    }
                }
            }
        }
    }

    private func sectionBlock(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2.5) {
            fixedBar(w: 26, h: 3.5, color: accent)
            fullBar(h: 2.5, color: light)
            fullBar(h: 2.5, color: light)
            fixedBar(w: 42, h: 2.5, color: light)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        TemplateThumbnail(name: "Classic", category: "traditional", isSelected: true)
        TemplateThumbnail(name: "Modern", category: "modern")
        TemplateThumbnail(name: "Creative", category: "creative", isPremium: true)
        TemplateThumbnail(name: "Corporate", category: "corporate")
    }
    .padding()
    .screenBackground()
}
