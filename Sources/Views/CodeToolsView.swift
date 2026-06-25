import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit
import CryptoKit

struct CodeToolsView: View {
    @EnvironmentObject var store: AppStore
    @State private var seg = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $seg) {
                    Text("Chạy code").tag(0)
                    Text("AI lập trình").tag(1)
                    Text("Web/Game").tag(2)
                    Text("Bảo mật & Mod").tag(3)
                    Text("DevOps").tag(4)
                    Text("Proxy").tag(5) // ← THÊM
                }
                .pickerStyle(.segmented).padding()
                
                if seg == 0 { RunPythonPane() }
                else if seg == 1 { CodeAIPane() }
                else if seg == 2 { WebPreviewPane() }
                else if seg == 3 { SecurityModPane() }
                else if seg == 4 { DevOpsToolsPane() } // ← THAY ĐỔI
                else { ProxyPane() } // ← THÊM
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThreeDLogoText(size: 20)
                }
            }
        }
    }
}

// ======================== Chạy Python trên server ========================
struct RunPythonPane: View {
    @EnvironmentObject var store: AppStore
    @State private var code = "print(\"Xin chào KENIOS!\")"
    @State private var stdin = ""
    @State private var result: CodeRunResult?
    @State private var running = false
    @State private var error: String?
    @State private var showImporter = false
    @State private var language = "python"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Code").font(.subheadline.bold())
                    Picker("", selection: $language) {
                        Text("Python").tag("python")
                        Text("JavaScript").tag("javascript")
                        Text("TypeScript").tag("typescript")
                        Text("Bash").tag("bash")
                        Text("PHP").tag("php")
                        Text("Ruby").tag("ruby")
                        Text("C").tag("c")
                        Text("C++").tag("cpp")
                        Text("Go").tag("go")
                        Text("Java").tag("java")
                        Text("Rust").tag("rust")
                    }.pickerStyle(.menu)
                    Spacer()
                    Button { showImporter = true } label: {
                        Label("Thêm tệp", systemImage: "doc.badge.plus").font(.caption)
                    }
                }
                TextEditor(text: $code)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if language == "java" {
                    Text("Java: lớp public phải đặt tên là Main (file Main.java).")
                        .font(.caption).foregroundStyle(.orange)
                }

                Text("Stdin (tuỳ chọn)").font(.subheadline.bold())
                TextField("Dữ liệu nhập cho input()...", text: $stdin, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        if running { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text("Chạy code").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.accent).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(running || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let result {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Kết quả").font(.subheadline.bold())
                            Button {
                                UIPasteboard.general.string = result.stdout + (result.stderr.isEmpty ? "" : "\n" + result.stderr)
                            } label: { Image(systemName: "doc.on.doc").font(.caption) }
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
                    }
                }

                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .padding()
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item], // chỉ .item để mọi file đều chọn được
                      allowsMultipleSelection: true) { loadFiles($0) }
    }

    private func loadFiles(_ res: Result<[URL], Error>) {
        guard case .success(let urls) = res, !urls.isEmpty else { return }
        var parts: [String] = []
        var failed = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                parts.append(urls.count > 1 ? "# ===== \(url.lastPathComponent) =====\n\(text)" : text)
            } else {
                failed += 1
            }
        }
        if !parts.isEmpty { code = parts.joined(separator: "\n\n") }
        error = failed > 0 ? "Bỏ qua \(failed) tệp nhị phân (không phải text/code)." : nil
    }

    private func run() async {
        running = true; error = nil; result = nil
        do {
            result = try await store.api.runCode(language: language, code: code,
                                                 stdin: stdin.isEmpty ? nil : stdin)
        } catch { self.error = error.localizedDescription }
        running = false
    }
}

// ======================== AI lập trình (review/debug/explain/...) ========================
struct CodeAIPane: View {
    @EnvironmentObject var store: AppStore

    @State private var code = ""
    @State private var language = "python"
    @State private var task = "review"
    @State private var targetLang = "JavaScript"
    @State private var provider = ""
    @State private var result: String?
    @State private var running = false
    @State private var error: String?
    @State private var showImporter = false

