import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @State private var email = ""
    @State private var phone = ""
    @State private var newPassword = ""
    @State private var message: String?
    @State private var connected: Bool?
    @State private var showConnections = false
    @State private var showPayment = false
    @State private var cleanupDays = 30
    @State private var cleaning = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    KHeroHeader(icon: "gearshape.fill",
                                title: "Cài đặt",
                                subtitle: "Tài khoản · giao diện · dọn dẹp · cache")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // SERVER — chỉ hiện khi CHƯA cài sẵn máy chủ mặc định (Config.defaultServerURL)
                if Config.defaultServerURL.isEmpty {
                    Section("Kết nối máy chủ (\(store.serverType))") {
                        LabeledContent("URL / IP", value: store.baseURL)
                        HStack {
                            Text("Trạng thái")
                            Spacer()
                            if let connected {
                                Circle().fill(connected ? .green : .red).frame(width: 8, height: 8)
                                Text(connected ? "Đang kết nối" : "Mất kết nối")
                                    .foregroundStyle(connected ? .green : .red)
                            } else { ProgressView() }
                        }
                        Button("Quản lý máy chủ (VPS / Hosting)") { showConnections = true }
                    }
                }

                // ACCOUNT
                Section("Tài khoản") {
                    LabeledContent("Tên đăng nhập", value: store.username ?? "-")
                    HStack {
                        Text("Gói")
                        Spacer()
                        Text(store.plan == "pro" ? "PRO" : "Free")
                            .foregroundStyle(store.plan == "pro" ? .green : .secondary)
                    }
                    HStack {
                        Text("Credits")
                        Spacer()
                        Text("\(store.credits)").foregroundStyle(Theme.accent)
                    }
                    Button("Nạp credits") { showPayment = true }
                    TextField("Gmail", text: $email)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    TextField("Số điện thoại", text: $phone).keyboardType(.phonePad)
                    SecureField("Đổi mật khẩu (để trống nếu không đổi)", text: $newPassword)
                    Button("Lưu thay đổi") { Task { await saveProfile() } }
                }

                Section("Khác") {
                    Picker("Ngôn ngữ", selection: Binding(
                        get: { store.language },
                        set: { store.setLanguage($0) })) {
                        Text("Tiếng Việt").tag("vi")
                        Text("English").tag("en")
                    }
                    Toggle("Giao diện tối", isOn: Binding(
                        get: { store.isDark }, set: { store.setDark($0) }))
                }

                Section("Dung lượng & Dọn dẹp") {
                    Picker("Xóa tin nhắn cũ hơn", selection: $cleanupDays) {
                        Text("7 ngày").tag(7)
                        Text("30 ngày").tag(30)
                        Text("90 ngày").tag(90)
                    }
                    .pickerStyle(.menu)

                    Button {
                        Task { await runCleanup() }
                    } label: {
                        HStack {
                            if cleaning {
                                ProgressView().tint(.red).padding(.trailing, 4)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Dọn dẹp cơ sở dữ liệu")
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(cleaning)
                }

                Section("Bộ nhớ đệm (Cache)") {
                    Button {
                        clearCache()
                    } label: { Label("Xoá cache của app", systemImage: "trash") }
                }

                if let message { Text(message).foregroundStyle(.green).font(.footnote) }

                Section {
                    Button("Đăng xuất", role: .destructive) { store.logout() }
                }
            }
            .navigationTitle("Cài đặt")
            .sheet(isPresented: $showConnections) { ConnectionsView() }
            .sheet(isPresented: $showPayment) { PaymentView() }
            .task {
                await store.refreshCredits()
                connected = (try? await store.api.getConfig()) != nil
            }
            .onAppear { email = store.email ?? ""; phone = store.phone ?? "" }
        }
    }

    private func clearCache() {
        // Xoá URLCache + thư mục Caches + tệp tạm
        URLCache.shared.removeAllCachedResponses()
        let fm = FileManager.default
        for dir in [fm.urls(for: .cachesDirectory, in: .userDomainMask).first, fm.temporaryDirectory].compactMap({ $0 }) {
            if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for u in items { try? fm.removeItem(at: u) }
            }
        }
        message = "Đã xoá cache."
    }

    private func saveProfile() async {
        do {
            _ = try await store.api.updateProfile(email: email, phone: phone,
                                                   newPassword: newPassword.isEmpty ? nil : newPassword)
            store.updateLocalUser(email: email, phone: phone)
            newPassword = ""; message = "Đã cập nhật."
        } catch { message = error.localizedDescription }
    }

    private func runCleanup() async {
        cleaning = true
        message = nil
        do {
            let res = try await store.api.cleanupDatabase(days: cleanupDays)
            message = res.message
        } catch {
            message = "Lỗi: \(error.localizedDescription)"
        }
        cleaning = false
    }
}
