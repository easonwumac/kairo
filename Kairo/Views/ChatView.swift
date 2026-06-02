#if canImport(SwiftUI)
import SwiftUI

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    public init(environment: KairoEnvironment = .preview()) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(environment: environment))
    }

    public var body: some View {
        NavigationSplitView {
            historyList
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.startNewThread()
                        } label: {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }
                    }
                }
        } detail: {
            chatSurface
                .navigationTitle(viewModel.currentThread.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
        .task {
            await viewModel.load()
        }
    }

    private var historyList: some View {
        List(selection: Binding(
            get: { viewModel.currentThread.id },
            set: { selectedID in
                guard let selectedID, let thread = viewModel.threads.first(where: { $0.id == selectedID }) else { return }
                viewModel.selectThread(thread)
            }
        )) {
            if viewModel.threads.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Send a message to create your first saved chat.")
                )
            } else {
                ForEach(viewModel.threads) { thread in
                    ChatHistoryRow(thread: thread)
                        .tag(thread.id)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteThread(thread) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var chatSurface: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.currentThread.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                ChatBubble(message: message)
                                if !message.proposedActions.isEmpty {
                                    ProposedActionsStrip(actions: message.proposedActions)
                                        .padding(.horizontal)
                                }
                            }
                            .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Kairo is thinking…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color.gray.opacity(0.08))
                .onChange(of: viewModel.currentThread.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isLoading) { _, _ in
                    scrollToBottom(proxy)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            composer
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask Kairo", text: $viewModel.composerText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isLoading)
                .onSubmit {
                    Task { await viewModel.sendComposerMessage() }
                }

            Button {
                Task { await viewModel.sendComposerMessage() }
            } label: {
                Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            .accessibilityLabel("Send")
        }
        .padding()
        .background(.regularMaterial)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if viewModel.isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastID = viewModel.currentThread.messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct ProposedActionsStrip: View {
    let actions: [AgentAction]
    private let catalog = SandboxActionCatalog()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    if let descriptor = catalog.descriptor(for: action.kind) {
                        HStack(spacing: 6) {
                            Image(systemName: descriptor.supportStatus == .unsupportedBySandbox ? "exclamationmark.triangle" : "checkmark.circle")
                            Text(descriptor.displayName)
                            CapabilityChipView(descriptor: descriptor)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .accessibilityLabel("Action preview: \(descriptor.displayName), \(descriptor.supportStatus.displayName)")
                    }
                }
            }
        }
    }
}

private struct ChatHistoryRow: View {
    let thread: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.title)
                .font(.headline)
                .lineLimit(1)
            Text(thread.lastMessagePreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(thread.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 44) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 6) {
                    if message.status == .failed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text(message.createdAt, style: .time)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }

            if !isUser { Spacer(minLength: 44) }
        }
        .padding(.horizontal)
    }

    private var bubbleColor: Color {
        if isUser { return .accentColor }
        if message.status == .failed { return Color.orange.opacity(0.16) }
        return Color.primary.opacity(0.06)
    }
}
#endif
