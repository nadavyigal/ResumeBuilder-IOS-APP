import SwiftUI

private struct ApplicationComparePair: Identifiable {
    let left: ApplicationItem
    let right: ApplicationItem
    var id: String { "\(left.id)—\(right.id)" }
}

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false
    @State private var latestOptimization: OptimizationHistoryItem?
    @State private var profileMessage: String?
    @State private var appeared = false

    @State private var applicationsViewModel = ApplicationsViewModel()
    @State private var appSelectionMode = false
    @State private var appSelectedIds = Set<String>()
    @State private var comparePair: ApplicationComparePair?

    private var email: String { appState.session?.email ?? "Signed in" }
    private var initials: String {
        let parts = email.split(separator: "@").first?.split(separator: ".") ?? []
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased().prefix(2).description
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ── Hero header ──────────────────────────────────────
                        heroHeader
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -8)

                        // ── Stats row ────────────────────────────────────────
                        statsRow
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .opacity(appeared ? 1 : 0)

                        // ── Sections ─────────────────────────────────────────
                        VStack(spacing: 14) {
                            latestResumeSection
                            applicationsSection
                            if BackendConfig.isMonetizationEnabled {
                                creditsSection
                            }
                            accountSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                        Spacer(minLength: 100)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .task {
                async let _ = loadLatestOptimization()
                async let _ = applicationsViewModel.load(token: appState.session?.accessToken)
                withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
                    .preferredColorScheme(.dark)
                    .tint(Theme.accent)
            }
            .sheet(item: $comparePair) { pair in
                NavigationStack {
                    ApplicationCompareView(left: pair.left, right: pair.right)
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            // Gradient banner
            Theme.brandGradient
                .opacity(0.85)
                .frame(height: 160)
                .overlay(
                    RadialGradient(
                        colors: [Color.white.opacity(0.15), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 220
                    )
                )

            // Avatar + name
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.bgPrimary)
                        .frame(width: 76, height: 76)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 16, y: 6)

                    Text(initials.isEmpty ? "R" : initials)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.brandGradient)
                }
                .offset(y: 38)

                Spacer().frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .padding(.bottom, 48)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("Active account")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(
                value: latestOptimization != nil ? "1+" : "0",
                label: "Optimized",
                icon: "wand.and.stars",
                color: Theme.accent
            )
            statCell(
                value: latestOptimization.map { "\($0.matchScorePercent)%" } ?? "—",
                label: "Best ATS",
                icon: "gauge.medium",
                color: Theme.accentBlue
            )
            statCell(
                value: "∞",
                label: "Templates",
                icon: "paintbrush.fill",
                color: Theme.accentCyan
            )
        }
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Section: Latest Resume

    private var latestResumeSection: some View {
        ProfileSection(title: "Latest Resume", icon: "doc.text.fill", iconColor: Theme.accent) {
            if let opt = latestOptimization {
                NavigationLink {
                    OptimizedResumeView(
                        viewModel: OptimizedResumeViewModel(
                            optimizationId: opt.id,
                            atsScoreAfter: opt.matchScorePercent,
                            jobTitle: opt.jobTitle,
                            company: opt.company
                        )
                    )
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.accent.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "doc.richtext.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opt.jobTitle ?? "Optimized resume")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(opt.company ?? "Tap to preview")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        ATSScorePill(score: opt.matchScorePercent)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundStyle(Theme.textTertiary)
                    Text(profileMessage ?? "No optimized resume yet.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
            }
        }
    }

    // MARK: - Section: Applications

    private var applicationsSection: some View {
        ProfileSection(title: "My Applications", icon: "tray.full.fill", iconColor: Theme.accentBlue) {
            if applicationsViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if applicationsViewModel.applications.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Tailor a resume to start tracking applications.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(14)
            } else {
                VStack(spacing: 0) {
                    if appSelectionMode {
                        HStack {
                            Button("Cancel") {
                                appSelectionMode = false
                                appSelectedIds.removeAll()
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Button("Compare") {
                                let items = applicationsViewModel.applications.filter { appSelectedIds.contains($0.id) }
                                if items.count == 2 {
                                    comparePair = ApplicationComparePair(left: items[0], right: items[1])
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(appSelectedIds.count == 2 ? Theme.accent : Theme.textTertiary)
                            .disabled(appSelectedIds.count != 2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    ForEach(Array(applicationsViewModel.applications.enumerated()), id: \.element.id) { index, app in
                        Group {
                            if appSelectionMode {
                                Button {
                                    if appSelectedIds.contains(app.id) {
                                        appSelectedIds.remove(app.id)
                                    } else if appSelectedIds.count < 2 {
                                        appSelectedIds.insert(app.id)
                                    }
                                } label: {
                                    applicationRow(app, selected: appSelectedIds.contains(app.id))
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    ApplicationDetailView(application: app)
                                } label: {
                                    applicationRow(app, selected: false)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.55)
                                        .onEnded { _ in
                                            appSelectionMode = true
                                            appSelectedIds = [app.id]
                                        }
                                )
                            }
                        }

                        if index < applicationsViewModel.applications.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
    }

    private func applicationRow(_ app: ApplicationItem, selected: Bool) -> some View {
        HStack(spacing: 12) {
            if appSelectionMode {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                    .font(.system(size: 18))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accentBlue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accentBlue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(app.jobTitle ?? "Untitled Role")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(app.companyName ?? app.appliedDate ?? "—")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if let score = app.atsScore {
                ATSScorePill(score: score)
            }
            if !appSelectionMode {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
    }

    // MARK: - Section: Credits

    private var creditsSection: some View {
        ProfileSection(title: "Credits", icon: "creditcard.fill", iconColor: Theme.accentBlue) {
            VStack(spacing: 0) {
                NavigationLink { CreditsView() } label: {
                    profileRow(icon: "list.bullet.rectangle", label: "View Credits", color: Theme.accentBlue)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 14)

                Button { showPaywall = true } label: {
                    profileRow(icon: "plus.circle.fill", label: "Buy Credits", color: Theme.accent, isAction: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section: Account

    private var accountSection: some View {
        ProfileSection(title: "Account", icon: "person.crop.circle.fill", iconColor: Theme.textTertiary) {
            Button(role: .destructive) {
                appState.signOut()
            } label: {
                profileRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    label: "Sign Out",
                    color: .red,
                    isDestructive: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row helper

    private func profileRow(
        icon: String,
        label: String,
        color: Color,
        isAction: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.subheadline.weight(isDestructive ? .medium : .regular))
                .foregroundStyle(isDestructive ? .red : Theme.textPrimary)
            Spacer()
            if !isDestructive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
    }

    // MARK: - Data

    @MainActor
    private func loadLatestOptimization() async {
        guard appState.session?.accessToken != nil else { return }
        do {
            let response: OptimizationHistoryResponse = try await appState.callWithFreshToken { token in
                try await appState.apiClient.get(
                    endpoint: .optimizations,
                    token: token
                )
            }
            latestOptimization = response.allItems.first
            if latestOptimization == nil {
                profileMessage = "Tailor a resume to a job to see it here."
            }
        } catch {
            profileMessage = error.localizedDescription
        }
    }
}

// MARK: - ATS Score Pill (inline)

private struct ATSScorePill: View {
    let score: Int

    private var color: Color {
        if score >= 80 { return .green }
        if score >= 60 { return Theme.accentBlue }
        return Theme.accent
    }

    var body: some View {
        Text("\(score)%")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Profile Section Container

private struct ProfileSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .kerning(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }
}
