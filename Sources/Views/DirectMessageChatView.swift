import SwiftUI

struct DirectMessageChatView: View {
    let friend: FriendItem
    @EnvironmentObject var store: AppStore
    @State private var messageText = ""
    @State private var timer: Timer? = nil
    @State private var isSending = false
    @State private var sendError: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat history list
            ScrollViewReader { proxy in
                ScrollView {
                    let messages = store.directMessages[friend.id] ?? []
                    VStack(spacing: 12) {
                        if messages.isEmpty {
                            Text("Chưa có tin nhắn nào. Hãy gửi lời chào!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(messages) { msg in
                                let isMe = msg.senderId != friend.id
                                HStack {
                                    if isMe { Spacer() }
                                    
                                    VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                                        Text(msg.content)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(isMe ? Theme.accent : Color(.secondarySystemBackground))
                                            .foregroundStyle(isMe ? .white : .primary)
                                            .cornerRadius(18)
                                        
                                        Text(formatTime(msg.createdAt))
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 4)
                                    }
                                    
                                    if !isMe { Spacer() }
                                }
                                .id(msg.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: store.directMessages[friend.id]?.count) { _ in
                    if let last = store.directMessages[friend.id]?.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = store.directMessages[friend.id]?.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            if let err = sendError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            // Bottom input bar
            HStack(spacing: 10) {
                TextField("Nhập tin nhắn...", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                
                Button {
                    Task { await sendMessage() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Theme.accent)
                            .clipShape(Circle())
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle(friend.username)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    // MARK: - Helper functions
    private func startPolling() {
        // Initial fetch
        Task {
            await store.refreshDirectMessages(friendId: friend.id)
        }
        // Poll every 3 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task {
                await store.refreshDirectMessages(friendId: friend.id)
            }
        }
    }
    
    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isSending = true
        sendError = nil
        do {
            _ = try await store.api.sendDirectMessage(receiverId: friend.id, content: content)
            messageText = ""
            await store.refreshDirectMessages(friendId: friend.id)
        } catch {
            sendError = error.localizedDescription
        }
        isSending = false
    }
    
    private func formatTime(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