    private let tasks: [(String, String)] = [
        ("review", "Review code"),
        ("debug", "Debug / sửa lỗi"),
        ("explain", "Giải thích"),
        ("convert", "Chuyển ngôn ngữ"),
        ("test", "Viết unit test"),
        ("optimize", "Tối ưu hiệu năng"),
        ("document", "Viết docstring"),
        ("security", "Kiểm tra bảo mật"),
        ("refactor", "Refactor sạch hơn"),
        ("simplify", "Rút gọn code"),
        ("typehint", "Thêm type hint"),
        ("comment", "Thêm comment"),
        ("rename", "Đặt tên rõ nghĩa"),
        ("complexity", "Phân tích Big-O"),
        ("errorhandling", "Thêm xử lý lỗi"),
        ("validate", "Validate đầu vào"),
        ("logging", "Thêm logging"),
        ("async", "Chuyển sang async"),
        ("oop", "Chuyển sang OOP"),
        ("functional", "Phong cách hàm"),
        ("modernize", "Cú pháp hiện đại"),
        ("deprecate", "Tìm API lỗi thời"),
        ("lint", "Soát coding style"),
        ("edgecases", "Liệt kê edge case"),
        ("mockdata", "Sinh dữ liệu mẫu"),
        ("memory", "Soát rò rỉ bộ nhớ"),
        ("threadsafe", "Soát thread-safe"),
        ("dependency", "Giảm phụ thuộc"),
        ("configextract", "Tách cấu hình"),
        ("i18n", "Tách chuỗi đa ngữ"),
        ("regex", "Giải thích regex"),
        ("sqlexplain", "Giải thích SQL"),
        ("sqloptimize", "Tối ưu SQL"),
        ("apidoc", "Sinh tài liệu API"),
        ("readme", "Viết README"),
        ("dockerfile", "Viết Dockerfile"),
        ("ciyaml", "Viết CI/CD"),
        ("explainerror", "Giải thích lỗi"),
        ("boilerplate", "Sinh khung từ mô tả"),
        ("cheatsheet", "Tạo cheat sheet"),
        ("translatecmt", "Dịch comment"),
        ("responsive", "Làm responsive web"),
        ("accessibility", "Soát accessibility"),
        ("namingstyle", "Chuẩn hoá đặt tên"),
    ]
    private let languages = ["python", "javascript", "typescript", "swift", "kotlin",
                              "go", "rust", "c", "cpp", "java", "php", "html", "css", "sql", "shell"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dán code cần xử lý").font(.subheadline.bold())
                    Spacer()
                    Button { showImporter = true } label: {
                        Label("Thêm tệp", systemImage: "doc.badge.plus").font(.caption)
                    }
                }
                TextEditor(text: $code)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ngôn ngữ").font(.caption).foregroundStyle(.secondary)
                        Picker("Ngôn ngữ", selection: $language) {
                            ForEach(languages, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tác vụ").font(.caption).foregroundStyle(.secondary)
                        Picker("Tác vụ", selection: $task) {
                            ForEach(tasks, id: \.0) { Text($0.1).tag($0.0) }
                        }
                    }
                }

