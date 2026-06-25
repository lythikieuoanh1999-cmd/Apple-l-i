import SwiftUI

// ======================== KenMail — Email tích hợp (tài khoản + mật khẩu) ========================
// Chạy chung trong backend KENIOS: tạo hộp thư @kenios.store có mật khẩu, nhận thư thật
// (qua MX + bộ nhận SMTP), gửi nội bộ và gửi ra ngoài (qua relay nếu cấu hình).
struct KenMailView: View {
    @EnvironmentObject var store: AppStore

    @State private var mailboxes: [Mailbox] = []
    @State private var domain = "kenios.store"
    @State private var selected: Mailbox?
    @State private var mails: [MailItem] = []
    @State private var loading = false
    @State private var error: String?

    // Tạo hộp thư
    @State private var showCreate = false
    @State private var createLocal = ""
    @State private var createPass = ""

    // Soạn thư
    @State private var showCompose = false
    @State private var toAddr = ""
    @State private var subject = ""
    @State private var bodyText = ""
    @State private var sending = false

    @State private var openMail: MailItem?

    // Tạo hàng loạt ngẫu nhiên
    @State private var showBulk = false
    @State private var bulkCount = "10"
    @State private var bulkPrefix = ""
    @State private var bulking = false
    @State private var bulkResults: [MailCredential] = []
    @State private var showBulkResults = false

