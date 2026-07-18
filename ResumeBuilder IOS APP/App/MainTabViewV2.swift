import SwiftUI

struct MainTabViewV2: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: ResumlyTab = MainTabViewV2.initialTab

    // Stable VM instances — created once, survive tab switches.
    @State private var tailorViewModel = TailorViewModel()
    @State private var designViewModel = DesignViewModel(optimizationId: nil)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep tabs alive to preserve form fields and in-flight async state.
            Group {
                HomeTabView(
                    viewModel: tailorViewModel,
                    onSwitchTab: switchTab,
                    onShowOptimizedPreview: showOptimizedPreview
                )
                    .opacity(selectedTab == .tailor ? 1 : 0)
                    .allowsHitTesting(selectedTab == .tailor)

                OptimizedResumeTabView(isActive: selectedTab == .optimized, onSwitchTab: switchTab)
                    .opacity(selectedTab == .optimized ? 1 : 0)
                    .allowsHitTesting(selectedTab == .optimized)

                DesignTabView(
                    viewModel: designViewModel,
                    isActive: selectedTab == .design,
                    onSwitchTab: switchTab,
                    onPreview: { selectedTab = .optimized }
                )
                .opacity(selectedTab == .design ? 1 : 0)
                .allowsHitTesting(selectedTab == .design)

                ExpertTabView(onSwitchTab: switchTab)
                    .opacity(selectedTab == .expert ? 1 : 0)
                    .allowsHitTesting(selectedTab == .expert)

                ProfileView(isActive: selectedTab == .me, onSwitchTab: switchTab)
                    .opacity(selectedTab == .me ? 1 : 0)
                    .allowsHitTesting(selectedTab == .me)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ResumlyTabBar(selection: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(Theme.accent)
        .overlay(alignment: .top) {
            if appState.optimizationRecoveryState == .recovered {
                optimizationRecoveredBanner
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, AppSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: appState.optimizationRecoveryState)
        .onChange(of: appState.latestOptimizationId) { _, newId in
            syncDesignViewModel(to: newId)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--smoke-open-optimized-tab") {
                selectedTab = .optimized
            }
            #endif
            syncDesignViewModel(to: appState.latestOptimizationId)
        }
    }

    private func switchTab(_ tab: ResumlyTab) {
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                selectedTab = tab
            }
        }
    }

    private func showOptimizedPreview(_ optimizationId: String) {
        guard appState.latestOptimizationId == optimizationId else {
            assertionFailure("The optimization ID must be persisted before preview navigation.")
            return
        }
        switchTab(.optimized)
    }

    private func syncDesignViewModel(to optimizationId: String?) {
        guard designViewModel.optimizationId != optimizationId else { return }
        designViewModel = DesignViewModel(optimizationId: optimizationId)
    }

    private var optimizationRecoveredBanner: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(AppColors.accentCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("Latest optimization restored")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Your Optimized, Design, Expert, and Account tabs are back in sync.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button {
                appState.dismissOptimizationRecoveryNotice()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .accessibilityLabel("Dismiss restored optimization message")
        }
        .padding(AppSpacing.md)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private static var initialTab: ResumlyTab {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--smoke-open-optimized-tab") {
            return .optimized
        }
        #endif
        return .tailor
    }
}

#Preview {
    MainTabViewV2()
        .environment(AppState())
}
