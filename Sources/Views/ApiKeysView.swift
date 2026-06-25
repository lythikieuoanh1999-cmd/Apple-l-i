import SwiftUI

// ======================== KENIOS AI — Cấp API key cho người khác dùng ké ========================
struct ApiKeysView: View {
    @EnvironmentObject var store: AppStore
    @State private var tokens: [ApiTokenItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var newName = ""
    @State private var lastCreated: String?

    var body: some View {
        List {
            Section {
                Text("KENIOS AI là model chạy trên máy chủ của bạn — không dùng API key của ai. Tạo khoá API ở đây để người khác gọi AI của bạn.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let lastCreated {
                Section("Khoá vừa tạo") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lastCreated).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        Button { UIPasteboard.general.string = lastCreated } label: {
                            Label("Copy khoá", systemImage: "doc.on.doc").font(.caption)
                        }
                        Text("Lưu lại ngay — khoá chỉ hiện đầy đủ ở đây.").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }

            Section("Khoá API của bạn") {
                if tokens.isEmpty && !loading {
                    Text("Chưa có khoá. Bấm + để tạo.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(tokens) { t in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.name ?? "Khoá API").font(.subheadline.bold())
                        Text(t.token).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                        Text("Đã gọi: \(t.calls ?? 0) lần").font(.caption2).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) { Task { await remove(t) } } label: { Label("Xoá", systemImage: "trash") }
                        Button { UIPasteboard.general.string = t.token } label: { Label("Copy", systemImage: "doc.on.doc") }.tint(.blue)
                    }
                }
            }

            Section("Cách người khác dùng") {
                Text(usageExample).font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                Button { UIPasteboard.general.string = usageExample } label: {
                    Label("Copy ví dụ", systemImage: "doc.on.doc").font(.caption)
                }
            }

            if let error { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .navigationTitle("API key KENIOS AI")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .task { await reload() }
        .alert("Tạo khoá API", isPresented: $showCreate) {
            TextField("Tên (vd: App của bạn A)", text: $newName)
            Button("Tạo") { Task { await create() } }
            Button("Huỷ", role: .cancel) { }
        }
    }

    private var usageExample: String {
        let base = store.baseURL.isEmpty ? "http://IP-VPS" : store.baseURL
        return """
        curl -X POST \(base)/v1/kenios/chat \\
          -H "Content-Type: application/json" \\
          -d '{"token":"<API_KEY>","message":"Xin chào"}'
        """
    }

    private func reload() async {
        loading = true; error = nil
        do { tokens = try await store.api.apiTokenList().tokens }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    private func create() async {
        do {
            let r = try await store.api.apiTokenCreate(name: newName)
            lastCreated = r.token; newName = ""
            await reload()
        } catch { self.error = error.localizedDescription }
    }
    private func remove(_ t: ApiTokenItem) async {
        do { try await store.api.apiTokenDelete(token: t.token); await reload() }
        catch { self.error = error.localizedDescription }
    }
}
