import SwiftUI
import UIKit

struct ApplicationDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: ApplicationDetailViewModel
    @State private var showAttachPicker = false
    @State private var expertVM: ExpertModesViewModel? = nil

    private var token: String? { appState.session?.accessToken }

    init(application: ApplicationItem) {
        _vm = State(wrappedValue: ApplicationDetailViewModel(application: application))
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

                if let summary = optimizedAttachmentSummary {
                    Section("Attached resume") {
                        Text(summary.filename)
                            .font(.body)

                        if let url = summary.url {
                            ShareLink(item: url) {
                                Label("Share link", systemImage: "square.and.arrow.up")
                            }
                        }

                        if let url = summary.url {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Label("Open in Safari", systemImage: "safari")
                            }
                        }
                    }
                }

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
        .sheet(isPresented: $showAttachPicker) {
            OptimizeAttachmentPickerView(accessToken: token) { picked in
                Task { await vm.attachOptimizedResume(optimizationHistoryId: picked.id, token: token) }
            }
        }
        .task {
            if let oid = vm.item.optimizationId, !oid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, expertVM == nil {
                expertVM = ExpertModesViewModel(optimizationId: oid, resumeViewModel: nil)
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
    }

    private struct AttachmentSummary {
        let filename: String
        let url: URL?
    }

    private var optimizedAttachmentSummary: AttachmentSummary? {
        let id = vm.item.optimizedResumeId
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