                if task == "convert" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chuyển sang").font(.caption).foregroundStyle(.secondary)
                        TextField("VD: JavaScript, Kotlin, Go...", text: $targetLang)
                            .padding(8).background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI sử dụng").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(store.providers.filter { ($0.code ?? false) }) { p in
                                Button { provider = p.id } label: {
                                    HStack(spacing: 6) {
                                        if provider == p.id { Image(systemName: "checkmark").font(.caption2) }
                                        Circle().fill(providerColor(p.id)).frame(width: 7, height: 7)
                                        Text(p.label.components(separatedBy: " · ").first ?? p.id)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(provider == p.id ? Theme.accent.opacity(0.25) : Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                                    .opacity(store.configuredKeys.contains(p.id) ? 1 : 0.4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        if running { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text("Gửi cho AI").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Theme.accent).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(running || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || provider.isEmpty || !store.configuredKeys.contains(provider))

                if !store.configuredKeys.contains(provider) && !provider.isEmpty {
                    Text("Chưa có API key cho AI này. Vào Cài đặt → API Keys.")
                        .font(.caption).foregroundStyle(.orange)
                }

                if let result {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kết quả").font(.subheadline.bold())
                        Text(result)
                            .font(.system(.footnote, design: .monospaced))
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                            .contextMenu {
                                Button { UIPasteboard.general.string = result } label: {
                                    Label("Sao chép", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }

                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .padding()
        }
        .onAppear {
            if provider.isEmpty {
                provider = store.configuredKeys.first(where: { id in
                    store.providers.first(where: { $0.id == id })?.code ?? false
                }) ?? store.providers.first(where: { $0.code ?? false })?.id ?? ""
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item], // chỉ .item để mọi file đều chọn được
                      allowsMultipleSelection: true) { loadFiles($0) }
    }

    private func loadFiles(_ res: Result<[URL], Error>) {
        guard case .success(let urls) = res, !urls.isEmpty else { return }
        let map = ["py": "python", "js": "javascript", "ts": "typescript", "swift": "swift",
                   "kt": "kotlin", "go": "go", "rs": "rust", "c": "c", "cpp": "cpp",
                   "java": "java", "php": "php", "html": "html", "css": "css", "sql": "sql", "sh": "shell"]
        var parts: [String] = []
        var failed = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                parts.append(urls.count > 1 ? "// ===== \(url.lastPathComponent) =====\n\(text)" : text)
                if let l = map[url.pathExtension.lowercased()] { language = l }
            } else {
                failed += 1
            }
        }
        if !parts.isEmpty { code = parts.joined(separator: "\n\n") }
        error = failed > 0 ? "Bỏ qua \(failed) tệp nhị phân (không phải text/code)." : nil
    }

    private func run() async {
        running = true; error = nil; result = nil
        do {
            let r = try await store.api.codeAI(provider: provider, code: code, language: language,
                                               task: task, targetLang: task == "convert" ? targetLang : nil)
            result = r.result
        } catch { self.error = error.localizedDescription }
        running = false
    }
}

// ======================== Cấu hình Auto-Click (bấm tự động · đa nhiệm) ========================
struct AutoClickConfig: Equatable {
    var enabled = false
    var clicksPerSecond: Double = 5       // tốc độ: số lần bấm mỗi giây cho MỖI mục tiêu
    var selectors: String = "button"      // danh sách CSS selector, ngăn cách bởi dấu phẩy → đa nhiệm
}

// ======================== Xem trước Web / Game (giả lập trong app) ========================
struct WebPreview: UIViewRepresentable {
    let html: String
    var reloadToken: Int = 0
    var autoClick: AutoClickConfig = .init()
    var onClickCount: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebPreview
        var loadedToken = -1
        var loadedHTML = "\u{1}"
        var lastScript = ""
        var appliedScript = ""
        init(_ p: WebPreview) { parent = p }

        func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "kclick", let n = message.body as? Int { parent.onClickCount?(n) }
        }
        // Timer bị xoá mỗi lần trang tải lại → cài lại auto-click khi tải xong
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(lastScript)
            appliedScript = lastScript
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.userContentController.add(context.coordinator, name: "kclick")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.scrollView.bounces = false
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        let coord = context.coordinator
        coord.parent = self
        let script = Self.clickScript(autoClick)
        coord.lastScript = script

        if coord.loadedToken != reloadToken || coord.loadedHTML != html {
            coord.loadedToken = reloadToken
            coord.loadedHTML = html
            coord.appliedScript = ""   // sẽ được cài lại trong didFinish khi trang tải xong
            let content = html.isEmpty
                ? "<html><body style='font-family:-apple-system;color:#888;text-align:center;padding-top:40px'>Bấm \"Chạy thử\" để xem web/game ở đây.</body></html>"
                : html
            wv.loadHTMLString(content, baseURL: nil)
        } else if coord.appliedScript != script {
            // Chỉ cập nhật khi cấu hình auto-click thực sự đổi (không chạy lại mỗi lần đếm số)
            coord.appliedScript = script
            wv.evaluateJavaScript(script)
        }
    }

    /// Sinh JS cài nhiều bộ đếm giờ bấm tự động — mỗi selector một luồng riêng (đa nhiệm).
    static func clickScript(_ cfg: AutoClickConfig) -> String {
        let sels = cfg.selectors
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let cps = max(0.2, min(cfg.clicksPerSecond, 60))
        let interval = Int(1000.0 / cps)
        let selData = (try? JSONEncoder().encode(sels)) ?? Data("[]".utf8)
        let selArray = String(data: selData, encoding: .utf8) ?? "[]"
        let enabled = (cfg.enabled && !sels.isEmpty) ? "true" : "false"
        return """
        (function(){
          if(window.__kTimers){window.__kTimers.forEach(function(t){clearInterval(t)});}
          window.__kTimers=[];
          if(window.__kClicks===undefined){window.__kClicks=0;}
          function report(){try{window.webkit.messageHandlers.kclick.postMessage(window.__kClicks);}catch(e){}}
          if(!\(enabled)){ report(); return; }
          var sels=\(selArray);
          sels.forEach(function(sel){
            window.__kTimers.push(setInterval(function(){
              try{
                var els=document.querySelectorAll(sel);
                if(els.length===0){return;}
                els.forEach(function(e){ e.click(); window.__kClicks++; });
              }catch(e){}
            }, \(interval)));
          });
          window.__kTimers.push(setInterval(report, 300));
        })();
        """
    }
}

struct WebPreviewPane: View {
    @EnvironmentObject var store: AppStore
    @State private var html = WebPreviewPane.sample
    @State private var preview = ""
    @State private var runToken = 0           // tăng mỗi lần "Chạy thử" → buộc tải lại dù code không đổi
    @State private var showImporter = false
    @State private var showFull = false
    @State private var gameDesc = ""
    @State private var provider = ""
    @State private var generating = false
    @State private var error: String?

    // Auto-Click (bấm tự động · chỉnh tốc độ · đa nhiệm)
    @State private var autoClick = AutoClickConfig()
    @State private var clickCount = 0

