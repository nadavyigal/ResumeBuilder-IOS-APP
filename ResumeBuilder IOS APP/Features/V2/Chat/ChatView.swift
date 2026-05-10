import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Bindable private var resumeViewModel: OptimizedResumeViewModel
    @State private var vm: ChatViewModel
    @State private var compose = ""

    init(resumeViewModel: OptimizedResumeViewModel) {
        let oid = resumeViewModel.optimizationIdentifier ?? ""
        _resumeViewModel = Bindable(wrappedValue: resumeViewModel)
        _vm = State(
            wrappedValue: ChatViewModel(
                optimizationId: oid,
                resumeId: resumeViewModel.resumeId
            )
        )
    }

    private var optimizationReady: Bool {
        !(resumeViewModel.optimizationIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if optimizationReady {
                chatContent
            } else {
                ContentUnavailableView(
                    "Chat unavailable",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("Optimization id missing — return and run Optimize first.")
                )
                .foregroundStyle(AppColors.textPrimary)
                .padding()
            }
        }
        .screenBackground(showRadialGlow: false)
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            if !vm.pendingChanges.isEmpty {
                atsSuggestionsBanner
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                        ForEach(vm.messages) { bubble in
                            MessageRow(bubble: bubble)
                                .id(bubble.id)
                        }

                        if vm.showsTypingDots {
                            ChatTypingDots()
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        if !vm.streamingAssistantBuffer.isEmpty && vm.isStreaming {
                            streamingTail
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        Color.clear.frame(height: 24).id("bottom")
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.lg)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: vm.streamingAssistantBuffer) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.appCaption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AppSpacing.md)
                    .multilineTextAlignment(.center)
            }

            Divider().opacity(0.15)

            ChatInputBar(
                text: $compose,
                isSending: vm.isStreaming,
                onSend: {
                    let text = compose
                    compose = ""
                    Task {
                        await vm.sendMessage(text: text, token: appState.session?.accessToken)
                    }
                }
            )
            .padding(.bottom, AppSpacing.sm)
        }
        .sheet(isPresented: $vm.showPendingReview) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        ForEach(vm.pendingChanges) { item in
                            PendingChangeCard(
                                model: item,
                                isProcessing: vm.isStreaming || item.status == .applying,
                                onAccept: {
                                    Task {
                                        await vm.approve(
                                            suggestionId: item.suggestionId,
                                            token: appState.session?.accessToken,
                                            mergeInto: resumeViewModel
                                        )
                                    }
                                },
                                onReject: {
                                    vm.reject(suggestionId: item.suggestionId)
                                }
                            )
                            .padding(.horizontal, AppSpacing.lg)
                        }
                    }
                    .padding(.vertical, AppSpacing.lg)
                    .screenBackground(showRadialGlow: false)
                }
                .navigationTitle("Review Changes")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { vm.showPendingReview = false }
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private var streamingTail: some View {
        HStack {
            Text(vm.streamingAssistantBuffer)
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
                .padding(AppSpacing.md)
                .glassCard(cornerRadius: AppRadii.lg)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.accentSky.opacity(0.8))
                        .padding(10)
                        .accessibilityHidden(true)
                }
            Spacer(minLength: 44)
        }
    }

    private var atsSuggestionsBanner: some View {
        Button {
            vm.showPendingReview = true
        } label: {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.accentSky)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested resume updates (\(vm.pendingChanges.count))")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Review changes before approving")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text("Review Changes")
                    .font(.appCaption.bold())
                    .foregroundStyle(AppColors.accentSky)
            }
            .padding(AppSpacing.md)
            .glassCard(cornerRadius: AppRadii.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                    .strokeBorder(AppColors.accentSky.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }
}

private struct MessageRow: View {
    let bubble: ChatViewModel.Bubble

    var body: some View {
        HStack {
            if bubble.role == .user { Spacer(minLength: 40) }

            Text(bubble.text)
                .font(.appBody)
                .foregroundStyle(bubble.role == .user ? Color.white : AppColors.textPrimary)
                .multilineTextAlignment(bubble.role == .user ? .trailing : .leading)
                .textSelection(.enabled)
                .padding(AppSpacing.md)
                .background {
                    Group {
                        if bubble.role == .user {
                            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                                .fill(AppGradients.primary)
                        } else {
                            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                                .fill(AppColors.glassTint)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                                        .stroke(AppColors.glassStroke, lineWidth: 1)
                                )
                        }
                    }
                }

            if bubble.role == .ai { Spacer(minLength: 40) }
        }
    }
}

private struct ChatTypingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: false)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 3
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppColors.textTertiary.opacity(i <= tick ? 0.92 : 0.28))
                        .frame(width: 7, height: 7)
                }
                Text("Typing…")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
        }
        .padding(.leading, AppSpacing.sm)
    }
}

private struct ChatInputBar: View {
    @Binding var text: String
    var isSending: Bool
    var onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            TextField("Ask AI to tweak your optimized resume…", text: $text, axis: .vertical)
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1...8)
                .padding(AppSpacing.md)
                .glassCard(cornerRadius: AppRadii.md)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColors.textPrimary, AppGradients.primary)
            }
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
            .opacity(isSending ? 0.45 : 1)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }
}

#Preview("Chat stub") {
    NavigationStack {
        ChatView(
            resumeViewModel: OptimizedResumeViewModel(
                optimizationId: "opt-preview",
                resumeId: "resume-preview",
                sections: [.init(id: "s1", type: .summary, body: "Engineer.", status: "optimized")]
            )
        )
    }
    .environment(AppState())
}
