import SwiftUI

// ======================== Models cho Proxy ========================
struct ProxyItem: Identifiable, Decodable {
    let id: Int
    let label: String
    let scheme: String
    let host: String
    let port: Int
    let username: String?
    let hasPassword: Bool
    let region: String
    let source: String
    let active: Bool
}

struct ProxyListResponse: Decodable {
    let proxies: [ProxyItem]
    let regions: [String]
}
struct ProxyAddResponse: Decodable { let id: Int; let message: String }
struct ProxyImportResponse: Decodable { let imported: Int; let message: String }
struct ProxySelectResponse: Decodable { let activeId: Int?; let message: String }
struct ProxyTestResponse: Decodable {
    let ok: Bool
    let latencyMs: Int?
    let ip: String?
    let country: String?
    let countryCode: String?
    let region: String?
    let city: String?
    let error: String?
}
struct ProxyVpsSpawnResponse: Decodable {
    let created: [Int]
    let count: Int
    let host: String
    let note: String
}

// ======================== Pane Proxy ========================
struct ProxyPane: View {
    @EnvironmentObject var store: AppStore

    @State private var proxies: [ProxyItem] = []
    @State private var regions: [String] = []
    @State private var regionFilter = ""          // "" = tất cả vùng
    @State private var loading = false
    @State private var info: String?
    @State private var error: String?

    // form thêm proxy
    @State private var showAdd = false
    @State private var fScheme = "http"
    @State private var fHost = ""
    @State private var fPort = ""
    @State private var fUser = ""
    @State private var fPass = ""
    @State private var fRegion = ""
    @State private var fLabel = ""

    // import hàng loạt
    @State private var showImport = false
    @State private var importText = ""
    @State private var importRegion = ""
    @State private var importScheme = "http"

    // kết quả test theo id
    @State private var testing: Int?
    @State private var testResults: [Int: String] = [:]

    // tạo proxy trên VPS (admin)
    @State private var spawnCount = "5"
    @State private var spawning = false

    private let schemes = ["http", "https", "socks5"]

    private var filtered: [ProxyItem] {
        regionFilter.isEmpty ? proxies : proxies.filter { $0.region == regionFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Bộ lọc theo vùng
                if !regions.isEmpty {
                    Text("Vùng địa chỉ").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            chip("Tất cả", selected: regionFilter.isEmpty) { regionFilter = "" }
                            ForEach(regions, id: \.self) { r in
                                chip(r, selected: regionFilter == r) { regionFilter = r }
                            }
                        }
                    }
                }

                HStack {
                    Button { showAdd.toggle() } label: {
                        Label("Thêm proxy", systemImage: "plus.circle").font(.caption)
                    }
                    Spacer()
                    Button { showImport.toggle() } label: {
                        Label("Import", systemImage: "square.and.arrow.down").font(.caption)
                    }
                    Spacer()
                    Button { Task { await load() } } label: {
                        Label("Tải lại", systemImage: "arrow.clockwise").font(.caption)
                    }
                }

                if showAdd { addForm }
                if showImport { importForm }