    static let sample = """
    <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
    <style>body{font-family:-apple-system;text-align:center;padding:24px}
    button{font-size:20px;padding:12px 22px;margin:6px;border:none;border-radius:12px;background:#4f46e5;color:#fff}
    #s{font-size:28px;color:#4f46e5}</style>
    </head><body><h2>KENIOS Web/Game</h2><p>Điểm: <b id="s">0</b></p>
    <button id="tap" onclick="add(1)">Bấm để tăng điểm</button>
    <button onclick="add(10)">+10</button>
    <script>var c=0;function add(n){c+=n;document.getElementById('s').innerText=c;}</script>
    </body></html>
    """

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("HTML / JS — web · game").font(.subheadline.bold())
                Spacer()
                Button { showImporter = true } label: {
                    Label("Thêm tệp", systemImage: "doc.badge.plus").font(.caption)
                }
            }
            TextEditor(text: $html)
                .font(.system(.footnote, design: .monospaced))
                .frame(height: 110)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                TextField("Tả game muốn AI viết (vd: game rắn săn mồi)...", text: $gameDesc)
                    .padding(8).background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button { Task { await generate() } } label: {
                    HStack(spacing: 4) {
                        if generating { ProgressView() }
                        else { Image(systemName: "wand.and.stars") }
                        Text("AI viết").font(.caption.bold())
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Theme.accent).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(generating || gameDesc.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Button { run() } label: {
                    Label("Chạy thử", systemImage: "play.fill").bold()
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { run(); showFull = true } label: {
                    Label("Toàn màn hình", systemImage: "arrow.up.left.and.arrow.down.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            autoClickControls

            if !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ShareLink(item: webFileURL()) {
                    Label("Lưu file HTML về máy", systemImage: "square.and.arrow.down")
                        .font(.caption).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let error { Text(error).foregroundStyle(.red).font(.caption) }

            WebPreview(html: preview, reloadToken: runToken, autoClick: autoClick,
                       onClickCount: { clickCount = $0 })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator)))
        }
        .padding()
        .onAppear {
            if provider.isEmpty {
                provider = store.configuredKeys.first(where: { id in
                    store.providers.first(where: { $0.id == id })?.code ?? false
                }) ?? store.configuredKeys.first ?? ""
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item], // chỉ .item để mọi file đều chọn được
                      allowsMultipleSelection: true) { loadFile($0) }
        .sheet(isPresented: $showFull) {
            NavigationStack {
                WebPreview(html: preview, reloadToken: runToken, autoClick: autoClick,
                           onClickCount: { clickCount = $0 })
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Chơi thử").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showFull = false } } }
            }
        }
    }

    // MARK: - Auto-Click (bấm tự động · chỉnh tốc độ · đa nhiệm)
    private var autoClickControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $autoClick.enabled) {
                HStack(spacing: 6) {
                    Image(systemName: "cursorarrow.click.2")
                    Text("Auto-Click").font(.subheadline.bold())
                    if autoClick.enabled {
                        Text("• \(clickCount) lần")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .tint(Theme.accent)

            HStack(spacing: 8) {
                Image(systemName: "speedometer").foregroundStyle(.secondary)
                Slider(value: $autoClick.clicksPerSecond, in: 0.5...30, step: 0.5)
                Text(String(format: "%.1f/s", autoClick.clicksPerSecond))
                    .font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
            }

            HStack(spacing: 6) {
                Image(systemName: "scope").foregroundStyle(.secondary)
                TextField("Mục tiêu CSS (vd: #tap, button) — nhiều mục tiêu ngăn bởi dấu phẩy", text: $autoClick.selectors)
                    .font(.caption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("Mỗi mục tiêu chạy một luồng bấm riêng (đa nhiệm). Tốc độ áp dụng cho từng mục tiêu.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func run() {
        preview = html
        runToken &+= 1
        clickCount = 0
    }

    private func webFileURL() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("kenios_web.html")
        try? html.data(using: .utf8)?.write(to: u)
        return u
    }

    private func loadFile(_ res: Result<[URL], Error>) {
        guard case .success(let urls) = res, !urls.isEmpty else { return }
        var parts: [String] = []
        var failed = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                parts.append(text)
            } else { failed += 1 }
        }
        if !parts.isEmpty {
            // Nhiều tệp → ghép lại (vd index.html + style.css + script.js)
            html = parts.joined(separator: "\n")
            preview = html
            runToken &+= 1
        }
        error = failed > 0 ? "Bỏ qua \(failed) tệp không đọc được (nhị phân)." : nil
    }

    private func generate() async {
        // Tự chọn AI có key nếu chưa có
        if provider.isEmpty {
            provider = store.configuredKeys.first(where: { id in
                store.providers.first(where: { $0.id == id })?.code ?? false
            }) ?? store.configuredKeys.first ?? ""
        }
        guard !provider.isEmpty else {
            error = "Chưa có AI nào có key. Vào Cài đặt → API Keys thêm key (vd Gemini hoặc Groq, miễn phí) rồi quay lại."
            return
        }
        generating = true; error = nil
        let prompt = """
        Viết một game/web hoàn chỉnh theo mô tả: "\(gameDesc)".
        Yêu cầu: TẤT CẢ trong MỘT file index.html duy nhất (HTML + CSS + JavaScript inline), không dùng thư viện ngoài, chạy được ngay trên trình duyệt điện thoại. Chỉ trả về code trong một khối ```html ... ```, không giải thích.
        """
        do {
            let r = try await store.api.chat(provider: provider, message: prompt, image: nil,
                                             model: nil, conversationId: nil, system: nil)
            let code = WebPreviewPane.extractCode(r.reply)
            html = code; preview = code
        } catch { self.error = error.localizedDescription }
        generating = false
    }

    static func extractCode(_ text: String) -> String {
        let parts = text.components(separatedBy: "```")
        guard parts.count >= 3 else { return text }
        var block = parts[1]
        if let nl = block.firstIndex(of: "\n") {
            let lang = block[..<nl].trimmingCharacters(in: .whitespaces)
            if lang.count < 20 && !lang.contains("<") {
                block = String(block[block.index(after: nl)...])
            }
        }
        return block.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// ======================== Bảo mật & Mod Game ========================
struct SecurityModPane: View {
    @EnvironmentObject var store: AppStore
    
    @State private var toolMode = 0 // 0: Mã hóa Code, 1: PE/Hex, 2: Hợp ngữ AI
    
    // Code Encryption States
    @State private var inputCode = "print(\"KENIOS Game Hack\")"
    @State private var language = "python"
    @State private var level = "high"
    @State private var encryptedResult = ""
    @State private var encrypting = false
    @State private var encryptError: String?
    
    // PE/Hex States
    @State private var showFileImporter = false
    @State private var analyzing = false
    @State private var analysisResult: BinaryAnalysisResponse?
    @State private var analyzeError: String?
    
    // ASM States
    @State private var asmInput = "mov eax, 1"
    @State private var asmMode = "assemble" // assemble or disassemble
    @State private var asmArch = "x86"
    @State private var asmResult = ""
    @State private var translating = false
    @State private var asmError: String?
    @State private var provider = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $toolMode) {
                Text("Mã hóa").tag(0)
                Text("PE / Hex").tag(1)
                Text("Hợp ngữ").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if toolMode == 0 {
                        codeEncryptView
                    } else if toolMode == 1 {
                        peHexView
                    } else {
                        asmView
                    }
                }
                .padding()
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    // MARK: - Code Encrypt UI
    private var codeEncryptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nhập mã nguồn cần bảo vệ").font(.subheadline).bold()
            
            TextEditor(text: $inputCode)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            HStack {
                Picker("Ngôn ngữ", selection: $language) {
                    Text("Python").tag("python")
                    Text("JavaScript").tag("javascript")
                    Text("C/C++").tag("c")
                }
                Spacer()
                Picker("Cường độ", selection: $level) {
                    Text("Cơ bản").tag("low")
                    Text("Nâng cao").tag("high")
                }
            }
            .padding(.horizontal, 4)
            
            Button {
                Task { await runEncrypt() }
            } label: {
                HStack {
                    if encrypting { ProgressView().tint(.white) }
                    else { Image(systemName: "lock.shield") }
                    Text("Mã hóa mã nguồn").bold()
                }
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(encrypting ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(encrypting || inputCode.isEmpty)
            
            if !encryptedResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Kết quả mã hóa").font(.subheadline).bold()
                        Spacer()
                        Button {
                            UIPasteboard.general.string = encryptedResult
                        } label: {
                            Label("Sao chép", systemImage: "doc.on.doc").font(.caption)
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            saveToLibrary(text: encryptedResult, ext: language == "python" ? "py" : "js")
                        } label: {
                            Label("Lưu file", systemImage: "square.and.arrow.down").font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text(encryptedResult)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                }
                .padding(.top, 8)
            }
            
            if let err = encryptError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
    }
    
    // MARK: - PE / Hex Analyzer UI
    private var peHexView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phân tích tệp Binary PE/ELF & Xem mã Hex").font(.subheadline).bold()
            Text("Hỗ trợ đọc cấu trúc tệp EXE, DLL, DEX, DYLIB và xuất chuỗi ký tự (Strings) để mod game.")
                .font(.caption).foregroundStyle(.secondary)
            
            Button {
                showFileImporter = true
            } label: {
                HStack {
                    if analyzing {
                        ProgressView().tint(.white)
                        Text("Đang tải & phân tích...")
                    } else {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Chọn tệp cần phân tích (.exe, .dll, .dat...)")
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(analyzing ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(analyzing)
            
            if let res = analysisResult {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Thông tin tệp tin").font(.headline)
                        HStack {
                            Text("Định dạng:")
                            Spacer()
                            Text(res.fileType).bold()
                        }
                        HStack {
                            Text("Kiến trúc:")
                            Spacer()
                            Text(res.architecture ?? "N/A").bold()
                        }
                        HStack {
                            Text("Entry Point:")
                            Spacer()
                            Text(res.entryPoint ?? "N/A").bold()
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text("Hex Dump (2048 bytes đầu)").font(.subheadline).bold()
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(res.hexDump)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if let strings = res.strings, !strings.isEmpty {
                        Text("Chuỗi ASCII trích xuất (Symbol/Strings)").font(.subheadline).bold()
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(strings, id: \.self) { s in
                                    Text(s)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.vertical, 2)
                                    Divider()
                                }
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxHeight: 180)
                    }
                }
            }
            
            if let err = analyzeError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
    }
    
    // MARK: - Hợp ngữ (ASM) UI
    private var asmView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dịch hợp ngữ qua AI (Assembler / Disassembler)").font(.subheadline).bold()
            
            Picker("", selection: $asmMode) {
                Text("Lệnh → Hex (Assemble)").tag("assemble")
                Text("Hex → Lệnh (Disasm)").tag("disassemble")
            }
            .pickerStyle(.segmented)
            
            TextField(asmMode == "assemble" ? "Ví dụ: mov eax, 1" : "Ví dụ: 90 90 31 C0", text: $asmInput)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            HStack {
                Picker("Kiến trúc", selection: $asmArch) {
                    Text("x86 / x64").tag("x86")
                    Text("ARM / ARM64").tag("arm")
                }
                Spacer()
                
                Picker("AI", selection: $provider) {
                    ForEach(store.providers.filter { $0.code ?? false }) { p in
                        Text(p.label.components(separatedBy: " · ").first ?? p.id).tag(p.id)
                    }
                }
            }
            
            Button {
                Task { await runTranslateAsm() }
            } label: {
                HStack {
                    if translating { ProgressView().tint(.white) }
                    else { Image(systemName: "cpu") }
                    Text("Dịch bằng AI").bold()
                }
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(translating || asmInput.isEmpty ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(translating || asmInput.isEmpty)
            
            if !asmResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Kết quả dịch").font(.subheadline).bold()
                        Spacer()
                        Button {
                            UIPasteboard.general.string = asmResult
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }
                    }
                    Text(asmResult)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .textSelection(.enabled)
                }
            }
            
            if let err = asmError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .onAppear {
            if provider.isEmpty {
                provider = store.configuredKeys.first(where: { id in
                    store.providers.first(where: { $0.id == id })?.code ?? false
                }) ?? store.providers.first(where: { $0.code ?? false })?.id ?? "gemini"
            }
        }
    }
    
    // MARK: - Handlers & Logic
    private func runEncrypt() async {
        encrypting = true
        encryptedResult = ""
        encryptError = nil
        do {
            let res = try await store.api.encryptCode(code: inputCode, language: language, level: level)
            encryptedResult = res.result
        } catch {
            encryptError = error.localizedDescription
        }
        encrypting = false
    }
    
    private func handleFileImport(_ res: Result<[URL], Error>) {
        guard case .success(let urls) = res, let url = urls.first else { return }
        analyzing = true
        analysisResult = nil
        analyzeError = nil
        
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        
        Task {
            do {
                let r = try await store.api.analyzeBinary(fileURL: url)
                analysisResult = r
            } catch {
                analyzeError = error.localizedDescription
            }
            analyzing = false
        }
    }
    
    private func runTranslateAsm() async {
        translating = true
        asmResult = ""
        asmError = nil
        do {
            let res = try await store.api.translateAsm(input: asmInput, mode: asmMode, arch: asmArch, provider: provider)
            asmResult = res.result
        } catch {
            asmError = error.localizedDescription
        }
        translating = false
    }
    
    private func saveToLibrary(text: String, ext: String) {
        Task {
            do {
                let filename = "encrypted_code_\(Int(Date().timeIntervalSince1970)).\(ext)"
                let dataB64 = Data(text.utf8).base64EncodedString()
                _ = try await store.api.uploadFile(name: filename, category: "code", dataBase64: dataB64)
            } catch {
                print("Error saving to library: \(error)")
            }
        }
    }
}

// ======================== Phân hệ DevOps & DevOps Tools ========================
struct DevOpsToolsPane: View {
    @EnvironmentObject var store: AppStore
    @State private var subTab = 0 // 0: SSH, 1: REST, 2: SQL, 3: Crypto
    
    // SSH state
    @State private var sshHost = ""
    @State private var sshUser = "root"
    @State private var sshPass = ""
    @State private var sshCmd = "uname -a"
    @State private var sshResult: SSHResultResponse? = nil
    @State private var sshRunning = false
    @State private var sshError: String? = nil
    
    // REST Client state
    @State private var httpMethod = "GET"
    @State private var httpUrl = "https://httpbin.org/get"
    @State private var httpHeaders = "{\n  \"Content-Type\": \"application/json\"\n}"
    @State private var httpBody = ""
    @State private var httpResult: HTTPTestResponse? = nil
    @State private var httpRunning = false
    @State private var httpError: String? = nil
    
    // SQL state
    @State private var sqlQuery = "SELECT name FROM sqlite_master WHERE type='table';"
    @State private var sqlResult: SQLResultResponse? = nil
    @State private var sqlRunning = false
    @State private var sqlError: String? = nil
    
    // Crypto state
    @State private var cryptoInput = ""
    @State private var cryptoAlgo = "Base64 Encode"
    @State private var cryptoResult = ""
    
    let cryptoAlgos = [
        "Base64 Encode", "Base64 Decode",
        "URL Encode", "URL Decode",
        "Hex Encode", "Hex Decode",
        "MD5 Hashing", "SHA-256 Hashing"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $subTab) {
                    Text("SSH Terminal").tag(0)
                    Text("REST Client").tag(1)
                    Text("SQL Manager").tag(2)
                    Text("Crypto Suite").tag(3)
                }
                .pickerStyle(.segmented)
                
                if subTab == 0 {
                    sshPane
                } else if subTab == 1 {
                    restPane
                } else if subTab == 2 {
                    sqlPane
                } else {
                    cryptoPane
                }
            }
            .padding()
        }
    }
    
    // MARK: - SSH Client UI
    private var sshPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terminal SSH").font(.headline)
            Text("Kết nối VPS Linux và thực thi câu lệnh từ xa.").font(.caption).foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                TextField("IP / Hostname (e.g. 192.168.1.1)", text: $sshHost)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                HStack(spacing: 8) {
                    TextField("Username", text: $sshUser)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Mật khẩu / Key Pass", text: $sshPass)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            
            Text("Lệnh thực thi").font(.subheadline.bold())
            TextEditor(text: $sshCmd)
                .font(.system(.body, design: .monospaced))
                .frame(height: 80)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button {
                Task { await runSSH() }
            } label: {
                HStack {
                    if sshRunning {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "terminal")
                    }
                    Text("Thực thi SSH").bold()
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(sshRunning ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(sshRunning || sshHost.isEmpty || sshUser.isEmpty)
            
            if let err = sshError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            
            if let res = sshResult {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Kết quả SSH Console").font(.caption.bold()).foregroundStyle(.secondary)
                        Spacer()
                        Text("Exit Code: \(res.exitCode)")
                            .font(.caption2)
                            .foregroundStyle(res.exitCode == 0 ? .green : .red)
                        Button {
                            let out = res.stdout + "\n" + res.stderr
                            UIPasteboard.general.string = out
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if !res.stdout.isEmpty {
                                Text(res.stdout)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            if !res.stderr.isEmpty {
                                Text(res.stderr)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    .frame(height: 200)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private func runSSH() async {
        sshRunning = true
        sshError = nil
        sshResult = nil
        do {
            sshResult = try await store.api.runSSH(host: sshHost, user: sshUser, pass: sshPass, cmd: sshCmd)
        } catch {
            sshError = error.localizedDescription
        }
        sshRunning = false
    }
    
    // MARK: - REST Client UI
    private var restPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REST Client").font(.headline)
            Text("Gửi HTTP request tùy chỉnh (Bỏ qua lỗi CORS trên mobile).").font(.caption).foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Picker("", selection: $httpMethod) {
                    Text("GET").tag("GET")
                    Text("POST").tag("POST")
                    Text("PUT").tag("PUT")
                    Text("DELETE").tag("DELETE")
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                TextField("URL", text: $httpUrl)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Text("Headers (JSON)").font(.subheadline.bold())
            TextEditor(text: $httpHeaders)
                .font(.system(.footnote, design: .monospaced))
                .frame(height: 80)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if httpMethod == "POST" || httpMethod == "PUT" {
                Text("Request Body").font(.subheadline.bold())
                TextEditor(text: $httpBody)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(height: 100)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Button {
                Task { await sendHTTPRequest() }
            } label: {
                HStack {
                    if httpRunning {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "paperplane")
                    }
                    Text("Gửi yêu cầu").bold()
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(httpRunning ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(httpRunning || httpUrl.isEmpty)
            
            if let err = httpError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            
            if let res = httpResult {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Text("Phản hồi").font(.subheadline.bold())
                        Spacer()
                        Text("Status: \(res.status)")
                            .font(.caption.bold())
                            .foregroundStyle(res.status >= 200 && res.status < 300 ? .green : (res.status >= 400 ? .red : .orange))
                        
                        Button {
                            UIPasteboard.general.string = res.body
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }
                    }
                    
                    Text("Body").font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        Text(res.body)
                            .font(.system(.footnote, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }
                    .frame(height: 180)
                }
            }
        }
    }
    
    private func sendHTTPRequest() async {
        httpRunning = true
        httpError = nil
        httpResult = nil
        
        // Parse headers
        var parsedHeaders: [String: String] = [:]
        let cleanedHeaders = httpHeaders.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedHeaders.isEmpty {
            if let data = cleanedHeaders.data(using: .utf8) {
                do {
                    if let parsed = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                        parsedHeaders = parsed
                    } else {
                        httpError = "Lỗi: Headers phải là một JSON dictionary dạng {\"Key\": \"Value\"}."
                        httpRunning = false
                        return
                    }
                } catch {
                    httpError = "Lỗi định dạng JSON Headers: \(error.localizedDescription)"
                    httpRunning = false
                    return
                }
            }
        }
        
        do {
            httpResult = try await store.api.runHTTP(url: httpUrl, method: httpMethod, headers: parsedHeaders, body: httpBody)
        } catch {
            httpError = error.localizedDescription
        }
        httpRunning = false
    }
    
    // MARK: - SQL Manager UI
    private var sqlPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quản trị CSDL SQLite").font(.headline)
            Text("Chạy lệnh SQL trực tiếp trên file database của hệ thống.").font(.caption).foregroundStyle(.secondary)
            
            if !store.isAdmin {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Cảnh báo bảo mật").font(.caption.bold()).foregroundStyle(.orange)
                    }
                    Text("Chỉ tài khoản Admin mới có quyền thực thi các câu lệnh sửa đổi database (INSERT, UPDATE, DELETE, DROP...).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Text("Truy vấn SQL").font(.subheadline.bold())
            TextEditor(text: $sqlQuery)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button {
                Task { await runSQL() }
            } label: {
                HStack {
                    if sqlRunning {
                        ProgressView().tint(.white).padding(.trailing, 4)
                    } else {
                        Image(systemName: "database")
                    }
                    Text("Thực thi SQL").bold()
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(sqlRunning ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(sqlRunning || sqlQuery.isEmpty)
            
            if let err = sqlError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            
            if let res = sqlResult {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    if let msg = res.message {
                        Text(msg).font(.caption).foregroundStyle(.green)
                    }
                    
                    if !res.columns.isEmpty {
                        Text("Bảng kết quả").font(.subheadline.bold())
                        
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Header row
                                HStack(spacing: 0) {
                                    ForEach(res.columns, id: \.self) { col in
                                        Text(col)
                                            .font(.caption.bold())
                                            .padding(8)
                                            .frame(width: 120, alignment: .leading)
                                            .background(Color(.systemGray4))
                                            .border(Color.gray.opacity(0.3), width: 0.5)
                                    }
                                }
                                
                                // Data rows
                                ForEach(0..<res.rows.count, id: \.self) { rIdx in
                                    HStack(spacing: 0) {
                                        ForEach(0..<res.rows[rIdx].count, id: \.self) { cIdx in
                                            Text(res.rows[rIdx][cIdx])
                                                .font(.caption)
                                                .padding(8)
                                                .frame(width: 120, alignment: .leading)
                                                .background(rIdx % 2 == 0 ? Color(.secondarySystemBackground) : Color(.systemBackground))
                                                .border(Color.gray.opacity(0.2), width: 0.5)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                        .border(Color.gray.opacity(0.3), width: 1)
                    }
                }
            }
        }
    }
    
    private func runSQL() async {
        sqlRunning = true
        sqlError = nil
        sqlResult = nil
        do {
            sqlResult = try await store.api.runSQL(query: sqlQuery)
        } catch {
            sqlError = error.localizedDescription
        }
        sqlRunning = false
    }
    
    // MARK: - Crypto Suite UI
    private var cryptoPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mã hóa & Băm dữ liệu").font(.headline)
            Text("Chuyển đổi định dạng, băm chuỗi (MD5, SHA-256) ngay tại thiết bị.").font(.caption).foregroundStyle(.secondary)
            
            Text("Dữ liệu đầu vào").font(.subheadline.bold())
            TextEditor(text: $cryptoInput)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            HStack {
                Text("Thuật toán")
                Spacer()
                Picker("", selection: $cryptoAlgo) {
                    ForEach(cryptoAlgos, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Button {
                runCrypto()
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Chuyển đổi / Băm").bold()
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(cryptoInput.isEmpty ? Color.gray : Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(cryptoInput.isEmpty)
            
            if !cryptoResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack {
                        Text("Kết quả đầu ra").font(.subheadline.bold())
                        Spacer()
                        Button {
                            UIPasteboard.general.string = cryptoResult
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }
                    }
                    Text(cryptoResult)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private func runCrypto() {
        let input = cryptoInput
        switch cryptoAlgo {
        case "Base64 Encode":
            cryptoResult = Data(input.utf8).base64EncodedString()
        case "Base64 Decode":
            if let data = Data(base64Encoded: input) {
                cryptoResult = String(data: data, encoding: .utf8) ?? "Lỗi: Kết quả giải mã không phải chuỗi văn bản UTF-8."
            } else {
                cryptoResult = "Lỗi: Chuỗi đầu vào không phải Base64 hợp lệ."
            }
        case "URL Encode":
            cryptoResult = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        case "URL Decode":
            cryptoResult = input.removingPercentEncoding ?? input
        case "Hex Encode":
            cryptoResult = Data(input.utf8).map { String(format: "%02x", $0) }.joined()
        case "Hex Decode":
            let hex = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
            var data = Data()
            var idx = hex.startIndex
            var valid = true
            while idx < hex.endIndex {
                let nextIdx = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
                let hexByte = String(hex[idx..<nextIdx])
                if let val = UInt8(hexByte, radix: 16) {
                    data.append(val)
                } else {
                    valid = false
                    break
                }
                idx = nextIdx
            }
            if valid {
                cryptoResult = String(data: data, encoding: .utf8) ?? "Lỗi: Kết quả giải mã không phải chuỗi văn bản UTF-8."
            } else {
                cryptoResult = "Lỗi: Chuỗi hex không hợp lệ."
            }
        case "MD5 Hashing":
            let digest = Insecure.MD5.hash(data: Data(input.utf8))
            cryptoResult = digest.map { String(format: "%02hhx", $0) }.joined()
        case "SHA-256 Hashing":
            let digest = SHA256.hash(data: Data(input.utf8))
            cryptoResult = digest.map { String(format: "%02hhx", $0) }.joined()
        default:
            cryptoResult = ""
        }
    }
}
