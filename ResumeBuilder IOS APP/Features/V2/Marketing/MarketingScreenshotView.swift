import SwiftUI

enum MarketingScreenshotSlot: Int, CaseIterable, Identifiable {
    case tailor = 1
    case blockers
    case aiEdits
    case templates
    case expert

    var id: Int { rawValue }

    static var current: MarketingScreenshotSlot? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--marketing-screenshot") else { return nil }
        guard
            let slotIndex = arguments.firstIndex(of: "--screenshot-slot"),
            arguments.indices.contains(slotIndex + 1),
            let slotNumber = Int(arguments[slotIndex + 1]),
            let slot = MarketingScreenshotSlot(rawValue: slotNumber)
        else {
            return .tailor
        }

        return slot
    }

    var headline: String {
        switch self {
        case .tailor: return "Your resume, tailored for any job"
        case .blockers: return "See exactly what's blocking you"
        case .aiEdits: return "AI edits that actually fit the role"
        case .templates: return "Templates that pass ATS and impress recruiters"
        case .expert: return "Expert analysis for every section"
        }
    }

    var subline: String {
        switch self {
        case .tailor: return "Paste a posting. See what's blocking you."
        case .blockers: return "ATS scores every section of your resume"
        case .aiEdits: return "Applied section by section, in one tap"
        case .templates: return "Export a polished PDF from your phone"
        case .expert: return "Targeted rewrites at hiring-manager level"
        }
    }

    var caption: String {
        switch self {
        case .tailor: return "AI resume tailor and ATS checker for job seekers"
        case .blockers: return "ATS resume score by section - find the blockers before applying"
        case .aiEdits: return "AI resume optimization by job description - improve bullets and summary"
        case .templates: return "Resume design templates - ATS safe and professionally formatted"
        case .expert: return "Expert resume review with AI rewrite suggestions"
        }
    }
}

struct MarketingScreenshotView: View {
    let slot: MarketingScreenshotSlot

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 410

            ZStack {
                AppGradients.background
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: isCompact ? 18 : 22) {
                    brandHeader
                        .padding(.top, isCompact ? 20 : 26)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(slot.headline)
                            .font(.system(size: isCompact ? 42 : 46, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(slot.subline)
                            .font(.system(size: isCompact ? 19 : 21, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text(slot.caption)
                        .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .padding(.bottom, isCompact ? 18 : 24)
                }
                .padding(.horizontal, isCompact ? 22 : 26)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch slot {
        case .tailor:
            TailorScreenshotPanel()
        case .blockers:
            BlockersScreenshotPanel()
        case .aiEdits:
            AIEditsScreenshotPanel()
        case .templates:
            TemplatesScreenshotPanel()
        case .expert:
            ExpertScreenshotPanel()
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Image("ResumelyMark")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            Text("Resumely")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text("Resume Builder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }
}

private struct TailorScreenshotPanel: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ScoreRingView(score: 72, size: 152, lineWidth: 13, animated: false)

                VStack(alignment: .leading, spacing: 10) {
                    MetricPill(label: "Match", value: "72%", tint: AppColors.accentSky)
                    MetricPill(label: "Quick wins", value: "9", tint: AppColors.accentTeal)
                    MetricPill(label: "Risk", value: "Keywords", tint: AppColors.accentViolet)
                }
            }

            MarketingCard {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingLabel("Job description")
                    Text("Senior Product Designer needed to lead mobile flows, ATS-friendly resume systems, and measurable hiring outcomes.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(3)
                }
            }

            MarketingCard {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingLabel("Resume scan")
                    FixRow(title: "Add role-specific keywords", tone: .amber)
                    FixRow(title: "Sharpen impact metrics", tone: .green)
                    FixRow(title: "Rewrite summary for mobile product", tone: .blue)
                }
            }
        }
    }
}

private struct BlockersScreenshotPanel: View {
    private let rows: [(String, Int, MarketingTone)] = [
        ("Summary", 62, .amber),
        ("Experience", 78, .green),
        ("Skills", 45, .red),
        ("Keywords", 51, .amber)
    ]

