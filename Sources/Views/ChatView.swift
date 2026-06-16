import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ChatView: View {
    @EnvironmentObject var store: AppStore

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var conversationId: Int?
    @State private var sending = false
    @State private var error: String?
    @State private var savedNotice: String?

    @State private var provider = ""
    @State private var model: String?
    @State private var ensembleOn = false
    @State private var ensembleProviders: Set<String> = []
    @State private var showAISheet = false

    @State private var photoItem: PhotosPickerItem?
    @State private var imageBase64: String?
    @State private var fileBase64: String?
    @State private var fileMime: String?
    @State private var attachmentName: String?
    @State private var showFileImporter = false

    @StateObject private var recorder = VoiceRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                messagesList
                if let attachmentName { attachmentChip(attachmentName) }
                if let savedNotice { savedFileChip(savedNotice) }
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Text("KENIOS").font(.headline) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newChat() } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showAISheet) {
                AISelectionView(provider: $provider, model: $model,
                                ensembleOn: $ensembleOn, ensembleProviders: $ensembleProviders)
            }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
            .onAppear { if provider.isEmpty { setDefaultProvider() }; load() }
            .onChange(of: store.activeConversation) { _ in load() }
            .onChange(of: photoItem) { item in loadPhoto(item) }
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.image, .plainText, .pdf, .sourceCode, .item],
                          allowsMultipleSelection: false) { handleFileImport($0) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeConversation?.title ?? "Hội thoại mới")
                    .font(.subheadline).bold().lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(providerColor(provider)).frame(width: 8, height: 8)
                    Text(ensembleOn ? "Đối xứng \(ensembleProviders.count) AI"
                         : (providerLabel(provider) + (isFree(provider) ? " · Free" : "")))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { showAISheet = true } label: {
                Text("Chọn AI").font(.subheadline).foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles").font(.system(size: 44))
                            .foregroundStyle(LinearGradient(colors: [.blue, Theme.purple, .pink],
                                          startPoint: .leading, endPoint: .trailing))
                        Text("Hôm nay bạn cần gì?").font(.title3).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.top, 90)
                }
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { m in MessageBubble(message: m).id(m.id) }
                    if sending {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text(ensembleOn ? "Các AI đang trả lời..." : "Đang trả lời...")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.leading, 4)
                    }
                    if !sending, messages.last?.role == "assistant" {
                        Button { Task { await regenerate() } } label: {
                            Label("Tạo lại câu trả lời", systemImage: "arrow.clockwise").font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 2)
                    }
                }.padding()
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func attachmentChip(_ name: String) -> some View {
        HStack {
            Image(systemName: "paperclip"); Text(name).lineLimit(1)
            Spacer()
            Button { clearAttachment() } label: { Image(systemName: "xmark.circle.fill") }
        }
        .font(.footnote).padding(.horizontal).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private func savedFileChip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "doc.badge.checkmark").foregroundStyle(.green)
            Text(text).lineLimit(2)
            Spacer()
            Button { savedNotice = nil } label: { Image(systemName: "xmark.circle.fill") }
        }
        .font(.caption).padding(.horizontal).padding(.vertical, 6)
        .background(Color.green.opacity(0.12))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button { showFileImporter = true } label: { Label("Tệp / Drive", systemImage: "folder") }
                PhotosPicker(selection: $photoItem, matching: .images) { Label("Ảnh", systemImage: "photo") }
            } label: {
                Image(systemName: "plus").font(.title3.bold())
                    .frame(width: 34, height: 34)
                    .kGlassInteractive(Circle())
            }

            TextField("Hỏi gì đó...", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .kGlass(RoundedRectangle(cornerRadius: 22))

            Button { toggleVoice() } label: {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic")
                    .font(.title3).foregroundStyle(recorder.isRecording ? .red : .secondary)
            }

            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up").font(.headline.bold()).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Theme.accent).clipShape(Circle())
            }
            .disabled(sending || (input.trimmingCharacters(in: .whitespaces).isEmpty
                                   && imageBase64 == nil && fileBase64 == nil))
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private func providerLabel(_ id: String) -> String {
        store.providers.first(where: { $0.id == id })?.label ?? (id.isEmpty ? "Chọn AI" : id)
    }
    private func isFree(_ id: String) -> Bool {
        store.providers.first(where: { $0.id == id })?.free ?? false
    }
    private func setDefaultProvider() {
        provider = store.configuredKeys.first
            ?? store.providers.first(where: { $0.free })?.id
            ?? store.providers.first?.id ?? "gemini"
    }
    private func newChat() { store.activeConversation = nil; load() }
    private func load() {
        conversationId = store.activeConversation?.id
        messages = []
        if let cid = conversationId {
            Task { @MainActor in
                if let d = try? await store.api.conversation(cid) { messages = d.messages }
            }
        }
    }

    @MainActor private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || imageBase64 != nil || fileBase64 != nil else { return }
        sending = true; error = nil
        let attachLabel = imageBase64 != nil ? "[ảnh]" : (fileBase64 != nil ? "[file]" : "")
        messages.append(ChatMessage(role: "user", content: text.isEmpty ? attachLabel : text))
        let img = imageBase64
        let fb64 = fileBase64
        let fmime = fileMime
        input = ""; clearAttachment()
        do {
            if ensembleOn {
                guard ensembleProviders.count >= 2 else {
                    throw APIError.message("Chọn ít nhất 2 AI (đã nhập key) để đối xứng.")
                }
                let r = try await store.api.ensemble(providers: Array(ensembleProviders),
                                                     message: text, judge: nil)
                messages.append(ChatMessage(role: "assistant", content: r.best, provider: "ensemble"))
            } else {
                guard store.configuredKeys.contains(provider) else {
                    throw APIError.message("Chưa nhập API key cho \(providerLabel(provider)). Vào Cài đặt để thêm.")
                }
                let r = try await store.api.chat(provider: provider, message: text,
                                                 image: img, fileBase64: fb64, fileMime: fmime,
                                                 model: model, conversationId: conversationId,
                                                 system: store.systemPrompt.isEmpty ? nil : store.systemPrompt)
                conversationId = r.conversationId
                messages.append(ChatMessage(role: "assistant", content: r.reply, provider: provider))
                if let files = r.savedFiles, !files.isEmpty {
                    savedNotice = "Đã tự lưu \(files.count) file vào Thư viện → File: "
                        + files.map { $0.name }.joined(separator: ", ")
                }
                await store.refreshConversations()
            }
        } catch { self.error = error.localizedDescription }
        sending = false
    }

    @MainActor private func regenerate() async {
        guard let lastUser = messages.last(where: { $0.role == "user" }) else { return }
        if messages.last?.role == "assistant" { messages.removeLast() }
        sending = true; error = nil
        do {
            if ensembleOn {
                let r = try await store.api.ensemble(providers: Array(ensembleProviders),
                                                     message: lastUser.content, judge: nil)
                messages.append(ChatMessage(role: "assistant", content: r.best, provider: "ensemble"))
            } else {
                let r = try await store.api.chat(provider: provider, message: lastUser.content,
                                                 image: nil, model: model, conversationId: conversationId,
                                                 system: store.systemPrompt.isEmpty ? nil : store.systemPrompt)
                conversationId = r.conversationId
                messages.append(ChatMessage(role: "assistant", content: r.reply, provider: provider))
            }
        } catch { self.error = error.localizedDescription }
        sending = false
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            if let data = try? await item.loadTransferable(type: Data.self) {
                imageBase64 = data.base64EncodedString(); attachmentName = "Ảnh đã chọn"
            }
        }
    }
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
            if type?.conforms(to: .image) == true {
                imageBase64 = data.base64EncodedString(); attachmentName = url.lastPathComponent
            } else if type?.conforms(to: .pdf) == true {
                fileBase64 = data.base64EncodedString(); fileMime = "application/pdf"
                attachmentName = url.lastPathComponent
            } else if type?.conforms(to: .plainText) == true || type?.conforms(to: .sourceCode) == true,
                      let txt = String(data: data, encoding: .utf8) {
                input += "\n\n[Tệp \(url.lastPathComponent)]:\n" + txt
            } else {
                // Gửi dạng file_base64 chung (server sẽ tự đọc nếu là văn bản/code)
                fileBase64 = data.base64EncodedString()
                fileMime = type?.preferredMIMEType ?? "application/octet-stream"
                attachmentName = url.lastPathComponent
            }
        case .failure(let e): error = e.localizedDescription
        }
    }
    private func clearAttachment() {
        imageBase64 = nil; fileBase64 = nil; fileMime = nil
        attachmentName = nil; photoItem = nil
    }

    private func toggleVoice() {
        if recorder.isRecording {
            guard let data = recorder.stop() else { return }
            Task { @MainActor in
                do {
                    let r = try await store.api.transcribe(provider: "openai",
                                                           audioBase64: data.base64EncodedString(),
                                                           mime: "audio/m4a")
                    input += (input.isEmpty ? "" : " ") + r.text
                } catch { self.error = error.localizedDescription }
            }
        } else {
            recorder.requestPermission { granted in
                guard granted else { error = "Cần quyền micro."; return }
                do { try recorder.start() } catch { self.error = error.localizedDescription }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if !isUser, let p = message.provider {
                    HStack(spacing: 5) {
                        Circle().fill(providerColor(p)).frame(width: 7, height: 7)
                        Text(p == "ensemble" ? "Đối xứng" : p.capitalized)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Theme.accent : Color(.secondarySystemBackground))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .textSelection(.enabled)
                    .contextMenu {
                        Button { UIPasteboard.general.string = message.content } label: {
                            Label("Sao chép", systemImage: "doc.on.doc")
                        }
                        ShareLink(item: message.content) {
                            Label("Lưu / Chia sẻ", systemImage: "square.and.arrow.up")
                        }
                    }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
