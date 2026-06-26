import SwiftUI

struct AdminView: View {
    @EnvironmentObject var store: AppStore
    @State private var users: [AdminUser] = []
    @State private var error: String?
    @State private var message: String?
    @State private var pwUser: AdminUser?
    @State private var paymentId = ""
    @State private var showBank = false
    @State private var showErrors = false
    @State private var stats: AdminStats?
    @State private var adminKeys: [AdminKeyInfo] = []
    @State private var adminKeyProvider: Provider?
    @State private var pendingPayments: [PaymentRecord] = []
    @State private var maintMsg = "Ứng dụng đang nâng cấp phiên bản. Vui lòng đợi trong giây lát."

    var body: some View {
        NavigationStack {
            List {
                // ==================== 📊 Thống kê ====================
                Section {
                    if let stats {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            statCard(icon: "person.2.fill", value: "\(stats.totalUsers)", label: "Tổng người dùng", color: .blue)
                            statCard(icon: "person.badge.plus", value: "\(stats.newUsers7d)", label: "Mới 7 ngày", color: .green)
                            statCard(icon: "bubble.left.and.bubble.right.fill", value: "\(stats.totalConversations)", label: "Hội thoại", color: .orange)
                            statCard(icon: "text.bubble.fill", value: "\(stats.totalMessages)", label: "Tin nhắn", color: Theme.purple)
                            statCard(icon: "banknote.fill", value: formatRevenue(stats.revenue30d), label: "Doanh thu 30 ngày", color: .pink)
                            statCard(icon: "doc.fill", value: "\(stats.totalFiles)", label: "Tổng file", color: .teal)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    } else {
                        HStack { Spacer(); ProgressView("Đang tải thống kê..."); Spacer() }
                    }
                } header: {
                    Text("📊 Thống kê")
                }

                // ==================== Hệ thống ====================
                Section("Hệ thống") {
                    Button { showBank = true } label: {
                        Label("Thông tin ngân hàng / nạp tiền", systemImage: "banknote")
                    }
                    Button { showErrors = true } label: {
                        Label("Log lỗi hệ thống", systemImage: "exclamationmark.triangle")
                    }
                }

                // ==================== 🔑 API Keys Hệ Thống ====================
                Section {
                    ForEach(store.providers) { p in
                        Button {
                            adminKeyProvider = p
                        } label: {
                            HStack {
                                Circle().fill(providerColor(p.id)).frame(width: 10, height: 10)
                                Text(p.label.components(separatedBy: " · ").first ?? p.id)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if adminKeys.contains(where: { $0.provider == p.id && $0.configured }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text("Đã cấu hình").font(.caption2).foregroundStyle(.green)
                                } else {
                                    Text("Chưa có").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("🔑 API Keys Hệ Thống")
                } footer: {
                    Text("Key hệ thống dùng làm fallback khi người dùng chưa nhập key riêng.")
                }

                // ==================== Thanh toán chờ duyệt ====================
                Section("Thanh toán chờ duyệt") {
                    if pendingPayments.isEmpty {
                        Text("Không có thanh toán nào chờ duyệt.")
                            .foregroundStyle(.secondary).font(.footnote)
                    } else {
                        ForEach(pendingPayments) { payment in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Đơn #\(payment.id)")
                                        .font(.subheadline.bold())
                                    Text("\(payment.amount)đ → \(payment.credits) credits")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let ref = payment.ref, !ref.isEmpty {
                                        Text(ref).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    Task { await confirmPaymentById(payment.id) }
                                } label: {
                                    Text("Xác nhận")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                // ==================== Xác nhận thanh toán thủ công ====================
                Section("Xác nhận bằng ID") {
                    HStack {
                        TextField("ID đơn thanh toán", text: $paymentId)
                            .keyboardType(.numberPad)
                        Button("Xác nhận") { Task { await confirmPayment() } }
                            .disabled(paymentId.isEmpty)
                    }
                    if let message { Text(message).font(.footnote).foregroundStyle(.green) }
                }

                // ==================== Chế độ bảo trì ====================
                Section("Chế độ bảo trì") {
                    Toggle("Bật bảo trì (khoá app người dùng)", isOn: Binding(
                        get: { store.maintenance },
                        set: { on in Task { await setMaintenance(on) } }))
                    TextField("Thông báo bảo trì", text: $maintMsg, axis: .vertical)
                        .lineLimit(1...3)
                    Text("Khi bật, mọi người dùng (trừ admin) thấy màn hình khoá tới khi bạn tắt.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                // ==================== Danh sách người dùng ====================
                Section("Người dùng (\(users.count))") {
                    ForEach(users) { u in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(u.username).bold()
                                if u.isAdmin == true {
                                    Text("admin").font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Theme.accent.opacity(0.2))
                                        .foregroundStyle(Theme.accent)
                                        .clipShape(Capsule())
                                }
                                PlanBadge(plan: u.isAdmin == true ? "pro" : (u.plan ?? "free"))
                                Spacer()
                                if (u.banned ?? 0) == 1 {
                                    Text("đã khóa").font(.caption).foregroundStyle(.red)
                                } else if (u.status ?? "active") == "suspended" {
                                    Text("tạm ngưng").font(.caption).foregroundStyle(.orange)
                                }
                            }
                            if let pid = u.publicId, !pid.isEmpty {
                                Text("ID: \(pid)").font(.caption2).foregroundStyle(Theme.accent)
                            }
                            if let e = u.email, !e.isEmpty {
                                Text(e).font(.caption).foregroundStyle(.secondary)
                            }
                            if let p = u.phone, !p.isEmpty {
                                Text(p).font(.caption).foregroundStyle(.secondary)
                            }
                            if let lf = u.lastFeature, !lf.isEmpty {
                                Text("Đang dùng: \(lf)").font(.caption2).foregroundStyle(.green)
                            }
                            HStack {
                                Menu("Thao tác") {
                                    Button((u.banned ?? 0) == 1 ? "Mở khóa" : "Khóa tài khoản",
                                           role: (u.banned ?? 0) == 1 ? nil : .destructive) {
                                        Task { await ban(u, !((u.banned ?? 0) == 1)) }
                                    }
                                    Menu("Đặt gói") {
                                        Button("Free") { Task { await setPlan(u, "free") } }
                                        Button("Pro") { Task { await setPlan(u, "pro") } }
                                    }
                                    if (u.status ?? "active") == "suspended" {
                                        Button("Mở lại hoạt động") { Task { await unsuspend(u) } }
                                    } else {
                                        Menu("Tạm ngưng") {
                                            Button("15 phút") { Task { await suspend(u, 15) } }
                                            Button("1 giờ") { Task { await suspend(u, 60) } }
                                            Button("1 ngày") { Task { await suspend(u, 1440) } }
                                            Button("Vô thời hạn") { Task { await suspend(u, 0) } }
                                        }
                                    }
                                    Button("Đổi mật khẩu giúp") { pwUser = u }
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Quản trị")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThreeDLogoText(size: 20)
                }
            }
            .task {
                await reload()
                await loadStats()
                await loadAdminKeys()
                await loadPendingPayments()
            }
            .refreshable {
                await reload()
                await loadStats()
                await loadAdminKeys()
                await loadPendingPayments()
            }
            .sheet(item: $pwUser) { u in AdminPasswordSheet(user: u) { Task { await reload() } } }
            .sheet(isPresented: $showBank) { BankSettingsSheet() }
            .sheet(isPresented: $showErrors) { ErrorLogView() }
            .sheet(item: $adminKeyProvider) { p in AdminKeyEntryView(provider: p) { Task { await loadAdminKeys() } } }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    // MARK: - Stat Card

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatRevenue(_ amount: Int) -> String {
        if amount >= 1_000_000 {
            return String(format: "%.1fM", Double(amount) / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "%.0fK", Double(amount) / 1_000)
        }
        return "\(amount)"
    }

    // MARK: - Actions

    private func confirmPayment() async {
        guard let pid = Int(paymentId) else { return }
        message = nil; error = nil
        do {
            let r = try await store.api.adminConfirmPayment(pid)
            message = r.message; paymentId = ""
            await reload()
            await loadPendingPayments()
        } catch { self.error = error.localizedDescription }
    }

    private func confirmPaymentById(_ pid: Int) async {
        message = nil; error = nil
        do {
            let r = try await store.api.adminConfirmPayment(pid)
            message = r.message
            await reload()
            await loadPendingPayments()
        } catch { self.error = error.localizedDescription }
    }

    private func reload() async {
        do { users = try await store.api.adminUsers() }
        catch { self.error = error.localizedDescription }
    }

    private func loadStats() async {
        stats = try? await store.api.adminStats()
    }

    private func loadAdminKeys() async {
        adminKeys = (try? await store.api.adminListKeys()) ?? []
    }

    private func loadPendingPayments() async {
        // Filter payment history for pending items
        let allHistory = (try? await store.api.paymentHistory()) ?? []
        pendingPayments = allHistory.filter { $0.status == "pending" }
    }

    private func ban(_ u: AdminUser, _ banned: Bool) async {
        do { _ = try await store.api.adminBan(u.id, banned: banned); await reload() }
        catch { self.error = error.localizedDescription }
    }

    private func setPlan(_ u: AdminUser, _ plan: String) async {
        do { _ = try await store.api.adminSetPlan(u.id, plan: plan); await reload() }
        catch { self.error = error.localizedDescription }
    }

    private func suspend(_ u: AdminUser, _ minutes: Int) async {
        do { _ = try await store.api.adminSuspend(u.id, minutes: minutes); await reload() }
        catch { self.error = error.localizedDescription }
    }
    private func unsuspend(_ u: AdminUser) async {
        do { _ = try await store.api.adminUnsuspend(u.id); await reload() }
        catch { self.error = error.localizedDescription }
    }
    private func setMaintenance(_ on: Bool) async {
        do {
            _ = try await store.api.adminSetMaintenance(on: on, message: maintMsg)
            store.maintenance = on
        } catch { self.error = error.localizedDescription }
    }
}

// ======================== Admin Key Entry ========================
struct AdminKeyEntryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let provider: Provider
    var onDone: () -> Void
    @State private var key = ""
    @State private var message: String?
    @State private var isError = false
    @State private var checking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Circle().fill(providerColor(provider.id)).frame(width: 10, height: 10)
                        Text(provider.label).bold()
                    }
                    SecureField("Dán API key hệ thống tại đây", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Key này sẽ được dùng làm fallback cho tất cả người dùng chưa có key riêng.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if checking { ProgressView().padding(.trailing, 4) }
                            Text(checking ? "Đang lưu..." : "Lưu key hệ thống")
                        }
                    }
                    .disabled(key.isEmpty || checking)
                    Button("Xóa key", role: .destructive) {
                        Task { await remove() }
                    }
                }
                if let message {
                    Text(message).font(.footnote)
                        .foregroundStyle(isError ? .red : .green)
                }
            }
            .navigationTitle("API Key Hệ Thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { dismiss() } }
            }
        }
    }

    private func save() async {
        checking = true; message = nil
        do {
            let r = try await store.api.adminSaveKey(provider: provider.id, apiKey: key)
            isError = false; message = r.message
            onDone()
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            isError = true; message = error.localizedDescription
        }
        checking = false
    }

    private func remove() async {
        do {
            _ = try await store.api.adminDeleteKey(provider: provider.id)
            onDone(); dismiss()
        } catch { message = error.localizedDescription; isError = true }
    }
}

// ======================== Đổi mật khẩu (admin) ========================
struct AdminPasswordSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let user: AdminUser
    var onDone: () -> Void
    @State private var newPassword = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Đổi mật khẩu cho \(user.username)") {
                    SecureField("Mật khẩu mới (≥6 ký tự)", text: $newPassword)
                    Button("Xác nhận") { Task { await save() } }.disabled(newPassword.count < 6)
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle("Đổi mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { dismiss() } } }
        }
    }
    private func save() async {
        do {
            _ = try await store.api.adminSetPassword(user.id, newPassword: newPassword)
            onDone(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

// ======================== Cài đặt ngân hàng (admin) ========================
struct BankSettingsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var s = BankSettings(bankCode: "970416", bankShort: "ACB",
                                        bankAccount: "23252921", bankName: "TRAN MINH CHIEN",
                                        bankWebhook: "", bankApikey: "")
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Ngân hàng nhận tiền (hiện QR cho khách khi nạp)") {
                    TextField("Mã ngân hàng VietQR (vd ACB = 970416)", text: $s.bankCode)
                        .keyboardType(.numberPad)
                    TextField("Tên ngân hàng ngắn (vd ACB)", text: $s.bankShort)
                        .textInputAutocapitalization(.characters)
                    TextField("Số tài khoản", text: $s.bankAccount).keyboardType(.numberPad)
                    TextField("Chủ tài khoản (IN HOA, không dấu)", text: $s.bankName)
                        .textInputAutocapitalization(.characters)
                    TextField("Webhook (tuỳ chọn)", text: $s.bankWebhook)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Tự động xác nhận giao dịch (tuỳ chọn)") {
                    TextField("API key giao dịch (Casso / Sepay...)", text: $s.bankApikey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Nhập API key của dịch vụ đọc biến động số dư (vd Casso, Sepay) để tự động cộng credits khi khách chuyển khoản. Để trống thì admin xác nhận tay.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section { Button("Lưu") { Task { await save() } } }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(isError ? .red : .green)
                }
                Section {
                    Text("Mã VietQR (Napas): ACB 970416 · Vietcombank 970436 · Techcombank 970407 · MB 970422 · BIDV 970418 · VPBank 970432.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Thông tin ngân hàng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { dismiss() } } }
            .task { await load() }
        }
    }
    private func load() async {
        if let r = try? await store.api.adminGetBank() { s = r }
    }
    private func save() async {
        message = nil
        do { let r = try await store.api.adminSetBank(s); isError = false; message = r.message }
        catch { isError = true; message = error.localizedDescription }
    }
}

// ======================== Log lỗi hệ thống (admin) ========================
struct ErrorLogView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var logs: [ErrorLog] = []
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if logs.isEmpty {
                    Text("Chưa có lỗi nào được ghi.").foregroundStyle(.secondary)
                } else {
                    ForEach(logs) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.context ?? "-").font(.caption.bold())
                            Text(e.detail ?? "").font(.caption2).foregroundStyle(.red)
                            HStack {
                                if let u = e.username { Text(u).font(.caption2).foregroundStyle(.secondary) }
                                Spacer()
                                Text(timeText(e.createdAt)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Log lỗi hệ thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Xóa hết", role: .destructive) { Task { await clear() } }
                        .disabled(logs.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { dismiss() } }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func reload() async {
        do { logs = try await store.api.adminErrors() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    private func clear() async {
        do { _ = try await store.api.adminClearErrors(); await reload() }
        catch { self.error = error.localizedDescription }
    }
    private func timeText(_ ts: Int?) -> String {
        guard let ts else { return "" }
        let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"
        return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }
}
