import SwiftUI
import UniformTypeIdentifiers

struct ScoreView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ScoreViewModel
    @State private var isImporterPresented = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                // Background glow
                RadialGradient(
                    colors: [Theme.accentBlue.opacity(0.12), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 360
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Page header ──────────────────────────────────────
                        pageHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)

                        // ── Feature chips ────────────────────────────────────
                        featureChips
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)

                        // ── Input card ───────────────────────────────────────
                        inputCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                        // ── CTA ──────────────────────────────────────────────
                        ctaButton

                        // ── Processing indicator ─────────────────────────────
                        if viewModel.isLoading {
                            processingView
                                .transition(.scale.combined(with: .opacity))
                        }

                        // ── Error ────────────────────────────────────────────
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // ── Result ───────────────────────────────────────────
                        if let result = viewModel.result {
                            ScoreResultView(result: result, isAuthenticated: appState.isAuthenticated)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // tab bar clearance
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.useSharedJobURLIfNeeded(from: appState)
                withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.selectedResumeURL = url
                    viewModel.selectedResumeName = url.lastPathComponent
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Subviews

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentBlue)
                Text("FREE CHECK")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accentBlue)
                    .kerning(1.2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.accentBlue.opacity(0.12), in: Capsule())

            Text("ATS Score")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.textPrimary, Theme.textSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("See how your resume performs against a job before you apply.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
        }
    }

    private var featureChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scoreFeatures, id: \.icon) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text(feature.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.bgCard, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .scrollClipDisabled()
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            // Resume picker
            Button { isImporterPresented = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                viewModel.selectedResumeName != nil
                                    ? Theme.accent.opacity(0.15)
                                    : Theme.bgPrimary.opacity(0.5)
                            )
                            .frame(width: 36, height: 36)
                        Image(systemName: viewModel.selectedResumeName != nil ? "doc.fill" : "doc.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                viewModel.selectedResumeName != nil ? Theme.accent : Theme.textTertiary
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedResumeName != nil ? "Resume attached" : "Choose Resume PDF")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                viewModel.selectedResumeName != nil ? Theme.textPrimary : Theme.textSecondary
                            )
                        if let name = viewModel.selectedResumeName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(Theme.accentBlue)
                                .lineLimit(1)
                        } else {
                            Text("PDF up to 5 MB")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
                .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            viewModel.selectedResumeName != nil
                                ? Theme.accent.opacity(0.5)
                                : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
            }

            // URL input
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 20)
                TextField("Job post URL or paste description", text: $viewModel.jobDescriptionURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .font(.subheadline)
            }
            .padding(14)
            .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        viewModel.jobDescriptionURL.isEmpty
                            ? Color.white.opacity(0.06)
                            : Theme.accentBlue.opacity(0.4),
                        lineWidth: 1
                    )
            )

            // Paste area
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                viewModel.jobDescription.isEmpty
                                    ? Color.white.opacity(0.06)
                                    : Theme.accent.opacity(0.3),
                                lineWidth: 1
                            )
                    )

                if viewModel.jobDescription.isEmpty {
                    Text("Or paste the full job description here")
                        .foregroundStyle(Theme.textTertiary)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.jobDescription)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 130)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .font(.subheadline)
            }
            .frame(minHeight: 130)
        }
    }

    private var ctaButton: some View {
        Button {
            Task { await viewModel.runScore(appState: appState) }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Run ATS Score")
                            .fontWeight(.bold)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(.white)
            .background(
                viewModel.isLoading
                    ? AnyShapeStyle(Theme.bgCard)
                    : AnyShapeStyle(Theme.brandGradient),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Theme.accent.opacity(viewModel.isLoading ? 0 : 0.35), radius: 12, y: 6)
        }
        .disabled(viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }

    private var processingView: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(Theme.accentBlue)
                .scaleEffect(0.9)
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing resume…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Checking keyword match and ATS signals")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accentBlue.opacity(0.3), lineWidth: 1)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Feature chip data

private struct ScoreFeature {
    let icon: String
    let label: String
}

private let scoreFeatures: [ScoreFeature] = [
    .init(icon: "checkmark.seal", label: "ATS pass rate"),
    .init(icon: "text.magnifyingglass", label: "Keyword match"),
    .init(icon: "chart.bar", label: "Section gaps"),
    .init(icon: "bolt.fill", label: "Quick wins"),
]
