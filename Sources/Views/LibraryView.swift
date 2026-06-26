import SwiftUI
import UniformTypeIdentifiers
import QuickLook

struct LibraryView: View {
    @State private var seg = 1
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                KHeroHeader(icon: "clock.arrow.circlepath",
                            title: "Thư viện",
                            subtitle: "Video đã tải · File · Lịch sử nội dung")
                    .padding(.horizontal)
                    .padding(.top, 8)

                Picker("", selection: $seg) {
                    Text("File").tag(1)
                    Text("Lịch sử").tag(0)
                }
                .pickerStyle(.segmented).padding()
                if seg == 0 { HistoryPane() } else { FilesPane() }
            }
            .navigationTitle("Thư viện")
        }
    }
}

struct HistoryPane: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""

    private var filtered: [Conversation] {
        guard !search.isEmpty else { return store.conversations }
        return store.conversations.filter { ($0.title ?? "").localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Tìm kiếm...", text: $search)
            }
            Button {
                store.openConversation(nil)
            } label: {
                Label("Hội thoại mới", systemImage: "plus").foregroundStyle(Theme.accent)
            }
            ForEach(filtered) { c in
                Button { store.openConversation(c) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.title ?? "Hội thoại").foregroundStyle(.primary).lineLimit(1)
                        if let p = c.provider {
                            HStack(spacing: 5) {
                                Circle().fill(providerColor(p)).frame(width: 7, height: 7)
                                Text(p.capitalized).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .task { await store.refreshConversations() }
        .refreshable { await store.refreshConversations() }
        .overlay {
            if store.conversations.isEmpty {
                Text("Bạn chưa lưu cuộc trò chuyện nào").foregroundStyle(.secondary)
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { filtered[$0].id }
        Task {
            for id in ids { _ = try? await store.api.deleteConversation(id) }
            await store.refreshConversations()
        }
    }
}

struct FilesPane: View {
    @EnvironmentObject var store: AppStore
    @State private var category = "all"
    @State private var files: [FileItem] = []
    @State private var showImporter = false
    @State private var error: String?
    @State private var exportDoc: ExportableFile?
    @State private var runResult: FileRunResult?
    @State private var running: Int?
    @State private var previewURL: URL?

    private let cats = [("all", "Tất cả"), ("image", "Ảnh"), ("code", "Code"), ("document", "Tài liệu")]
    private let runnable: Set<String> = ["py", "js", "sh"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(cats, id: \.0) { c in
                        Button { category = c.0; Task { await reload() } } label: {
                            Text(c.1).font(.caption)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(category == c.0 ? Theme.accent : Color(.secondarySystemBackground))
                                .foregroundStyle(category == c.0 ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }.padding(.horizontal)
            }
            List {
                ForEach(files) { f in
                    HStack {
                        Button {
                            Task { await previewFile(f) }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Theme.accent.opacity(0.18))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: categoryIcon(f.category))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.name).lineLimit(1).foregroundStyle(.primary)
                                    Text(humanSize(f.size)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        if isRunnable(f.name) {
                            Button {
                                Task { await run(f) }
                            } label: {
                                if running == f.id { ProgressView() }
                                else { Image(systemName: "play.circle") }
                            }
                            .disabled(running != nil)
                            .buttonStyle(.plain)
                        }
                        Button { Task { await download(f) } } label: {
                            Image(systemName: "arrow.down.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete(perform: deleteFiles)

                Button { showImporter = true } label: {
                    VStack {
                        Label("Tải file lên từ máy", systemImage: "plus")
                        Text("Ảnh · PDF · Code · Tài liệu").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                }
            }
        }
        .task { await reload() }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item], allowsMultipleSelection: true) { handleImport($0) }
        .fileExporter(isPresented: Binding(get: { exportDoc != nil }, set: { if !$0 { exportDoc = nil } }),
                      document: exportDoc, contentType: .data,
                      defaultFilename: exportDoc?.filename ?? "file") { _ in exportDoc = nil }
        .quickLookPreview($previewURL)
        .alert("Lỗi", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .sheet(item: $runResult) { r in RunResultView(result: r) }
    }

    private func isRunnable(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return runnable.contains(ext)
    }

    private func run(_ f: FileItem) async {
        running = f.id; error = nil
        do {
            runResult = try await store.api.runTestFile(fileId: f.id)
        } catch { self.error = error.localizedDescription }
        running = nil
    }

    private func reload() async {
        if let list = try? await store.api.listFiles(category: category) { files = list }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        Task {
            var failed: [String] = []
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                let ext = url.pathExtension.lowercased()
                let cat: String
                if ["png", "jpg", "jpeg", "gif", "heic", "webp"].contains(ext) { cat = "image" }
                else if ["swift", "py", "js", "ts", "java", "c", "cpp", "go", "rs", "rb", "json", "html", "css"].contains(ext) { cat = "code" }
                else if ["pdf", "doc", "docx", "txt", "md", "xls", "xlsx", "ppt", "pptx"].contains(ext) { cat = "document" }
                else { cat = "other" }
                do {
                    _ = try await store.api.uploadFileRaw(name: url.lastPathComponent, category: cat, fileURL: url)
                } catch {
                    failed.append(url.lastPathComponent)
                }
                if access { url.stopAccessingSecurityScopedResource() }
            }
            await reload()
            if !failed.isEmpty { self.error = "Lỗi tải lên: \(failed.joined(separator: ", "))" }
        }
    }

    private func download(_ f: FileItem) async {
        do {
            let (tempURL, filename) = try await store.api.downloadFileRaw(f.id)
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let destinationURL = cacheDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: tempURL, to: destinationURL)
            exportDoc = ExportableFile(fileURL: destinationURL, filename: filename)
        } catch { self.error = error.localizedDescription }
    }

    private func previewFile(_ f: FileItem) async {
        do {
            let (tempURL, filename) = try await store.api.downloadFileRaw(f.id)
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let destinationURL = cacheDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: tempURL, to: destinationURL)
            self.previewURL = destinationURL
        } catch { self.error = error.localizedDescription }
    }

    private func deleteFiles(_ offsets: IndexSet) {
        let ids = offsets.map { files[$0].id }
        Task {
            for id in ids { _ = try? await store.api.deleteFile(id) }
            await reload()
        }
    }
}

struct RunResultView: View {
    @Environment(\.dismiss) var dismiss
    let result: FileRunResult

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(result.file).font(.subheadline.bold())
                        Spacer()
                        Text("returncode: \(result.returncode)")
                            .font(.caption).foregroundStyle(result.returncode == 0 ? .green : .red)
                    }
                    if !result.stdout.isEmpty {
                        Text("stdout").font(.caption).foregroundStyle(.secondary)
                        Text(result.stdout)
                            .font(.system(.footnote, design: .monospaced))
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }
                    if !result.stderr.isEmpty {
                        Text("stderr").font(.caption).foregroundStyle(.secondary)
                        Text(result.stderr)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }
                    if result.stdout.isEmpty && result.stderr.isEmpty {
                        Text("Không có đầu ra.").foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Kết quả chạy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { dismiss() } } }
        }
    }
}

struct ExportableFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var fileURL: URL
    var filename: String
    init(fileURL: URL, filename: String) { self.fileURL = fileURL; self.filename = filename }
    init(configuration: ReadConfiguration) throws {
        fileURL = URL(fileURLWithPath: ""); filename = ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: fileURL, options: .immediate)
    }
}
