import SwiftUI
import UIKit

struct ApplicationDetailView: View {
    var onSwitchTab: (ResumlyTab) -> Void = { _ in }
    @Environment(AppState.self) private var appState
    @State private var vm: ApplicationDetailViewModel
    @State private var showAttachPicker = false
    @State private var expertVM: ExpertModesViewModel? = nil
    @State private var navigateToOptimizedResume = false
    @State private var isDownloadingResume = false
    @State private var resumeShareURL: URL?
    @State private var showResumeShare = false
    @State private var showCopiedCoverLetter = false

    private var token: String? { appState.session?.accessToken }

    init(application: ApplicationItem, onSwitchTab: @escaping (ResumlyTab) -> Void = { _ in }) {
        _vm = State(wrappedValue: ApplicationDetailViewModel(application: application))
        self.onSwitchTab = onSwitchTab
    }

    var body: some View {
        ZStack {
            List {
                Section("Actions") {
                    if vm.item.applyClickedAt == nil {
                        Button {
                            Task { await vm.markApplied(token: token) }
                        } label: {
                            Label(
                                vm.isMarkingApplied ? "Marking…" : "Mark as Applied",
                                systemImage: "checkmark.circle"
                            )
                        }
                        .disabled(vm.isMarkingApplied)
                    } else if let badge = formattedAppliedBadge(from: vm.item.applyClickedAt) {
                        Label(badge, systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Button {
                        showAttachPicker = true
                    } label: {
                        Label(
                            vm.isAttaching ? "Attaching…" : "Attach Optimized Resume",
                            systemImage: "doc.badge.plus"
                        )
                    }
                    .disabled(vm.isAttaching)

                    if let oid = vm.item.optimizationId, !oid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            appState.latestOptimizationId = oid
                            navigateToOptimizedResume = true
                        } label: {
                            Label("View Optimized Resume", systemImage: "doc.richtext")
                        }
                    }

                    if let oid = vm.item.optimizationId, !oid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        NavigationLink {
                            if let evm = expertVM {
                                ExpertModesView(vm: evm)
                            } else {
                                ProgressView("Loading expert analysis…")
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expert Analysis")
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(
                                    vm.expertReportsCount == 0
                                        ? "Run expert workflows for this optimization"
                                        : "\(vm.expertReportsCount) saved report\(vm.expertReportsCount == 1 ? "" : "s")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        LabeledContent("Expert Analysis", value: "Requires optimization linked to this application")
                            .foregroundStyle(.secondary)
                    }
                }

                packageHubSection

                Section("Overview") {
                    LabeledContent("Role", value: vm.item.jobTitle ?? "—")
                    LabeledContent("Company", value: vm.item.companyName ?? "—")
                    LabeledContent("Applied", value: vm.item.appliedDate.map { formattedListDate(from: $0) } ?? "—")
                    if let score = vm.item.atsScore {
                        LabeledContent("ATS score", value: "\(score)%")
                    }
                    LabeledContent("Status", value: vm.item.status ?? "applied")
                }
            }
            .navigationTitle("Application")

            if vm.isLoading {
                ProgressView()
                    .padding(AppSpacing.lg)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.md))
            }
        }
        .navigationDestination(isPresented: $navigateToOptimizedResume) {
            if let oid = vm.item.optimizationId {
                OptimizedResumeView(
                    viewModel: OptimizedResumeViewModel(
                        optimizationId: oid,
                        atsScoreAfter: vm.item.atsScore,
                        jobTitle: vm.item.jobTitle,
                        company: vm.item.companyName
                    ),
                    onSwitchTab: onSwitchTab
                )
            }
        }
        .sheet(isPresented: $showAttachPicker) {
            OptimizeAttachmentPickerView(accessToken: token) { picked in
                Task { await vm.attachOptimizedResume(optimizationHistoryId: picked.id, token: token) }
            }
        }
        .sheet(isPresented: $showResumeShare, onDismiss: { resumeShareURL = nil }) {
            if let resumeShareURL {
                ShareSheet(items: [resumeShareURL])
                    .ignoresSafeArea()
            }
        }
        .task {
            if let oid = vm.item.optimizationId, !oid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, expertVM == nil {
                let resumeVM = OptimizedResumeViewModel(
                    optimizationId: oid,
                    atsScoreAfter: vm.item.atsScore,
                    jobTitle: vm.item.jobTitle,
                    company: vm.item.companyName
                )
                expertVM = ExpertModesViewModel(
                    optimizationId: oid,
                    resumeViewModel: resumeVM,
                    applicationId: vm.item.id
                )
            }
            await vm.refresh(token: token)
        }
        .refreshable {
            await vm.refresh(token: token)
        }
        .alert(
            "Application",
            isPresented: Binding(
                get: { vm.actionError != nil },
                set: { if !$0 { vm.clearActionError() } }
            )
        ) {
            Button("OK", role: .cancel) { vm.clearActionError() }
        } message: {
            Text(vm.actionError ?? "")
        }
        .overlay(alignment: .top) {
            if showCopiedCoverLetter {
                Label("Cover letter copied", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accentTeal, in: Capsule())
                    .padding(.top, AppSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopiedCoverLetter = false }
                        }
                    }
            }
        }
    }

    private struct AttachmentSummary {
        let filename: String
        let url: URL?
    }

    private var optimizedAttachmentSummary: AttachmentSummary? {
        let id = vm.item.optimizedResumeId ?? vm.item.optimizationId
        let link = vm.item.optimizedResumeURL
        guard id != nil || (link?.isEmpty == false) else { return nil }

        let name: String
        if let urlStr = link, let url = URL(string: urlStr) {
            let last = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            name = last.isEmpty ? "Optimized Resume" : last
        } else {
            name = id.map { "Optimization \($0.prefix(8))…" } ?? "Optimized Resume"
        }

        let urlParsed = link.flatMap { URL(string: $0) }
        return AttachmentSummary(filename: name, url: urlParsed)
    }

    @ViewBuilder
    private var packageHubSection: some View {
        Section("Submission Package") {
            if optimizedAttachmentSummary == nil && coverLetterReport == nil && packageJobURL == nil {
                LabeledContent("Package", value: "Attach an optimized resume to complete this application.")
                    .foregroundStyle(.secondary)
            } else {
                if let score = vm.item.atsScore {
                    LabeledContent("ATS match", value: "\(score)% · \(atsStatusLabel(score))")
                }

                if let summary = optimizedAttachmentSummary {
                    LabeledContent("Resume", value: summary.filename)

                    Button {
                        Task { await shareOptimizedResume() }
                    } label: {
                        Label(isDownloadingResume ? "Preparing…" : "Share Resume PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isDownloadingResume)

                    if let url = summary.url {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Label("Open Resume Link", systemImage: "safari")
                        }
                    }
                }

                if let report = coverLetterReport {
                    Button {
                        if let text = report.coverLetterText {
                            UIPasteboard.general.string = text
                            withAnimation { showCopiedCoverLetter = true }
                        }
                    } label: {
                        Label("Copy Cover Letter", systemImage: "doc.on.doc")
                    }
                    .disabled(report.coverLetterText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)

                    if let text = report.coverLetterText {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cover Letter")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(text)
                                .font(.footnote)
                                .textSelection(.enabled)
                                .lineLimit(8)
                        }
                    } else {
                        LabeledContent("Cover Letter", value: report.reportTitle ?? "Saved")
                    }
                }

                if let url = packageJobURL {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Open Job Link", systemImage: "link")
                    }
                }
            }
        }
    }

    private var coverLetterReport: ApplicationExpertReportItem? {
        vm.expertReports.first { report in
            report.workflowType == ExpertWorkflowType.coverLetterArchitect.rawValue
                || report.reportTitle?.localizedCaseInsensitiveContains("cover") == true
                || report.coverLetterText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    private var packageJobURL: URL? {
        guard let raw = vm.item.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(raw)")
    }

    @MainActor
    private func shareOptimizedResume() async {
        guard !isDownloadingResume else { return }
        if let existingURL = optimizedAttachmentSummary?.url {
            resumeShareURL = existingURL
            showResumeShare = true
            return
        }
        guard let oid = vm.item.optimizationId ?? vm.item.optimizedResumeId else {
            vm.actionError = "Attach an optimized resume before sharing."
            return
        }
        guard let token else {
            vm.actionError = "Please sign in first."
            return
        }
        isDownloadingResume = true
        defer { isDownloadingResume = false }
        do {
            resumeShareURL = try await PDFExporter.downloadPDF(optimizationId: oid, token: token)
            showResumeShare = true
        } catch let apiError as APIClientError {
            vm.actionError = apiError.userFacingMessage
        } catch {
            vm.actionError = error.localizedDescription
        }
    }

    private func atsStatusLabel(_ score: Int) -> String {
        if score >= 80 { return "High" }
        if score >= 70 { return "Strong" }
        if score >= 55 { return "Medium" }
        return "Low"
    }

    private func formattedAppliedBadge(from iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let parsers: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        for p in parsers {
            if let d = p.date(from: iso) {
                let fmt = DateFormatter()
                fmt.dateStyle = .long
                fmt.timeStyle = .none
                return "Applied on \(fmt.string(from: d))"
            }
        }
        return "Applied"
    }

    private func formattedListDate(from iso: String) -> String {
        let parsers: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        for p in parsers {
            if let d = p.date(from: iso) {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .none
                return fmt.string(from: d)
            }
        }
        return iso
    }
}
