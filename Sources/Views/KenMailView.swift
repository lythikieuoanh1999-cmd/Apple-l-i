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
    @State private var createPhone = ""

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

    // Quản lý tên miền custom
    @State private var customDomains: [MailDomain] = []
    @State private var selectedDomain = "" // Tên miền đang chọn (trống = mặc định)
    @State private var showManageDomains = false
    @State private var newDomainInput = ""
    @State private var addingDomain = false

    private var bulkResultsText: String {
        bulkResults.map { "\($0.address) | \($0.password)" }.joined(separator: "\n")
    }

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
                        Button { selectedDomain = ""; showCreate = true } label: { Label("Tạo 1 hộp thư", systemImage: "plus") }
                        Button { selectedDomain = ""; showBulk = true } label: { Label("Tạo nhiều ngẫu nhiên", systemImage: "rectangle.stack.badge.plus") }
                        Button { showManageDomains = true } label: { Label("Quản lý tên miền", systemImage: "globe") }
                        Divider()
                        Link(destination: URL(string: "https://portal.inet.vn")!) {
                            Label("Tạo email trên iNET", systemImage: "link")
                        }
                        Link(destination: URL(string: "https://mail.kenios.store")!) {
                            Label("Webmail kenios.store", systemImage: "envelope.circle")
                        }
                        if !mailboxes.isEmpty {
                            let listText = mailboxes.map { $0.address }.joined(separator: "\n")
                            ShareLink(item: listText, preview: SharePreview("danh_sach_mailbox.txt", image: Image(systemName: "envelope"))) {
                                Label("Lưu danh sách email", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: { Image(systemName: "plus") }
                    Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await loadBoxes() }
            .sheet(isPresented: $showCreate) { createBoxSheet }
            .sheet(isPresented: $showBulk) { bulkCreateSheet }
            .sheet(isPresented: $showManageDomains) { manageDomainsSheet }
            .sheet(isPresented: $showCompose) { composeSheet }
            .sheet(isPresented: $showBulkResults) { bulkResultSheet }
            .sheet(item: $openMail) { m in mailDetail(m) }
            .alert("Lỗi", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    // MARK: - Sheet Tạo Hộp Thư mới
    private var createBoxSheet: some View {
        NavigationStack {
            Form {
                Section("Thông tin Email") {
                    HStack {
                        TextField("tên (vd: cong)", text: $createLocal)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        Text("@")
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $selectedDomain) {
                            Text(domain).tag("")
                            ForEach(customDomains) { d in
                                Text(d.domain).tag(d.domain)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        SecureField("mật khẩu (≥6 ký tự)", text: $createPass)
                        Button {
                            createPass = secretsRandomPass()
                        } label: {
                            Image(systemName: "shuffle").foregroundColor(.blue)
                        }
                    }

                    TextField("Số điện thoại (tuỳ chọn)", text: $createPhone)
                        .keyboardType(.phonePad)
                }
                
                Section {
                    Button {
                        Task { await createBox() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Tạo Hộp Thư").bold()
                            Spacer()
                        }
                    }
                    .disabled(createLocal.isEmpty || createPass.count < 6)
                }
            }
            .navigationTitle("Tạo Hộp Thư")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Huỷ") { showCreate = false }
                }
            }
        }
    }

    // MARK: - Sheet Tạo Hàng Loạt
    private var bulkCreateSheet: some View {
        NavigationStack {
            Form {
                Section("Cấu hình hàng loạt") {
                    Picker("Tên miền", selection: $selectedDomain) {
                        Text(domain).tag("")
                        ForEach(customDomains) { d in
                            Text(d.domain).tag(d.domain)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Số lượng (1–50)", text: $bulkCount)
                        .keyboardType(.numberPad)
                    
                    TextField("Tiền tố (vd: gamecenter)", text: $bulkPrefix)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button {
                        Task { await bulkCreate() }
                    } label: {
                        HStack {
                            Spacer()
                            if bulking {
                                ProgressView()
                            } else {
                                Text("Tạo Hàng Loạt").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(bulking || bulkCount.isEmpty)
                }
            }
            .navigationTitle("Tạo Hàng Loạt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Huỷ") { showBulk = false }
                }
            }
        }
    }

    // MARK: - Sheet Quản lý Tên miền
    private var manageDomainsSheet: some View {
        NavigationStack {
            List {
                Section(header: Text("Thêm tên miền tùy chỉnh")) {
                    HStack {
                        TextField("vd: domain.com", text: $newDomainInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        
                        Button {
                            Task { await addDomain() }
                        } label: {
                            if addingDomain {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(newDomainInput.isEmpty || addingDomain)
                    }
                }
                
                Section(header: Text("Tên miền đã thêm")) {
                    if customDomains.isEmpty {
                        Text("Chưa có tên miền tùy chỉnh nào.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(customDomains) { d in
                            VStack(alignment: .leading) {
                                Text(d.domain).font(.headline)
                                if let ts = d.createdAt {
                                    Text("Đã thêm: \(timeStr(ts))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await deleteDomain(d) }
                                } label: {
                                    Label("Xoá", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("HƯỚNG DẪN CẤU HÌNH (DNS)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Để nhận được email trên tên miền riêng của bạn:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("1. Tạo bản ghi MX:")
                            .font(.caption2).bold()
                        Text("• Host/Name: @\n• Value: IP_VPS_CỦA_BẠN\n• Priority: 10")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(6)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(4)
                        
                        Text("2. Tạo bản ghi SPF (để gửi mail không vào spam):")
                            .font(.caption2).bold()
                        Text("• Host/Name: @\n• Type: TXT\n• Value: v=spf1 ip4:IP_VPS_CỦA_BẠN -all")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(6)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Tên miền tùy chỉnh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { showManageDomains = false }
                }
            }
        }
    }

    // MARK: - Kết quả tạo hàng loạt
    private var bulkResultSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        UIPasteboard.general.string = bulkResultsText
                    } label: { Label("Copy tất cả (địa chỉ | mật khẩu)", systemImage: "doc.on.doc") }
                    
                    ShareLink(item: bulkResultsText, preview: SharePreview("danh_sach_mail.txt", image: Image(systemName: "doc.text"))) {
                        Label("Lưu vào File (TXT)", systemImage: "square.and.arrow.up")
                    }
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
            Button { selectedDomain = ""; showCreate = true } label: {
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
                    // Tự nhận diện mã xác nhận (OTP) trong thư → nút copy nhanh
                    if let code = Self.detectOTP((m.subject ?? "") + " " + (m.body ?? "")) {
                        Button { UIPasteboard.general.string = code } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Mã xác nhận: \(code)").font(.headline.monospacedDigit())
                                Spacer()
                                Image(systemName: "doc.on.doc")
                            }
                            .padding(12).background(Theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                    Text(m.body ?? "").font(.body).textSelection(.enabled)
                }.padding()
            }
            .navigationTitle("Thư").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { openMail = nil } } }
        }
    }

    /// Tìm mã OTP (4–8 chữ số) trong nội dung thư.
    static func detectOTP(_ text: String) -> String? {
        let pattern = "\\b[0-9]{4,8}\\b"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let m = re.firstMatch(in: text, range: range), let r = Range(m.range, in: text) {
            return String(text[r])
        }
        return nil
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
            await loadDomains()
            if selected != nil { await reload() }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
    
    private func loadDomains() async {
        do {
            customDomains = try await store.api.mailDomainsList()
        } catch {
            print("Lỗi tải tên miền: \(error.localizedDescription)")
        }
    }

    private func addDomain() async {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, clean.contains(".") else {
            error = "Tên miền không hợp lệ."; return
        }
        addingDomain = true
        do {
            _ = try await store.api.mailDomainsAdd(domain: clean)
            newDomainInput = ""
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
        addingDomain = false
    }

    private func deleteDomain(_ d: MailDomain) async {
        do {
            _ = try await store.api.mailDomainsDelete(id: d.id)
            await loadDomains()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func secretsRandomPass() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<12).compactMap { _ in chars.randomElement() })
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
            let r = try await store.api.mailCreate(local: local, password: createPass,
                                                   domain: selectedDomain, phone: createPhone)
            createLocal = ""; createPass = ""; createPhone = ""
            showCreate = false
            await loadBoxes()
            selected = mailboxes.first { $0.id == r.id } ?? mailboxes.first
            await reload()
        } catch { self.error = error.localizedDescription }
    }

    private func bulkCreate() async {
        let n = max(1, min(Int(bulkCount) ?? 10, 50))
        bulking = true; error = nil
        do {
            let r = try await store.api.mailBulkCreate(count: n, prefix: bulkPrefix, domain: selectedDomain)
            bulkResults = r.created
            bulkPrefix = ""
            showBulk = false
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
