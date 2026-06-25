import SwiftUI
import CryptoKit
import CoreImage.CIFilterBuiltins
import AVFoundation

// ======================== Models ========================
struct TOTPEntry: Identifiable, Codable {
    var id = UUID()
    var name: String
    var secret: String     // base32
}
struct VaultEntry: Identifiable, Codable {
    var id = UUID()
    var name: String
    var username: String
    var password: String
    var note: String = ""
}

// ======================== Lưu trữ (Keychain JSON) ========================
enum ToolStore {
    static func load<T: Codable>(_ key: String, _ type: [T].Type) -> [T] {
        guard let s = Keychain.load(key), let d = s.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: d)) ?? []
    }
    static func save<T: Codable>(_ key: String, _ list: [T]) {
        if let d = try? JSONEncoder().encode(list), let s = String(data: d, encoding: .utf8) {
            Keychain.save(key, s)
        }
    }
}

// ======================== Thuật toán TOTP (2FA) ========================
enum TOTP {
    static func base32Decode(_ s: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var lookup = [Character: Int]()
        for (i, c) in alphabet.enumerated() { lookup[c] = i }
        let clean = s.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "=", with: "")
        var bits = 0, value = 0
        var out = Data()
        for c in clean {
            guard let v = lookup[c] else { return nil }
            value = (value << 5) | v; bits += 5
            if bits >= 8 { out.append(UInt8((value >> (bits - 8)) & 0xFF)); bits -= 8 }
        }
        return out
    }

    static func code(secret: String, time: Date = Date(), digits: Int = 6, period: TimeInterval = 30) -> String? {
        guard let key = base32Decode(secret), !key.isEmpty else { return nil }
        var counter = UInt64(time.timeIntervalSince1970 / period).bigEndian
        let counterData = withUnsafeBytes(of: &counter) { Data($0) }
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: SymmetricKey(data: key))
        let hash = Data(mac)
        let offset = Int(hash[hash.count - 1] & 0x0f)
        let truncated = (UInt32(hash[offset] & 0x7f) << 24)
            | (UInt32(hash[offset + 1]) << 16)
            | (UInt32(hash[offset + 2]) << 8)
            | UInt32(hash[offset + 3])
        let mod = UInt32(pow(10.0, Double(digits)))
        return String(format: "%0\(digits)d", truncated % mod)
    }
}

// ======================== Tab Tiện ích ========================
struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("AI") {
                    NavigationLink { AssistantView() } label: {
                        Label("Trợ lý rảnh tay (giọng nói + streaming)", systemImage: "waveform.circle.fill")
                    }
                }
                Section("Bảo mật") {
                    NavigationLink { AuthenticatorView() } label: {
                        Label("Authenticator (mã 2FA)", systemImage: "lock.shield")
                    }
                    NavigationLink { VaultView() } label: {
                        Label("Két mật khẩu", systemImage: "key.fill")
                    }
                }
                Section("Tiện ích") {
                    NavigationLink { QRToolView() } label: {
                        Label("Mã QR (tạo & quét)", systemImage: "qrcode")
                    }
                    NavigationLink { NetToolsView() } label: {
                        Label("Net tools (IP, kiểm tra URL)", systemImage: "network")
                    }
                }
            }
            .navigationTitle("Tiện ích")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) } }
        }
    }
}

// ======================== Authenticator (2FA / TOTP) ========================
struct AuthenticatorView: View {
    @State private var entries: [TOTPEntry] = ToolStore.load("kenios_totp", [TOTPEntry].self)
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newSecret = ""

