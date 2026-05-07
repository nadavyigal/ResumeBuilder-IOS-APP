import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false
    @State private var latestOptimization: OptimizationItem?
    @State private var profileMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Text(appState.session?.email ?? "Signed in")
                    Button(role: .destructive) {
                        appState.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }

                Section("Resume") {
                    Text(appState.identityDebugSummary())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let latestOptimization {
                        NavigationLink {
                            OptimizationDetailView(optimization: latestOptimization)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(latestOptimization.jobTitle ?? "Latest optimized resume")
                                    .font(.headline)
                                Text(latestOptimization.company ?? "Tap to preview and redesign")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(profileMessage ?? "No optimized resume found yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                if BackendConfig.isMonetizationEnabled {
                    Section("Credits") {
                        NavigationLink("View Credits") {
                            CreditsView()
                        }

                        Button("Buy Credits") {
                            showPaywall = true
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .task {
                await loadLatestOptimization()
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallView()
                }
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
                profileMessage = "No optimized resume found for this Supabase user."
            }
        } catch {
            profileMessage = error.localizedDescription
        }
    }
}
