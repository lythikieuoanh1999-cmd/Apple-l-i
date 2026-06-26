import SwiftUI

// ======================== Phân phối — Đăng ký thiết bị (UDID) ========================
struct DevicesView: View {
    @EnvironmentObject var store: AppStore
    @State private var devices: [DeviceItem] = []
    @State private var loading = false
    @State private var error: String?

    private var enrollURL: String {
        let base = store.baseURL.isEmpty ? "http://IP-VPS" : store.baseURL
        return base.hasSuffix("/") ? base + "enroll/start" : base + "/enroll/start"
    }

    var body: some View {
        List {
            Section("Trang lấy UDID") {
                Text("Gửi link này cho người dùng. Mở bằng Safari trên iPhone → bấm \"Lấy UDID\" → cài hồ sơ → UDID tự gửi về máy chủ.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(enrollURL).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                HStack {
                    Button { UIPasteboard.general.string = enrollURL } label: { Label("Copy link", systemImage: "doc.on.doc").font(.caption) }
                    ShareLink(item: enrollURL) { Label("Chia sẻ", systemImage: "square.and.arrow.up").font(.caption) }
                }
            }

            if store.isAdmin {
                Section("Thiết bị đã đăng ký (\(devices.count))") {
                    if devices.isEmpty && !loading {
                        Text("Chưa có thiết bị nào.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(devices) { d in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(d.name?.isEmpty == false ? d.name! : (d.product ?? "iPhone")).font(.subheadline.bold())
                            Text(d.udid).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                            Text("\(d.product ?? "") · iOS \(d.version ?? "")").font(.caption2).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button { UIPasteboard.general.string = d.udid } label: { Label("Copy UDID", systemImage: "doc.on.doc") }.tint(.blue)
                        }
                    }
                    if !devices.isEmpty {
                        Button {
                            UIPasteboard.general.string = devices.map { $0.udid }.joined(separator: "\n")
                        } label: { Label("Copy tất cả UDID", systemImage: "doc.on.doc.fill").font(.caption) }
                    }
                }
            } else {
                Section {
                    Text("Danh sách thiết bị chỉ admin xem được.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Lưu ý") {
                Text("Để giới hạn theo UDID + bắt 'Tin cậy', cần ký app bằng tài khoản Apple Developer (ad-hoc). Xem hướng dẫn UDID-DISTRIBUTION.md.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if let error { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .navigationTitle("Thiết bị (UDID)")
        .task { if store.isAdmin { await reload() } }
    }

    private func reload() async {
        loading = true; error = nil
        do { devices = try await store.api.listDevices().devices }
        catch { self.error = error.localizedDescription }
        loading = false
    }
}