    var body: some View {
        List {
            if entries.isEmpty {
                Text("Thêm tài khoản bằng mã bí mật (base32) từ dịch vụ bật 2FA.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(entries) { e in
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    row(e, now: ctx.date)
                }
            }
            .onDelete { idx in entries.remove(atOffsets: idx); ToolStore.save("kenios_totp", entries) }
        }
        .navigationTitle("Authenticator")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .alert("Thêm tài khoản 2FA", isPresented: $showAdd) {
            TextField("Tên (vd: GitHub)", text: $newName)
            TextField("Mã bí mật (base32)", text: $newSecret)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Thêm") {
                let s = newSecret.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty {
                    entries.append(TOTPEntry(name: newName.isEmpty ? "Tài khoản" : newName, secret: s))
                    ToolStore.save("kenios_totp", entries)
                    newName = ""; newSecret = ""
                }
            }
            Button("Huỷ", role: .cancel) { }
        } message: { Text("Dán mã bí mật (Secret Key) dạng base32 mà dịch vụ cung cấp khi bật 2FA.") }
    }

    private func row(_ e: TOTPEntry, now: Date) -> some View {
        let code = TOTP.code(secret: e.secret, time: now) ?? "------"
        let remain = 30 - Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 30))
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).font(.subheadline)
                Text(code.prefix(3) + " " + code.suffix(3))
                    .font(.title2.monospacedDigit().bold()).foregroundStyle(Theme.accent)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 3).frame(width: 30, height: 30)
                Circle().trim(from: 0, to: CGFloat(remain) / 30)
                    .stroke(Theme.accent, lineWidth: 3).frame(width: 30, height: 30).rotationEffect(.degrees(-90))
                Text("\(remain)").font(.caption2)
            }
            Button { UIPasteboard.general.string = code } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless)
        }
    }
}

// ======================== Két mật khẩu ========================
struct VaultView: View {
    @State private var entries: [VaultEntry] = ToolStore.load("kenios_vault", [VaultEntry].self)
    @State private var search = ""
    @State private var showAdd = false
    @State private var n = ""; @State private var u = ""; @State private var p = ""; @State private var note = ""

    private var filtered: [VaultEntry] {
        search.isEmpty ? entries : entries.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.username.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { e in
                VStack(alignment: .leading, spacing: 4) {
                    Text(e.name).font(.subheadline.bold())
                    if !e.username.isEmpty {
                        HStack { Text(e.username).font(.caption)
                            Button { UIPasteboard.general.string = e.username } label: { Image(systemName: "doc.on.doc").font(.caption2) }.buttonStyle(.borderless) }
                    }
                    HStack { Text(String(repeating: "•", count: max(6, e.password.count))).font(.caption.monospaced())
                        Spacer()
                        Button { UIPasteboard.general.string = e.password } label: { Label("Copy mật khẩu", systemImage: "key").font(.caption2) }.buttonStyle(.borderless) }
                    if !e.note.isEmpty { Text(e.note).font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .onDelete { idx in
                let ids = idx.map { filtered[$0].id }
                entries.removeAll { ids.contains($0.id) }
                ToolStore.save("kenios_vault", entries)
            }
        }
        .searchable(text: $search)
        .navigationTitle("Két mật khẩu")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                Form {
                    TextField("Tên (vd: Email shop1)", text: $n)
                    TextField("Tài khoản / email", text: $u).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Mật khẩu", text: $p).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Ghi chú", text: $note)
                }
                .navigationTitle("Thêm mục").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Huỷ") { showAdd = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Lưu") {
                            entries.append(VaultEntry(name: n.isEmpty ? "Mục" : n, username: u, password: p, note: note))
                            ToolStore.save("kenios_vault", entries)
                            n = ""; u = ""; p = ""; note = ""; showAdd = false
                        }
                    }
                }
            }
        }
    }
}