    var body: some View {
        VStack(spacing: 14) {
            MarketingCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        MarketingLabel("ATS score")
                        Text("58")
                            .font(.system(size: 80, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Needs keyword and skills alignment")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    ScoreRingView(score: 58, size: 132, lineWidth: 12, animated: false)
                }
            }

            MarketingCard {
                VStack(spacing: 12) {
                    ForEach(rows, id: \.0) { row in
                        ScoreBreakdownRow(title: row.0, score: row.1, tone: row.2)
                    }
                }
            }

            MarketingCard {
                VStack(alignment: .leading, spacing: 11) {
                    MarketingLabel("Top blockers")
                    FixRow(title: "Missing 7 required keywords from the job post", tone: .red)
                    FixRow(title: "Skills section is too generic for the role", tone: .amber)
                }
            }
        }
    }
}

private struct AIEditsScreenshotPanel: View {
    var body: some View {
        VStack(spacing: 14) {
            MarketingCard {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingLabel("Before")
                    Text("Worked on dashboard redesigns and collaborated with engineers to improve user flows.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                }
            }

            MarketingCard(accent: AppColors.accentTeal) {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingLabel("AI rewrite")
                    Text("Led mobile dashboard redesign that cut onboarding drop-off by 18%, partnering with engineering to ship ATS-tracked workflow improvements.")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(4)

                    HStack(spacing: 10) {
                        Text("Impact metrics")
                        Text("Mobile UX")
                        Text("ATS keywords")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accentTeal)
                }
            }

            Button(action: {}) {
                Text("Apply improvement")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(Color.black)
                    .background(AppColors.accentTeal, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TemplatesScreenshotPanel: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TemplateMiniCard(title: "Modern", tint: AppColors.accentSky, selected: true)
                TemplateMiniCard(title: "Classic", tint: AppColors.accentTeal, selected: false)
            }

            MarketingCard {
                ResumeDocumentPreview()
            }

            MarketingCard {
                HStack(spacing: 12) {
                    ExportChip(title: "ATS safe", tint: AppColors.accentTeal)
                    ExportChip(title: "PDF export", tint: AppColors.accentSky)
                    ExportChip(title: "Mobile ready", tint: AppColors.accentViolet)
                }
            }
        }
    }
}

private struct ExpertScreenshotPanel: View {
    var body: some View {
        VStack(spacing: 14) {
            MarketingCard {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingLabel("Expert review")
                    Text("Hiring-manager read")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Your experience section proves ownership, but the first bullet hides the business outcome.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                }
            }

            MarketingCard(accent: AppColors.accentSky) {
                VStack(alignment: .leading, spacing: 12) {
                    MarketingLabel("Recommendation")
                    FixRow(title: "Move revenue impact into the first 8 words", tone: .blue)
                    FixRow(title: "Add scale: team size, users, or budget", tone: .green)
                    FixRow(title: "Replace passive verbs with shipped outcomes", tone: .amber)
                }
            }

            MarketingCard {
                VStack(alignment: .leading, spacing: 10) {
                    MarketingLabel("Suggested rewrite")
                    Text("Increased qualified applications by 23% by rebuilding the resume workflow around role-specific keywords, recruiter language, and measurable outcomes.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(4)
                }
            }
        }
    }
}

private struct MarketingCard<Content: View>: View {
    var accent: Color = Color.white.opacity(0.08)
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(accent.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

private struct MarketingLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppColors.accentTeal)
    }
}

private struct MetricPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
    }
}

private struct FixRow: View {
    let title: String
    let tone: MarketingTone

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tone.color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
    }
}

private struct ScoreBreakdownRow: View {
    let title: String
    let score: Int
    let tone: MarketingTone

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(score)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(tone.color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tone.color)
                        .frame(width: proxy.size.width * CGFloat(score) / 100)
                }
            }
            .frame(height: 8)
        }
    }
}

private struct TemplateMiniCard: View {
    let title: String
    let tint: Color
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(tint).frame(width: 56, height: 6)
                Capsule().fill(Color.white.opacity(0.6)).frame(width: 112, height: 5)
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 92, height: 5)
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 122, height: 5)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(selected ? 0.1 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? tint : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ResumeDocumentPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(Color.black.opacity(0.78)).frame(width: 128, height: 10)
                    Capsule().fill(Color.black.opacity(0.36)).frame(width: 168, height: 6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Capsule().fill(AppColors.accentSky).frame(width: 58, height: 5)
                    Capsule().fill(Color.black.opacity(0.24)).frame(width: 82, height: 5)
                }
            }

            Divider().overlay(Color.black.opacity(0.3))

            ForEach(0..<4, id: \.self) { index in
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(index == 0 ? AppColors.accentTeal : Color.black.opacity(0.62)).frame(width: index == 0 ? 96 : 132, height: 6)
                    Capsule().fill(Color.black.opacity(0.28)).frame(width: 260, height: 5)
                    Capsule().fill(Color.black.opacity(0.2)).frame(width: 230, height: 5)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
    }
}

private struct ExportChip: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.12)))
    }
}

private enum MarketingTone {
    case red
    case amber
    case green
    case blue

    var color: Color {
        switch self {
        case .red: return Color(hex: "FF5C7A")
        case .amber: return Color(hex: "FFB84D")
        case .green: return AppColors.accentTeal
        case .blue: return AppColors.accentSky
        }
    }
}

#Preview("Marketing Screenshot") {
    MarketingScreenshotView(slot: .tailor)
}
