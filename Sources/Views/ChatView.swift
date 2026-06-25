import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

// MARK: - Allowed file types
private let kAllowedTypes: [UTType] = [.item] // ← THAY ĐỔI: chỉ .item để mọi file đều chọn được (như iPhone)

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

    // Multi-attachment state (up to 30)
    @State private var attachments: [AttachmentItem] = []

    // Real-time Web Search toggle
    @State private var webSearchOn = false
    
    // AI Agent Mode toggle
    @State private var agentModeOn = false
    
    // Agent custom instructions
    @AppStorage("agentSystemPrompt") private var agentSystemPrompt = ""
    @State private var showAgentConfigSheet = false
    
    // Server file selection (RAG)
    @State private var selectedServerFiles: [FileItem] = []
    @State private var showLibraryPicker = false
    @State private var showImageGenSheet = false

    // PhotosPicker – multiple selection
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false

    // File importer
    @State private var showFileImporter = false

    // Voice recorder
    @StateObject private var recorder = VoiceRecorder()

    // Prompt templates sheet
    @State private var showPromptSheet = false

    // Token counter from last response
    @State private var lastTokensUsed: Int?

    // Share / Export feedback
    @State private var shareURL: String?
    @State private var showShareAlert = false
    @State private var exportText: String?
    @State private var showExportSheet = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                messagesList
                if let savedNotice { savedFileChip(savedNotice) }
                if !attachments.isEmpty || !selectedServerFiles.isEmpty { attachmentBar }
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThreeDLogoText(size: 20)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    toolbarMenu
                    Button { newChat() } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showAISheet) {
                AISelectionView(provider: $provider, model: $model,
                                ensembleOn: $ensembleOn, ensembleProviders: $ensembleProviders)
            }
            .sheet(isPresented: $showAgentConfigSheet) {
                AgentConfigSheetView(agentModeOn: $agentModeOn, agentSystemPrompt: $agentSystemPrompt)
            }
            .sheet(isPresented: $showPromptSheet) {
                PromptsListView(input: $input)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showLibraryPicker) {
                LibraryFilePickerView(selectedFiles: $selectedServerFiles)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showImageGenSheet) {
                ImageGenerationView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showExportSheet) {
                if let exportText {
                    ExportMarkdownSheet(text: exportText)
                }
            }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
            .alert("Chia sẻ hội thoại", isPresented: $showShareAlert) {
                Button("OK") { }
            } message: { Text(shareURL ?? "Đã tạo liên kết chia sẻ.") }
            .onAppear { if provider.isEmpty { setDefaultProvider() }; load() }
            .onChange(of: store.activeConversation) { _ in load() }
            .onChange(of: selectedPhotos) { newItems in loadPhotos(newItems) }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotos,
                          maxSelectionCount: 30, matching: .images)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: kAllowedTypes,
                allowsMultipleSelection: true
            ) { result in
                showFileImporter = false
                handleFileImport(result)
            }
        }
    }

    // MARK: - Toolbar Menu (Share & Export)
    private var toolbarMenu: some View {
        Menu {
            Button { newChat() } label: {
                Label("Hội thoại mới", systemImage: "square.and.pencil")
            }
            Button {
                Task { await store.refreshPrompts() }
                showPromptSheet = true
            } label: {
                Label("Prompt mẫu", systemImage: "text.badge.star")
            }
            Button { showAISheet = true } label: {
                Label("Chọn AI", systemImage: "cpu")
            }
            if conversationId != nil {
                Divider()
                Button {
                    Task { await shareConversation() }
                } label: {
                    Label("Chia sẻ hội thoại", systemImage: "square.and.arrow.up")
                }
                Button {
                    Task { await exportMarkdown() }
                } label: {
                    Label("Xuất Markdown", systemImage: "doc.text")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeConversation?.title ?? "Hội thoại mới")
                    .font(.subheadline).bold().lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(providerColor(provider)).frame(width: 8, height: 8)
                    Text(ensembleOn
                         ? "Đối xứng \(ensembleProviders.count) AI"
                         : (providerLabel(provider) + (isFree(provider) ? " · Free" : "")))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Button { showAgentConfigSheet = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body)
                        .foregroundStyle(Theme.accent)
                }
                
                Button { showAISheet = true } label: {
                    Text("Chọn AI").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
    }

    // MARK: - Messages list
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles").font(.system(size: 44))
                            .foregroundStyle(LinearGradient(
                                colors: [.blue, Theme.purple, .pink],
                                startPoint: .leading, endPoint: .trailing))
                        Text("Hôm nay bạn cần gì?")
                            .font(.title3).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.top, 90)
                }
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            MessageBubble(
                                message: m,
                                conversationId: conversationId,
                                store: store
                            ).id(m.id)

                            // Token counter below assistant bubbles
                            if m.role == "assistant", m.id == messages.last(where: { $0.role == "assistant" })?.id {
                                TokenCountView(tokens: lastTokensUsed)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    if sending {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text(ensembleOn ? "Các AI đang trả lời..." : "Đang trả lời...")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.leading, 4)
                    }
                    if !sending, messages.last?.role == "assistant" {
                        Button { Task { await regenerate() } } label: {
                            Label("Tạo lại câu trả lời", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 2)
                    }
                }.padding()
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Attachment bar (horizontal scroll preview)
    private var attachmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Server files (RAG)
                ForEach(selectedServerFiles) { file in
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack").foregroundStyle(.white)
                        Text(file.name).font(.caption).bold().lineLimit(1).foregroundStyle(.white)
                        Button {
                            selectedServerFiles.removeAll { $0.id == file.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }

                // Local attachments
                ForEach($attachments) { $item in
                    AttachmentChipView(
                        item: item,
                        onToggle: { item.selected.toggle() },
                        onRemove: { attachments.removeAll { $0.id == item.id } }
                    )
                }
            }.padding(.horizontal)
        }
        .frame(height: 100)
        .background(Color(.systemBackground))
    }

    // MARK: - Saved file chip
    private func savedFileChip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "doc.badge.checkmark").foregroundStyle(.green)
            Text(text).lineLimit(2)
            Spacer()
            Button { savedNotice = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
        }
        .font(.caption).padding(.horizontal).padding(.vertical, 6)
        .background(Color.green.opacity(0.12))
    }

    // MARK: - Input bar
    private var inputBar: some View {
        HStack(spacing: 10) {
            // Menu: file + photo + server files + image gen
            Menu {
                // Tệp / Drive
                Button {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFileImporter = true
                    }
                } label: {
                    Label("Tệp / Drive", systemImage: "folder")
                }

                // Đính kèm từ thư viện
                Button {
                    showLibraryPicker = true
                } label: {
                    Label("Đính kèm từ thư viện", systemImage: "server.rack")
                }

                // Vẽ ảnh AI
                Button {
                    showImageGenSheet = true
                } label: {
                    Label("Vẽ ảnh AI (Palette)", systemImage: "paintbrush")
                }

                // Ảnh từ thư viện (tối đa 30) — mở picker bằng state cho ổn định
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Ảnh (tối đa 30)", systemImage: "photo")
                }
            } label: {
                Image(systemName: "plus").font(.title3.bold())
                    .frame(width: 34, height: 34)
                    .kGlassInteractive(Circle())
            }

            // Prompt templates button
            Button {
                Task { await store.refreshPrompts() }
                showPromptSheet = true
            } label: {
                Text("📋")
                    .font(.title3)
                    .frame(width: 30, height: 30)
            }

            // Web Search Toggle
            Button {
                webSearchOn.toggle()
            } label: {
                Image(systemName: webSearchOn ? "globe.americas.fill" : "globe")
                    .font(.title3)
                    .foregroundStyle(webSearchOn ? Theme.accent : .secondary)
                    .frame(width: 30, height: 30)
            }

            // Agent Mode Toggle
            Button {
                agentModeOn.toggle()
            } label: {
                Image(systemName: agentModeOn ? "cpu.fill" : "cpu")
                    .font(.title3)
                    .foregroundStyle(agentModeOn ? Theme.accent : .secondary)
                    .frame(width: 30, height: 30)
            }

            // Text field
            TextField("Hỏi gì đó...", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .kGlass(RoundedRectangle(cornerRadius: 22))

            // Voice
            Button { toggleVoice() } label: {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic")
                    .font(.title3)
                    .foregroundStyle(recorder.isRecording ? .red : .secondary)
            }

            // Send
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.accent)
                    .clipShape(Circle())
            }
            .disabled(sending || (input.trimmingCharacters(in: .whitespaces).isEmpty
                                   && attachments.filter({ $0.selected }).isEmpty
                                   && selectedServerFiles.isEmpty))
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    // MARK: - Helpers
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
    private func newChat() {
        store.activeConversation = nil
        load()
    }
    private func load() {
        conversationId = store.activeConversation?.id
        messages = []
        attachments = []
        selectedPhotos = []
        lastTokensUsed = nil
        if let cid = conversationId {
            Task { @MainActor in
                if let d = try? await store.api.conversation(cid) { messages = d.messages }
            }
        }
    }

    // MARK: - Send
    @MainActor private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedAttachments = attachments.filter { $0.selected }
        guard !text.isEmpty || !selectedAttachments.isEmpty else { return }
        sending = true; error = nil

        // Build user-facing label
        let attachLabel = selectedAttachments.isEmpty ? "" : "[📎 \(selectedAttachments.count) tệp]"
        let userContent = text.isEmpty ? attachLabel : (text + (attachLabel.isEmpty ? "" : " " + attachLabel))
        messages.append(ChatMessage(role: "user", content: userContent))

        // Build API attachments
        var apiAttachments: [[String: String]]? = nil
        if !selectedAttachments.isEmpty {
            apiAttachments = selectedAttachments.map {
                ["name": $0.name, "data_base64": $0.data.base64EncodedString(), "mime": $0.mime]
            }
        }

        // Legacy single image / file for backward compat
        let singleImage: String? = nil
        let singleFileBase64: String? = nil
        let singleFileMime: String? = nil

        input = ""
        attachments = []
        selectedPhotos = []
        selectedServerFiles = []

        do {
            let defaultInstructions = """
            Bạn là một AI Agent lập trình và quản trị hệ thống siêu việt tên là KENIOS Untra.
            Bạn được trang bị các công cụ sau:
            1. Thực thi lệnh SSH trên VPS: sử dụng cú pháp ```ssh\n<command>\n```
            2. Thực thi truy vấn SQL SQLite: sử dụng cú pháp ```sql\n<query>\n```
            3. Chạy mã Python: sử dụng cú pháp ```python\n<code>\n```
            4. Gửi HTTP Request: sử dụng cú pháp ```http\nGET https://api.example.com\n```

            Khi người dùng yêu cầu thực hiện một tác vụ liên quan đến quản trị VPS, kiểm tra database, hay chạy code hoặc test API, bạn hãy viết câu lệnh/mã nguồn tương ứng trong block code thích hợp (ví dụ: ```ssh ... ```).
            Hệ thống KENIOS của người dùng sẽ tự động nhận diện block code này và cung cấp nút bấm "⚡ Thực thi" trực tiếp dưới tin nhắn để họ chạy chỉ bằng một chạm!
            Hãy hướng dẫn người dùng bấm nút thực thi hiển thị dưới tin nhắn của bạn để hoàn thành tác vụ.
            """
            let agentInstructions = agentSystemPrompt.isEmpty ? defaultInstructions : agentSystemPrompt
            let finalSystem: String?
            if agentModeOn {
                finalSystem = store.systemPrompt.isEmpty ? agentInstructions : store.systemPrompt + "\n\n" + agentInstructions
            } else {
                finalSystem = store.systemPrompt.isEmpty ? nil : store.systemPrompt
            }

            if ensembleOn {
                guard ensembleProviders.count >= 2 else {
                    throw APIError.message("Chọn ít nhất 2 AI (đã nhập key) để đối xứng.")
                }
                let r = try await store.api.ensemble(providers: Array(ensembleProviders),
                                                      message: text, judge: nil)
                messages.append(ChatMessage(role: "assistant", content: r.best, provider: "ensemble"))
                lastTokensUsed = nil
            } else {
                guard store.configuredKeys.contains(provider) else {
                    throw APIError.message("Chưa nhập API key cho \(providerLabel(provider)). Vào Cài đặt để thêm.")
                }
                let fileIds = selectedServerFiles.map { $0.id }
                let r = try await store.api.chat(
                    provider: provider, message: text,
                    image: singleImage, fileBase64: singleFileBase64,
                    fileMime: singleFileMime,
                    attachments: apiAttachments,
                    model: model, conversationId: conversationId,
                    system: finalSystem,
                    webSearch: webSearchOn,
                    fileIds: fileIds.isEmpty ? nil : fileIds
                )
                conversationId = r.conversationId
                messages.append(ChatMessage(role: "assistant", content: r.reply, provider: provider))
                lastTokensUsed = r.tokensUsed
                if let files = r.savedFiles, !files.isEmpty {
                    savedNotice = "Đã tự lưu \(files.count) file → "
                        + files.map { $0.name }.joined(separator: ", ")
                }
                await store.refreshConversations()
            }
        } catch { self.error = error.localizedDescription }
        sending = false
    }

    // MARK: - Regenerate
    @MainActor private func regenerate() async {
        guard let lastUser = messages.last(where: { $0.role == "user" }) else { return }
        if messages.last?.role == "assistant" { messages.removeLast() }
        sending = true; error = nil
        do {
            let defaultInstructions = """
            Bạn là một AI Agent lập trình và quản trị hệ thống siêu việt tên là KENIOS Untra.
            Bạn được trang bị các công cụ sau:
            1. Thực thi lệnh SSH trên VPS: sử dụng cú pháp ```ssh\n<command>\n```
            2. Thực thi truy vấn SQL SQLite: sử dụng cú pháp ```sql\n<query>\n```
            3. Chạy mã Python: sử dụng cú pháp ```python\n<code>\n```
            4. Gửi HTTP Request: sử dụng cú pháp ```http\nGET https://api.example.com\n```

            Khi người dùng yêu cầu thực hiện một tác vụ liên quan đến quản trị VPS, kiểm tra database, hay chạy code hoặc test API, bạn hãy viết câu lệnh/mã nguồn tương ứng trong block code thích hợp (ví dụ: ```ssh ... ```).
            Hệ thống KENIOS của người dùng sẽ tự động nhận diện block code này và cung cấp nút bấm "⚡ Thực thi" trực tiếp dưới tin nhắn để họ chạy chỉ bằng một chạm!
            Hãy hướng dẫn người dùng bấm nút thực thi hiển thị dưới tin nhắn của bạn để hoàn thành tác vụ.
            """
            let agentInstructions = agentSystemPrompt.isEmpty ? defaultInstructions : agentSystemPrompt
            let finalSystem: String?
            if agentModeOn {
                finalSystem = store.systemPrompt.isEmpty ? agentInstructions : store.systemPrompt + "\n\n" + agentInstructions
            } else {
                finalSystem = store.systemPrompt.isEmpty ? nil : store.systemPrompt
            }

            if ensembleOn {
                let r = try await store.api.ensemble(providers: Array(ensembleProviders),
                                                      message: lastUser.content, judge: nil)
                messages.append(ChatMessage(role: "assistant", content: r.best, provider: "ensemble"))
                lastTokensUsed = nil
            } else {
                let r = try await store.api.chat(
                    provider: provider, message: lastUser.content,
                    image: nil, model: model, conversationId: conversationId,
                    system: finalSystem
                )
                conversationId = r.conversationId
                messages.append(ChatMessage(role: "assistant", content: r.reply, provider: provider))
                lastTokensUsed = r.tokensUsed
            }
        } catch { self.error = error.localizedDescription }
        sending = false
    }

    // MARK: - Photo picker (multiple)
    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task { @MainActor in
            for item in items {
                guard attachments.count < 30 else { break }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let mime = detectImageMime(data)
                    let name = "Ảnh_\(attachments.count + 1).\(mimeExtension(mime))"
                    let attachment = AttachmentItem(
                        name: name,
                        data: data,
                        mime: mime,
                        type: "image",
                        selected: true,
                        thumbnail: data
                    )
                    attachments.append(attachment)
                }
            }
            // Reset selection so user can pick again
            selectedPhotos = []
        }
    }

    private func detectImageMime(_ data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }
        let bytes = [UInt8](data.prefix(4))
        if bytes[0] == 0x89, bytes[1] == 0x50 { return "image/png" }
        if bytes[0] == 0x47, bytes[1] == 0x49 { return "image/gif" }
        if bytes[0] == 0x52, bytes[1] == 0x49 { return "image/webp" }
        return "image/jpeg"
    }

    private func mimeExtension(_ mime: String) -> String {
        switch mime {
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        default: return "jpg"
        }
    }

    // MARK: - File importer (multiple)
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }

            for url in urls {
                guard attachments.count < 30 else { break }

                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }

                guard let data = try? Data(contentsOf: url) else { continue }
                let uti = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
                let fileName = url.lastPathComponent

                if uti?.conforms(to: .image) == true {
                    let mime = uti?.preferredMIMEType ?? "image/jpeg"
                    let attachment = AttachmentItem(
                        name: fileName,
                        data: data,
                        mime: mime,
                        type: "image",
                        selected: true,
                        thumbnail: data
                    )
                    attachments.append(attachment)
                } else if uti?.conforms(to: .pdf) == true {
                    let attachment = AttachmentItem(
                        name: fileName,
                        data: data,
                        mime: "application/pdf",
                        type: "file",
                        selected: true
                    )
                    attachments.append(attachment)
                } else if let textContent = String(data: data, encoding: .utf8) {
                    // Text / source code → add as file attachment with text data
                    let mime = uti?.preferredMIMEType ?? "text/plain"
                    let attachment = AttachmentItem(
                        name: fileName,
                        data: data,
                        mime: mime,
                        type: "file",
                        selected: true
                    )
                    attachments.append(attachment)
                } else {
                    // Binary file
                    let mime = uti?.preferredMIMEType ?? "application/octet-stream"
                    let attachment = AttachmentItem(
                        name: fileName,
                        data: data,
                        mime: mime,
                        type: "file",
                        selected: true
                    )
                    attachments.append(attachment)
                }
            }

        case .failure(let e):
            let nsErr = e as NSError
            let isCancelled = nsErr.domain == NSCocoaErrorDomain && nsErr.code == NSUserCancelledError
            if !isCancelled {
                error = e.localizedDescription
            }
        }
    }

    // MARK: - Voice
    private func toggleVoice() {
        if recorder.isRecording {
            guard let data = recorder.stop() else { return }
            Task { @MainActor in
                do {
                    let r = try await store.api.transcribe(
                        provider: "openai",
                        audioBase64: data.base64EncodedString(),
                        mime: "audio/m4a"
                    )
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

    // MARK: - Share conversation
    @MainActor private func shareConversation() async {
        guard let cid = conversationId else { return }
        do {
            let r = try await store.api.shareConversation(cid)
            shareURL = r.shareUrl
            showShareAlert = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Export Markdown
    @MainActor private func exportMarkdown() async {
        guard let cid = conversationId else { return }
        do {
            let data = try await store.api.exportConversation(cid, format: "markdown")
            if let text = String(data: data, encoding: .utf8) {
                exportText = text
                showExportSheet = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    var conversationId: Int?
    var store: AppStore?
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
                Group {
                    if isUser {
                        Text(message.content)
                    } else {
                        MarkdownText(text: message.content)
                    }
                }
                .padding(12)
                .background(isUser ? Theme.accent : Color(.secondarySystemBackground))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("Sao chép", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: message.content) {
                        Label("Lưu / Chia sẻ", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        guard let store else { return }
                        Task {
                            let _ = try? await store.api.addFavorite(
                                content: message.content,
                                conversationId: conversationId,
                                provider: message.provider
                            )
                            await store.refreshFavorites()
                        }
                    } label: {
                        Label("⭐ Yêu thích", systemImage: "star")
                    }
                }
                
                if !isUser {
                    let tools = detectedTools
                    if !tools.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("⚡ AI Agent Tools:").font(.caption.bold()).foregroundStyle(Theme.accent)
                            ForEach(0..<tools.count, id: \.self) { idx in
                                AgentToolButton(tool: tools[idx], store: store)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            if !isUser {
                TTSPlayButton(text: message.content, provider: message.provider ?? "openai", store: store)
                Spacer(minLength: 40)
            }
        }
    }
    
    private var detectedTools: [(type: String, content: String)] {
        guard !isUser else { return [] }
        var tools: [(type: String, content: String)] = []
        let content = message.content
        
        let patterns = [
            ("ssh", "```ssh\\n([\\s\\S]*?)\\n```"),
            ("sql", "```sql\\n([\\s\\S]*?)\\n```"),
            ("python", "```python\\n([\\s\\S]*?)\\n```"),
            ("http", "```http\\n([\\s\\S]*?)\\n```")
        ]
        
        for (type, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..<content.endIndex, in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                for match in matches {
                    if match.numberOfRanges > 1,
                       let r = Range(match.range(at: 1), in: content) {
                        let cmd = content[r].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cmd.isEmpty {
                            tools.append((type: type, content: cmd))
                        }
                    }
                }
            }
        }
        return tools
    }
}

struct AgentToolButton: View {
    let tool: (type: String, content: String)
    let store: AppStore?
    
    @State private var showSheet = false
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: tool.type))
                Text(buttonLabel(for: tool.type))
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.15))
            .foregroundStyle(Theme.accent)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showSheet) {
            if let store {
                AgentToolExecutionView(tool: tool, store: store)
            }
        }
    }
    
    private func iconName(for type: String) -> String {
        switch type {
        case "ssh": return "terminal"
        case "sql": return "database"
        case "python": return "play.circle"
        case "http": return "paperplane"
        default: return "gearshape"
        }
    }
    
    private func buttonLabel(for type: String) -> String {
        switch type {
        case "ssh": return "Thực thi lệnh SSH"
        case "sql": return "Chạy truy vấn SQL"
        case "python": return "Chạy mã Python"
        case "http": return "Gửi HTTP Request"
        default: return "Chạy tác vụ"
        }
    }
}

struct AgentToolExecutionView: View {
    let tool: (type: String, content: String)
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var running = false
    @State private var output = ""
    @State private var error: String? = nil
    
    // For SQL result
    @State private var sqlResult: SQLResultResponse? = nil
    
    // For SSH Connection fields if required
    @State private var sshHost = ""
    @State private var sshUser = "root"
    @State private var sshPass = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mã nguồn / Câu lệnh").font(.headline)
                    Text(tool.content)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if tool.type == "ssh" {
                        Text("Thông tin kết nối SSH").font(.subheadline.bold())
                        VStack(spacing: 8) {
                            TextField("IP / Hostname", text: $sshHost)
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            HStack {
                                TextField("User", text: $sshUser)
                                    .padding(10)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                SecureField("Pass", text: $sshPass)
                                    .padding(10)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                    
                    Button {
                        Task { await runTask() }
                    } label: {
                        HStack {
                            if running {
                                ProgressView().tint(.white).padding(.trailing, 4)
                            }
                            Text("Chạy tác vụ").bold()
                        }
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(running ? Color.gray : Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(running)
                    
                    if let err = error {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                    
                    if !output.isEmpty {
                        Text("Kết quả").font(.headline)
                        ScrollView {
                            Text(output)
                                .font(.system(.footnote, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black)
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .textSelection(.enabled)
                        }
                        .frame(height: 180)
                    }
                    
                    if let res = sqlResult {
                        VStack(alignment: .leading, spacing: 8) {
                            if let msg = res.message {
                                Text(msg).font(.caption).foregroundStyle(.green)
                            }
                            
                            if !res.columns.isEmpty {
                                Text("Bảng dữ liệu").font(.subheadline.bold())
                                ScrollView([.horizontal, .vertical]) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack(spacing: 0) {
                                            ForEach(res.columns, id: \.self) { col in
                                                Text(col)
                                                    .font(.caption.bold())
                                                    .padding(8)
                                                    .frame(width: 100, alignment: .leading)
                                                    .background(Color(.systemGray4))
                                                    .border(Color.gray.opacity(0.3), width: 0.5)
                                            }
                                        }
                                        ForEach(0..<res.rows.count, id: \.self) { rIdx in
                                            HStack(spacing: 0) {
                                                ForEach(0..<res.rows[rIdx].count, id: \.self) { cIdx in
                                                    Text(res.rows[rIdx][cIdx])
                                                        .font(.caption)
                                                        .padding(8)
                                                        .frame(width: 100, alignment: .leading)
                                                        .background(rIdx % 2 == 0 ? Color(.secondarySystemBackground) : Color(.systemBackground))
                                                        .border(Color.gray.opacity(0.2), width: 0.5)
                                                }
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .border(Color.gray.opacity(0.3), width: 1)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .onAppear {
                if let p = store.profiles.first(where: { $0.type == "VPS" }) {
                    sshHost = p.url.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
                    if let colonRange = sshHost.range(of: ":") {
                        sshHost = String(sshHost[..<colonRange.lowerBound])
                    }
                }
            }
        }
    }
    
    private var navTitle: String {
        switch tool.type {
        case "ssh": return "Thực thi Lệnh SSH"
        case "sql": return "Truy vấn CSDL"
        case "python": return "Chạy mã Python"
        case "http": return "REST Request"
        default: return "AI Agent Tool"
        }
    }
    
    private func runTask() async {
        running = true
        error = nil
        output = ""
        sqlResult = nil
        
        do {
            switch tool.type {
            case "ssh":
                let res = try await store.api.runSSH(host: sshHost, user: sshUser, pass: sshPass, cmd: tool.content)
                output = "Exit Code: \(res.exitCode)\n\nSTDOUT:\n\(res.stdout)\n\nSTDERR:\n\(res.stderr)"
            case "sql":
                let res = try await store.api.runSQL(query: tool.content)
                sqlResult = res
                output = res.message ?? "Thành công."
            case "python":
                let res = try await store.api.runCode(language: "python", code: tool.content, stdin: nil)
                output = "Return Code: \(res.returncode)\n\nSTDOUT:\n\(res.stdout)\n\nSTDERR:\n\(res.stderr)"
            case "http":
                var method = "GET"
                var url = tool.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if url.hasPrefix("GET ") || url.hasPrefix("POST ") || url.hasPrefix("PUT ") || url.hasPrefix("DELETE ") {
                    let parts = url.components(separatedBy: " ")
                    if parts.count >= 2 {
                        method = parts[0]
                        url = parts[1]
                    }
                }
                let res = try await store.api.runHTTP(url: url, method: method, headers: [:], body: "")
                output = "Status: \(res.status)\n\nHeaders:\n\(res.headers)\n\nBody:\n\(res.body)"
            default:
                break
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        running = false
    }
}

// MARK: - Prompts List View (sheet)
struct PromptsListView: View {
    @EnvironmentObject var store: AppStore
    @Binding var input: String
    @Environment(\.dismiss) private var dismiss

    @State private var prompts: [PromptTemplate] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Đang tải mẫu...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if prompts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Chưa có prompt mẫu nào")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(prompts) { prompt in
                        Button {
                            input = prompt.content
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prompt.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let cat = prompt.category, !cat.isEmpty {
                                    Text(cat)
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent)
                                }
                                Text(prompt.content)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Prompt mẫu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                do {
                    prompts = try await store.api.listPrompts()
                } catch {
                    prompts = store.promptTemplates
                }
                loading = false
            }
        }
    }
}

// MARK: - Export Markdown Sheet
struct ExportMarkdownSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("Xuất Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: text) {
                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("Sao chép", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - Library File Picker View (RAG)
struct LibraryFilePickerView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedFiles: [FileItem]
    @Environment(\.dismiss) private var dismiss
    
    @State private var files: [FileItem] = []
    @State private var selectedIds: Set<Int> = []
    @State private var loading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Đang tải tệp...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if files.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Thư viện chưa có tệp nào.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(files) { file in
                        Button {
                            if selectedIds.contains(file.id) {
                                selectedIds.remove(file.id)
                            } else {
                                selectedIds.insert(file.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedIds.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIds.contains(file.id) ? .blue : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let cat = file.category {
                                        Text(cat.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chọn tệp từ thư viện")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đồng ý") {
                        selectedFiles = files.filter { selectedIds.contains($0.id) }
                        dismiss()
                    }
                    .bold()
                }
            }
            .task {
                do {
                    files = try await store.api.listFiles(category: nil)
                    selectedIds = Set(selectedFiles.map { $0.id })
                } catch {
                    print("Error loading files for picker: \(error)")
                }
                loading = false
            }
        }
    }
}

// MARK: - Image Generation View (Palette)
struct ImageGenerationView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var prompt = ""
    @State private var provider = "openai"
    @State private var size = "1024x1024"
    @State private var drawing = false
    @State private var generatedImageB64: String?
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section("Mô tả hình ảnh (Prompt)") {
                        TextField("Mô tả chi tiết ảnh bạn muốn vẽ...", text: $prompt, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    
                    Section("Cấu hình") {
                        Picker("Nhà cung cấp", selection: $provider) {
                            ForEach(store.providers.filter { $0.id == "openai" || $0.label.lowercased().contains("openai") || $0.id.contains("dall") }) { prov in
                                Text(prov.label).tag(prov.id)
                            }
                            if store.providers.filter({ $0.id == "openai" || $0.label.lowercased().contains("openai") }).isEmpty {
                                Text("OpenAI DALL-E").tag("openai")
                            }
                        }
                    }
                    
                    if drawing {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Đang vẽ ảnh...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                    } else if let b64 = generatedImageB64, let uiImage = uiImageFromBase64(b64) {
                        Section("Ảnh kết quả") {
                            VStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit) // ← THAY ĐỔI: 'content' không phải tham số hợp lệ, đúng là 'contentMode'
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                HStack {
                                    Button {
                                        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                                    } label: {
                                        Label("Lưu vào Ảnh", systemImage: "square.and.arrow.down")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Spacer()
                                    
                                    ShareLink(item: Image(uiImage: uiImage), preview: SharePreview("Ảnh AI", image: Image(uiImage: uiImage))) {
                                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vẽ ảnh AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Vẽ") {
                        Task { await generate() }
                    }
                    .bold()
                    .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || drawing)
                }
            }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .onAppear {
                if let openaiProv = store.providers.first(where: { $0.id == "openai" })?.id {
                    provider = openaiProv
                }
            }
        }
    }
    
    private func uiImageFromBase64(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
    
    private func generate() async {
        drawing = true
        generatedImageB64 = nil
        error = nil
        do {
            let res = try await store.api.generateImage(prompt: prompt, provider: provider)
            generatedImageB64 = res.dataBase64
        } catch {
            self.error = error.localizedDescription
        }
        drawing = false
    }
}

// MARK: - TTS Play Button
struct TTSPlayButton: View {
    let text: String
    let provider: String
    let store: AppStore?
    
    @StateObject private var playerManager = AudioPlayerManager.shared
    @State private var loading = false
    
    private var isCurrentPlaying: Bool {
        playerManager.isPlaying && playerManager.currentText == text
    }
    
    var body: some View {
        Button {
            if isCurrentPlaying {
                playerManager.stop()
            } else {
                Task {
                    loading = true
                    defer { loading = false }
                    guard let api = store?.api else { return }
                    let speechProvider = provider.contains("openai") ? provider : "openai"
                    do {
                        let base64 = try await api.synthesizeSpeech(text: text, provider: speechProvider)
                        playerManager.play(base64: base64, text: text)
                    } catch {
                        print("TTS Error: \(error)")
                    }
                }
            }
        } label: {
            Group {
                if loading {
                    ProgressView()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: isCurrentPlaying ? "stop.fill" : "speaker.wave.2")
                        .font(.caption)
                }
            }
            .frame(width: 28, height: 28)
            .background(Color(.systemGray5))
            .clipShape(Circle())
        }
        .disabled(loading)
    }
}

// MARK: - Audio Player Manager (TTS Singleton)
class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying = false
    @Published var currentText: String?
    
    private var player: AVAudioPlayer?
    
    func play(base64: String, text: String) {
        stop()
        guard let data = Data(base64Encoded: base64) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.play()
            isPlaying = true
            currentText = text
        } catch {
            print("TTS Playback error: \(error)")
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentText = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentText = nil
    }
}

// MARK: - Agent Config Sheet View
struct AgentConfigSheetView: View {
    @Binding var agentModeOn: Bool
    @Binding var agentSystemPrompt: String
    @Environment(\.dismiss) var dismiss
    
    let defaultInstructions = """
    Bạn là một AI Agent lập trình và quản trị hệ thống siêu việt tên là KENIOS Untra.
    Bạn được trang bị các công cụ sau:
    1. Thực thi lệnh SSH trên VPS: sử dụng cú pháp ```ssh\n<command>\n```
    2. Thực thi truy vấn SQL SQLite: sử dụng cú pháp ```sql\n<query>\n```
    3. Chạy mã Python: sử dụng cú pháp ```python\n<code>\n```
    4. Gửi HTTP Request: sử dụng cú pháp ```http\nGET https://api.example.com\n```

    Khi người dùng yêu cầu thực hiện một tác vụ liên quan đến quản trị VPS, kiểm tra database, hay chạy code hoặc test API, bạn hãy viết câu lệnh/mã nguồn tương ứng trong block code thích hợp (ví dụ: ```ssh ... ```).
    Hệ thống KENIOS của người dùng sẽ tự động nhận diện block code này và cung cấp nút bấm "⚡ Thực thi" trực tiếp dưới tin nhắn để họ chạy chỉ bằng một chạm!
    Hãy hướng dẫn người dùng bấm nút thực thi hiển thị dưới tin nhắn của bạn để hoàn thành tác vụ.
    """
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Chế độ Trợ lý Tác vụ") {
                    Toggle("Kích hoạt Agent Mode (KENIOS Untra)", isOn: $agentModeOn)
                    Text("Khi kích hoạt, AI trợ lý sẽ được trang bị các công cụ thực thi lệnh, chạy mã, và test API.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                
                Section("Thiết lập Quy tắc Lập trình (System Logic)") {
                    TextEditor(text: Binding(
                        get: { agentSystemPrompt.isEmpty ? defaultInstructions : agentSystemPrompt },
                        set: { agentSystemPrompt = $0 }
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 220)
                    
                    Button("Khôi phục mặc định") {
                        agentSystemPrompt = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Cấu hình KENIOS Untra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }
}