// ======================== Mã QR ========================
struct QRToolView: View {
    @State private var text = ""
    @State private var qr: UIImage?
    @State private var showScan = false
    @State private var scanned = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Tạo mã QR").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                TextField("Nhập text / link / wifi...", text: $text, axis: .vertical)
                    .lineLimit(1...4).padding(10).background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button { qr = Self.makeQR(text) } label: {
                    Label("Tạo QR", systemImage: "qrcode").frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.accent).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }.disabled(text.isEmpty)
                if let qr {
                    Image(uiImage: qr).interpolation(.none).resizable().scaledToFit()
                        .frame(width: 220, height: 220)
                    ShareLink(item: Image(uiImage: qr), preview: SharePreview("QR", image: Image(uiImage: qr))) {
                        Label("Lưu / chia sẻ", systemImage: "square.and.arrow.up").font(.caption)
                    }
                }

                Divider().padding(.vertical, 6)

                Text("Quét mã QR").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Button { showScan = true } label: {
                    Label("Mở camera quét", systemImage: "camera.viewfinder").frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if !scanned.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kết quả:").font(.caption).foregroundStyle(.secondary)
                        Text(scanned).font(.callout).textSelection(.enabled)
                        HStack {
                            Button { UIPasteboard.general.string = scanned } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption) }
                            if scanned.lowercased().hasPrefix("http"), let u = URL(string: scanned) {
                                Link(destination: u) { Label("Mở", systemImage: "safari").font(.caption) }
                            }
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }.padding()
        }
        .navigationTitle("Mã QR")
        .sheet(isPresented: $showScan) {
            NavigationStack {
                QRScanner { code in scanned = code; showScan = false }
                    .ignoresSafeArea()
                    .navigationTitle("Quét QR").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showScan = false } } }
            }
        }
    }

    static func makeQR(_ s: String) -> UIImage? {
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(s.utf8)
        guard let out = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct QRScanner: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerVC { let vc = ScannerVC(); vc.onScan = onScan; return vc }
    func updateUIViewController(_ vc: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.compactMap { $0 as? AVCaptureVideoPreviewLayer }.first?.frame = view.layer.bounds
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let m = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let s = m.stringValue {
            session.stopRunning()
            onScan?(s)
        }
    }
}

// ======================== Net tools ========================
struct NetToolsView: View {
    @State private var ipInfo = ""
    @State private var loadingIP = false
    @State private var url = "https://"
    @State private var urlResult = ""
    @State private var checking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Thông tin IP").font(.headline)
                Button { Task { await fetchIP() } } label: {
                    HStack { if loadingIP { ProgressView().padding(.trailing, 4) }; Text("Lấy IP & vị trí") }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.accent).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if !ipInfo.isEmpty {
                    Text(ipInfo).font(.system(.footnote, design: .monospaced))
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                }

                Divider()

                Text("Kiểm tra URL (HTTP)").font(.headline)
                TextField("https://example.com", text: $url)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(10).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                Button { Task { await checkURL() } } label: {
                    HStack { if checking { ProgressView().padding(.trailing, 4) }; Text("Kiểm tra") }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                }.disabled(checking || url.count < 8)
                if !urlResult.isEmpty {
                    Text(urlResult).font(.system(.footnote, design: .monospaced))
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }.padding()
        }
        .navigationTitle("Net tools")
    }

    private func fetchIP() async {
        loadingIP = true; ipInfo = ""
        defer { loadingIP = false }
        guard let u = URL(string: "https://ipapi.co/json/") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let keys = ["ip", "city", "region", "country_name", "org", "asn", "timezone"]
                ipInfo = keys.compactMap { k in (obj[k] as? CustomStringConvertible).map { "\(k): \($0)" } }.joined(separator: "\n")
            }
        } catch { ipInfo = "Lỗi: \(error.localizedDescription)" }
    }

    private func checkURL() async {
        checking = true; urlResult = ""
        defer { checking = false }
        var s = url.trimmingCharacters(in: .whitespaces)
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        guard let u = URL(string: s) else { urlResult = "URL không hợp lệ."; return }
        var req = URLRequest(url: u); req.httpMethod = "HEAD"; req.timeoutInterval = 15
        let start = Date()
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            urlResult = "✅ Phản hồi \(code) · \(ms) ms"
        } catch { urlResult = "❌ \(error.localizedDescription)" }
    }
}
