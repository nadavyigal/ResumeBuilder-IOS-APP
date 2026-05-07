import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false
    @State private var latestOptimization: OptimizationItem?
    @State private var profileMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                List {
                    // ── Account section ───────────────────────────────────────
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Theme.brandGradient
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.white)
                                    .font(.body.weight(.medium))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.session?.email ?? "Signed in")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Active account")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .padding(.vertical, 6)

                        Button(role: .destructive) {
                            appState.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        ProfileSectionHeader("Account")
                    }
                    .listRowBackground(Theme.bgCard)

                    // ── Resume section ────────────────────────────────────────
                    Section {
                        if let latestOptimization {
                            NavigationLink {
                                OptimizationDetailView(optimization: latestOptimization)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(latestOptimization.jobTitle ?? "Latest optimized resume")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(latestOptimization.company ?? "Tap to preview and redesign")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Label(profileMessage ?? "No optimized resume yet.", systemImage: "doc.text")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    } header: {
                        ProfileSectionHeader("Latest Resume")
                    }
                    .listRowBackground(Theme.bgCard)

                    // ── Credits section ───────────────────────────────────────
                    if BackendConfig.isMonetizationEnabled {
                        Section {
                            NavigationLink {
                                CreditsView()
                            } label: {
                                Label("View Credits", systemImage: "creditcard")
                                    .foregroundStyle(Theme.textPrimary)
                            }

                            Button {
                                showPaywall = true
                            } label: {
                                Label("Buy Credits", systemImage: "plus.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        } header: {
                            ProfileSectionHeader("Credits")
                        }
                        .listRowBackground(Theme.bgCard)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Theme.bgPrimary)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await loadLatestOptimization()
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                }
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
            }
        }
    }

    @MainActor
    private func loadLatestOptimization() async {
        guard let token = appState.session?.accessToken else { return }
        do {
            let response: OptimizationHistoryResponse = try await appState.apiClient.get(endpoint: .optimizations, token: token)
            latestOptimization = response.resolvedOptimizations.first
            if latestOptimization == nil {
                profileMessage = "Tailor a resume to a job to see it here."
            }
        } catch {
            profileMessage = error.localizedDescription
        }
    }
}

private struct ProfileSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textTertiary)
            .textCase(nil)
    }
}