                // Tạo proxy trên VPS (chỉ admin)
                if store.isAdmin {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tạo proxy trên VPS (admin)").font(.subheadline.bold())
                        Text("Cùng 1 IP VPS, khác cổng. Nhớ mở cổng ở firewall VPS.")
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack {
                            TextField("Số lượng", text: $spawnCount)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .padding(8).background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Button {
                                Task { await spawn() }
                            } label: {
                                HStack(spacing: 6) {
                                    if spawning { ProgressView().scaleEffect(0.8) }
                                    Text("Tạo trên VPS")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(spawning || (Int(spawnCount) ?? 0) < 1)
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Tuỳ chọn "đi trực tiếp" (bỏ chọn proxy)
                rowDirect

                if loading { ProgressView().frame(maxWidth: .infinity) }

                ForEach(filtered) { p in proxyRow(p) }

                if let info { Text(info).font(.footnote).foregroundStyle(.green) }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding()
        }
        .task { await load() }
    }

    // ---- Hàng "đi trực tiếp" ----
    private var rowDirect: some View {
        let anyActive = proxies.contains { $0.active }
        return Button {
            Task { await select(nil) }
        } label: {
            HStack {
                Image(systemName: anyActive ? "circle" : "largecircle.fill.circle")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading) {
                    Text("Đi trực tiếp (không proxy)").font(.subheadline.bold())
                    Text("Dùng IP của VPS").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // ---- 1 dòng proxy ----
    private func proxyRow(_ p: ProxyItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Button { Task { await select(p.id) } } label: {
                    Image(systemName: p.active ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.label).font(.subheadline.bold())
                    Text("\(p.scheme)://\(p.host):\(String(p.port))")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        if !p.region.isEmpty { tag(p.region, "globe") }
                        tag(p.source, "tag")
                        if p.hasPassword { tag("auth", "lock") }
                    }
                }
                Spacer()
            }
            HStack {
                Button {
                    Task { await test(p.id) }
                } label: {
                    HStack(spacing: 4) {
                        if testing == p.id { ProgressView().scaleEffect(0.7) }
                        Text("Test").font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                if let res = testResults[p.id] {
                    Text(res).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    Task { await removeItem(p) }
                } label: { Image(systemName: "trash").font(.caption) }
            }
        }
        .padding(10)
        .background(p.active ? Theme.accent.opacity(0.12) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // ---- Form thêm ----
    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Scheme", selection: $fScheme) {
                ForEach(schemes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            field("Host / IP", $fHost)
            field("Port", $fPort, keyboard: .numberPad)
            field("Username (tuỳ chọn)", $fUser)
            field("Password (tuỳ chọn)", $fPass, secure: true)
            field("Vùng (vd: US, SG, VN)", $fRegion)
            field("Nhãn (tuỳ chọn)", $fLabel)
            Button("Lưu proxy") { Task { await add() } }
                .buttonStyle(.borderedProminent)
                .disabled(fHost.isEmpty || Int(fPort) == nil)
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // ---- Form import ----
    private var importForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mỗi dòng: host:port  hoặc  host:port:user:pass")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $importText)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 90)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Picker("Scheme", selection: $importScheme) {
                ForEach(schemes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            field("Vùng cho cả lô (tuỳ chọn)", $importRegion)
            Button("Import danh sách") { Task { await runImport() } }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // ---- UI helpers ----
    private func chip(_ t: String, selected: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(t).font(.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Theme.accent.opacity(0.25) : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
    private func tag(_ t: String, _ icon: String) -> some View {
        HStack(spacing: 3) { Image(systemName: icon); Text(t) }
            .font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(.secondarySystemBackground)).clipShape(Capsule())
    }
    private func field(_ ph: String, _ text: Binding<String>,
                       keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        Group {
            if secure { SecureField(ph, text: text) } else { TextField(ph, text: text) }
        }
        .keyboardType(keyboard)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // ---- Actions ----
    private func load() async {
        loading = true; error = nil
        do {
            let r = try await store.api.proxyList()
            proxies = r.proxies; regions = r.regions
        } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func add() async {
        error = nil; info = nil
        do {
            _ = try await store.api.proxyAdd(label: fLabel, scheme: fScheme, host: fHost,
                                             port: Int(fPort) ?? 0, username: fUser,
                                             password: fPass, region: fRegion, source: "manual")
            info = "Đã thêm proxy."
            fHost = ""; fPort = ""; fUser = ""; fPass = ""; fRegion = ""; fLabel = ""
            showAdd = false
            await load()
        } catch { self.error = error.localizedDescription }
    }
    private func runImport() async {
        error = nil; info = nil
        do {
            let r = try await store.api.proxyImport(text: importText, scheme: importScheme,
                                                    region: importRegion, source: "provider")
            info = r.message
            importText = ""; showImport = false
            await load()
        } catch { self.error = error.localizedDescription }
    }
    private func removeItem(_ p: ProxyItem) async {
        do {
            if p.source == "vpsproxy" {
                _ = try await store.api.proxyVpsDespawn(port: p.port)  // dừng instance trên VPS
            } else {
                _ = try await store.api.proxyDelete(id: p.id)
            }
            await load()
        } catch { self.error = error.localizedDescription }
    }
    private func spawn() async {
        spawning = true; error = nil; info = nil
        do {
            let r = try await store.api.proxyVpsSpawn(count: Int(spawnCount) ?? 1)
            info = "Đã tạo \(r.count) proxy trên VPS. \(r.note)"
            await load()
        } catch { self.error = error.localizedDescription }
        spawning = false
    }
    private func select(_ id: Int?) async {
        error = nil; info = nil
        do {
            let r = try await store.api.proxySelect(id: id)
            info = r.message
            await load()
        } catch { self.error = error.localizedDescription }
    }
    private func test(_ id: Int) async {
        testing = id; testResults[id] = nil
        do {
            let r = try await store.api.proxyTest(id: id)
            if r.ok {
                let loc = [r.city, r.country].compactMap { $0 }.joined(separator: ", ")
                testResults[id] = "✅ \(r.latencyMs ?? 0)ms · \(r.ip ?? "?") · \(loc)"
            } else {
                testResults[id] = "❌ \(r.error ?? "lỗi")"
            }
        } catch { testResults[id] = "❌ \(error.localizedDescription)" }
        testing = nil
    }
}