    var body: some View {
        NavigationStack {
            Group {
                if mailboxes.isEmpty {
                    emptyState
                } else {
                    inboxView
                }
            }
            .navigationTitle("KenMail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { showCreate = true } label: { Label("Tạo 1 hộp thư", systemImage: "plus") }
                        Button { showBulk = true } label: { Label("Tạo nhiều ngẫu nhiên", systemImage: "rectangle.stack.badge.plus") }
                    } label: { Image(systemName: "plus") }
                    Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await loadBoxes() }
            .alert("Tạo hộp thư mới", isPresented: $showCreate) {
                TextField("tên (vd: cong)", text: $createLocal)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("mật khẩu (≥6 ký tự)", text: $createPass)
                Button("Tạo") { Task { await createBox() } }
                Button("Huỷ", role: .cancel) { }
            } message: {
                Text("Địa chỉ sẽ là tên@\(domain), có mật khẩu để đăng nhập webmail.")
            }
            .alert("Tạo nhiều hộp thư ngẫu nhiên", isPresented: $showBulk) {
                TextField("Số lượng (1–50)", text: $bulkCount).keyboardType(.numberPad)
                TextField("Tiền tố (tuỳ chọn, vd: shop)", text: $bulkPrefix)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Tạo") { Task { await bulkCreate() } }
                Button("Huỷ", role: .cancel) { }
            } message: {
                Text("Tạo nhanh nhiều email @\(domain) ngẫu nhiên (không cần SĐT). Kèm mật khẩu để đăng nhập.")
            }
            .sheet(isPresented: $showCompose) { composeSheet }
            .sheet(isPresented: $showBulkResults) { bulkResultSheet }
            .sheet(item: $openMail) { m in mailDetail(m) }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    // MARK: - Kết quả tạo hàng loạt
    private var bulkResultSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        UIPasteboard.general.string = bulkResults
                            .map { "\($0.address) | \($0.password)" }.joined(separator: "\n")
                    } label: { Label("Copy tất cả (địa chỉ | mật khẩu)", systemImage: "doc.on.doc") }
                }
                ForEach(bulkResults) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.address).font(.subheadline.bold())
                        Text("Mật khẩu: \(c.password)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button { UIPasteboard.general.string = "\(c.address) | \(c.password)" } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }.tint(.blue)
                    }
                }
            }
            .navigationTitle("Đã tạo \(bulkResults.count) email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Xong") { showBulkResults = false } } }
        }
    }

    // MARK: - Trạng thái rỗng (chưa có hộp thư)
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 54)).foregroundStyle(Theme.accent)
            Text("Tạo email @\(domain) của bạn")
                .font(.title3.bold())
            Text("Hộp thư có tài khoản + mật khẩu, nhận thư thật, gửi nội bộ và ra ngoài.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
            Button { showCreate = true } label: {
                Label("Tạo hộp thư", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.accent).foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            if loading { ProgressView() }
        }
        .padding()
    }

    // MARK: - Hộp thư đến
    private var inboxView: some View {
        VStack(spacing: 0) {
            // Chọn hộp thư
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(mailboxes) { b in
                        Button { selected = b; Task { await reload() } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.fill").font(.caption2)
                                Text(b.address).font(.caption)
                                if let u = b.unseen, u > 0 {
                                    Text("\(u)").font(.caption2.bold())
                                        .padding(.horizontal, 5).background(Color.red)
                                        .foregroundStyle(.white).clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selected?.id == b.id ? Theme.accent.opacity(0.25) : Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                }.padding()
            }

            if let sel = selected {
                HStack {
                    Text(sel.address).font(.caption.bold())
                    Button { UIPasteboard.general.string = sel.address } label: {
                        Image(systemName: "doc.on.doc").font(.caption2)
                    }
                    Spacer()
                    Button { toAddr = ""; subject = ""; bodyText = ""; showCompose = true } label: {
                        Label("Soạn", systemImage: "square.and.pencil").font(.caption)
                    }.buttonStyle(.bordered)
                }.padding(.horizontal)
            }

            if loading { ProgressView().padding() }

            if mails.isEmpty && !loading {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Hộp thư trống — đang chờ email đến.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mails) { m in
                        Button { openMail = m; Task { await markSeen(m) } } label: { mailRow(m) }
                            .swipeActions {
                                Button(role: .destructive) { Task { await deleteMail(m) } } label: {
                                    Label("Xoá", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .refreshable { await reload() }
            }
        }
    }

    private func mailRow(_ m: MailItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: m.direction == "out" ? "paperplane.fill" : (m.seen == 0 ? "envelope.badge.fill" : "envelope.open"))
                .foregroundStyle(m.direction == "out" ? .blue : (m.seen == 0 ? Theme.accent : .secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(m.direction == "out" ? "Tới: \(m.toAddr ?? "")" : (m.fromAddr ?? "?"))
                    .font(.subheadline).fontWeight(m.seen == 0 ? .bold : .regular).lineLimit(1)
                Text(m.subject?.isEmpty == false ? m.subject! : "(không tiêu đề)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(timeStr(m.createdAt)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Chi tiết thư
    private func mailDetail(_ m: MailItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(m.subject?.isEmpty == false ? m.subject! : "(không tiêu đề)").font(.headline)
                    Text("Từ: \(m.fromAddr ?? "?")").font(.caption).foregroundStyle(.secondary)
                    Text("Tới: \(m.toAddr ?? "?")").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text(m.body ?? "").font(.body).textSelection(.enabled)
                }.padding()
            }
            .navigationTitle("Thư").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { openMail = nil } } }
        }
    }

    // MARK: - Soạn thư
    private var composeSheet: some View {
        NavigationStack {
            Form {
                Section("Từ") { Text(selected?.address ?? "").foregroundStyle(.secondary) }
                Section("Gửi tới") {
                    TextField("nguoinhan@gmail.com hoặc @\(domain)", text: $toAddr)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Tiêu đề") { TextField("Tiêu đề", text: $subject) }
                Section("Nội dung") {
                    TextEditor(text: $bodyText).frame(minHeight: 160)
                }
            }
            .navigationTitle("Soạn thư").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { showCompose = false } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await sendMail() } } label: {
                        if sending { ProgressView() } else { Text("Gửi").bold() }
                    }.disabled(sending || toAddr.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions
    private func loadBoxes() async {
        loading = true; error = nil
        do {
            let r = try await store.api.mailList()
            mailboxes = r.mailboxes; domain = r.domain
            if selected == nil { selected = mailboxes.first }
            if selected != nil { await reload() }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func reload() async {
        guard let sel = selected else { return }
        loading = true
        do { mails = try await store.api.mailInbox(mailboxId: sel.id).mails }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    private func createBox() async {
        let local = createLocal.trimmingCharacters(in: .whitespaces).lowercased()
        guard !local.isEmpty, createPass.count >= 6 else {
            error = "Tên hộp thư không trống, mật khẩu ≥ 6 ký tự."; return
        }
        do {
            let r = try await store.api.mailCreate(local: local, password: createPass)
            createLocal = ""; createPass = ""
            await loadBoxes()
            selected = mailboxes.first { $0.id == r.id } ?? mailboxes.first
            await reload()
        } catch { self.error = error.localizedDescription }
    }
    private func bulkCreate() async {
        let n = max(1, min(Int(bulkCount) ?? 10, 50))
        bulking = true; error = nil
        do {
            let r = try await store.api.mailBulkCreate(count: n, prefix: bulkPrefix)
            bulkResults = r.created
            bulkPrefix = ""
            await loadBoxes()
            if !bulkResults.isEmpty { showBulkResults = true }
            else { error = "Không tạo được hộp thư nào." }
        } catch { self.error = error.localizedDescription }
        bulking = false
    }
    private func sendMail() async {
        guard let sel = selected else { return }
        sending = true
        do {
            try await store.api.mailSend(mailboxId: sel.id, to: toAddr, subject: subject, body: bodyText)
            showCompose = false
            await reload()
        } catch { self.error = error.localizedDescription }
        sending = false
    }
    private func markSeen(_ m: MailItem) async {
        guard m.seen == 0 else { return }
        try? await store.api.mailSeen(mailId: m.id)
    }
    private func deleteMail(_ m: MailItem) async {
        try? await store.api.mailDelete(mailId: m.id)
        await reload()
    }
    private func timeStr(_ ts: Int?) -> String {
        guard let ts else { return "" }
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = DateFormatter(); f.dateFormat = "dd/MM HH:mm"
        return f.string(from: d)
    }
}
