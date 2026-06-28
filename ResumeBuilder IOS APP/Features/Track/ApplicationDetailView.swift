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
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    packageHeader
                    applicationSummaryCard
                    internalPackageNotice
                    packageContentsCard
                    packageActionButtons

                    if let report = coverLetterReport {
                        coverLetterCard(report)
                    }

                    secondaryActionsCard
                    overviewCard

                    Spacer(minLength: 100)
                }
                .padding(AppSpacing.lg)
            }
            .screenBackground(showRadialGlow: false)
            .navigationTitle("Submit Package")
            .navigationBarTitleDisplayMode(.inline)

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
                        company: vm.item.companyName,
                        jobURLString: vm.item.sourceURL
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
                    company: vm.item.companyName,
                    jobURLString: vm.item.sourceURL
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

    private var hasPackageContent: Bool {
        optimizedAttachmentSummary != nil || coverLetterReport != nil || packageJobURL != nil
    }

    private var packageHeader: some View {
        Label(
            hasPackageContent ? "Saved to Me" : "Package not complete",
            systemImage: hasPackageContent ? "checkmark.circle.fill" : "tray.full.fill"
        )
        .font(.appHeadline)
        .foregroundStyle(AppColors.accentTeal)
    }

    private var applicationSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(vm.item.jobTitle ?? NSLocalizedString("Target Role", comment: ""))
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(vm.item.companyName ?? NSLocalizedString("Company not specified", comment: ""))
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var internalPackageNotice: some View {
        Text("Saved internally in Me. Nothing was sent automatically; you can share the resume, copy the cover letter, or open the job link when you are ready.")
            .font(.appCaption)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var optimizedAttachmentSummary: AttachmentSummary? {
        let id = vm.item.optimizedResumeId ?? vm.item.optimizationId
        let link = vm.item.optimizedResumeURL
        guard id != nil || (link?.isEmpty == false) else { return nil }

        let name: String
        if let urlStr = link, let url = URL(string: urlStr) {
            let last = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            name = last.isEmpty ? NSLocalizedString("Optimized Resume", comment: "") : last
        } else {
            name = id.map { "Optimization \($0.prefix(8))…" } ?? NSLocalizedString("Optimized Resume", comment: "")
        }

        let urlParsed = link.flatMap { URL(string: $0) }
        return AttachmentSummary(filename: name, url: urlParsed)
    }

    private var packageContentsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Package Contents")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            packageContentRow(
                title: "Resume PDF",
                detail: optimizedAttachmentSummary?.filename,
                icon: "doc.fill",
                isPresent: optimizedAttachmentSummary != nil
            )

            packageContentRow(
                title: "Cover Letter",
                detail: coverLetterReport?.reportTitle,
                icon: "doc.text.fill",
                isPresent: coverLetterReport != nil
            )

            if let url = packageJobURL {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Job Link", systemImage: "link")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(vm.item.sourceURL ?? url.absoluteString)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            } else {
                Label("No job link attached", systemImage: "exclamationmark.triangle.fill")
                    .font(.appCaption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func packageContentRow(title: LocalizedStringKey, detail: String?, icon: String, isPresent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(isPresent ? AppColors.textSecondary : AppColors.textTertiary)
                .frame(width: 20)
            Text(title)
                .font(.appCaption.weight(isPresent ? .semibold : .regular))
                .foregroundStyle(isPresent ? AppColors.textSecondary : AppColors.textTertiary)
            if let detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Spacer(minLength: AppSpacing.sm)
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var packageActionButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            if optimizedAttachmentSummary != nil {
                packageButton(
                    title: isDownloadingResume ? "Preparing…" : "Share Resume PDF",
                    icon: "square.and.arrow.up"
                ) {
                    Task { await shareOptimizedResume() }
                }
                .disabled(isDownloadingResume)
            }

            if let report = coverLetterReport {
                packageButton(title: "Copy Cover Letter", icon: "doc.on.doc") {
                    if let text = report.coverLetterText {
                        UIPasteboard.general.string = text
                        withAnimation { showCopiedCoverLetter = true }
                    }
                }
                .disabled(report.coverLetterText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)
            }

            if let url = packageJobURL {
                packageButton(title: "Submit at Job Link", icon: "safari") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func packageButton(title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.appSubheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .glassCard(cornerRadius: AppRadii.md)
        }
        .buttonStyle(GradientButtonStyle())
    }

    private func coverLetterCard(_ report: ApplicationExpertReportItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Cover Letter")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Text(report.coverLetterText ?? NSLocalizedString("Cover letter saved in this application.", comment: ""))
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var secondaryActionsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Actions")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            if vm.item.applyClickedAt == nil {
                secondaryActionButton(
                    title: vm.isMarkingApplied ? "Marking…" : "Mark as Applied",
                    icon: "checkmark.circle"
                ) {
                    Task { await vm.markApplied(token: token) }
                }
                .disabled(vm.isMarkingApplied)
            } else if let badge = formattedAppliedBadge(from: vm.item.applyClickedAt) {
                Label(badge, systemImage: "checkmark.seal.fill")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.accentTeal)
            }

            secondaryActionButton(
                title: vm.isAttaching ? "Attaching…" : "Attach Optimized Resume",
                icon: "doc.badge.plus"
            ) {
                showAttachPicker = true
            }
            .disabled(vm.isAttaching)

            if let oid = vm.item.optimizationId, !oid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                secondaryActionButton(title: "View Optimized Resume", icon: "doc.richtext") {
                    appState.latestOptimizationId = oid
                    navigateToOptimizedResume = true
                }

                NavigationLink {
                    if let evm = expertVM {
                        ExpertModesView(vm: evm)
                    } else {
                        ProgressView("Loading expert analysis…")
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Expert Analysis")
                                .font(.appBody.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(
                                vm.expertReportsCount == 0
                                    ? "Run expert workflows for this optimization"
                                    : "\(vm.expertReportsCount) saved report\(vm.expertReportsCount == 1 ? "" : "s")"
                            )
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.appCaption.weight(.bold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Label("Expert Analysis requires an optimized resume linked to this application.", systemImage: "wand.and.stars")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func secondaryActionButton(title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.appBody.weight(.semibold))
                .foregroundStyle(AppColors.accentSky)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Overview")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            overviewRow("Role", vm.item.jobTitle ?? "—")
            overviewRow("Company", vm.item.companyName ?? "—")
            overviewRow("Applied", vm.item.appliedDate.map { formattedListDate(from: $0) } ?? "—")
            if let score = vm.item.atsScore {
                overviewRow("Match Score", "\(score)% · \(atsStatusLabel(score))")
            }
            overviewRow("Status", vm.item.status ?? "applied")
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func overviewRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Text(value)
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            vm.actionError = NSLocalizedString("Attach an optimized resume before sharing.", comment: "")
            return
        }
        guard let token else {
            vm.actionError = NSLocalizedString("Please sign in first.", comment: "")
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
                return String(format: NSLocalizedString("Applied on %@", comment: ""), fmt.string(from: d))
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
