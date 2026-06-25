import SwiftUI
import WebKit

// ======================== Trình duyệt mini: xem phim · nghe nhạc trong app ========================
final class BrowserModel: ObservableObject {
    @Published var urlText = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var pageTitle = ""

    enum Command { case load(String), back, forward, reload, stop }
    var onCommand: ((Command) -> Void)?

    func go() { onCommand?(.load(urlText)) }
    func open(_ s: String) { urlText = s; onCommand?(.load(s)) }
    func back() { onCommand?(.back) }
    func forward() { onCommand?(.forward) }
    func reload() { onCommand?(.reload) }
}

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel
    let home: String

    func makeCoordinator() -> Coordinator { Coordinator(model) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.allowsPictureInPictureMediaPlayback = true

        // Bypass Page Visibility API — ngăn YouTube/web pause video khi chuyển app hoặc khoá màn hình
        let visibilityScript = WKUserScript(
            source: """
            Object.defineProperty(document, 'hidden', { get: () => false });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible' });
            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        cfg.userContentController.addUserScript(visibilityScript)

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = context.coordinator
        let coord = context.coordinator
        coord.webView = wv
        model.onCommand = { [weak wv, weak coord] cmd in
            guard let wv else { return }
            switch cmd {
            case .load(let s): coord?.load(s, in: wv)
            case .back:        wv.goBack()
            case .forward:     wv.goForward()
            case .reload:      wv.reload()
            case .stop:        wv.stopLoading()
            }
        }
        coord.load(home, in: wv)
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: BrowserModel
        weak var webView: WKWebView?
        init(_ m: BrowserModel) { model = m }

        func load(_ s: String, in wv: WKWebView) {
            var str = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !str.isEmpty else { return }
            if str.contains(" ") || !str.contains(".") {
                // không phải URL → tìm kiếm Google
                let q = str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str
                str = "https://www.google.com/search?q=\(q)"
            } else if !str.lowercased().hasPrefix("http") {
                str = "https://" + str
            }
            if let u = URL(string: str) { wv.load(URLRequest(url: u)) }
        }

        private func sync(_ wv: WKWebView) {
            model.canGoBack = wv.canGoBack
            model.canGoForward = wv.canGoForward
            model.isLoading = wv.isLoading
            model.pageTitle = wv.title ?? ""
            if let u = wv.url?.absoluteString { model.urlText = u }
        }
        func webView(_ wv: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { model.isLoading = true; sync(wv) }
        func webView(_ wv: WKWebView, didFinish n: WKNavigation!) { model.isLoading = false; sync(wv) }
        func webView(_ wv: WKWebView, didFail n: WKNavigation!, withError e: Error) { model.isLoading = false; sync(wv) }
        func webView(_ wv: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { model.isLoading = false; sync(wv) }
    }
}

// Lối tắt web/game do người dùng tự thêm
struct WebShortcut: Identifiable, Codable {
    var id = UUID()
    var name: String
    var url: String
}

struct MediaWebView: View {
    @StateObject private var model = BrowserModel()
    @FocusState private var addressFocused: Bool

    // Lối tắt tùy chỉnh (thêm game/app của bạn)
    @AppStorage("kenios_web_shortcuts") private var shortcutsRaw = "[]"
    @State private var showAddShortcut = false
    @State private var newName = ""
    @State private var newURL = ""

    private let home = "https://m.youtube.com"
    private let shortcuts: [(String, String, String)] = [
        ("YouTube",  "play.tv.fill",          "https://m.youtube.com"),
        ("Game",     "gamecontroller.fill",   "https://www.crazygames.com"),
        ("Âm nhạc",  "music.note",            "https://soundcloud.com/discover"),
        ("Spotify",  "music.note.list",       "https://open.spotify.com"),
        ("Phim",     "film.fill",             "https://www.youtube.com/results?search_query=phim+hay"),
        ("KenMail",  "envelope.fill",         "https://mail.kenios.store"),
        ("Tìm kiếm", "magnifyingglass",       "https://www.google.com"),
    ]

    private var customShortcuts: [WebShortcut] {
        (try? JSONDecoder().decode([WebShortcut].self, from: Data(shortcutsRaw.utf8))) ?? []
    }
    private func saveCustom(_ list: [WebShortcut]) {
        if let d = try? JSONEncoder().encode(list) { shortcutsRaw = String(data: d, encoding: .utf8) ?? "[]" }
    }
    private func addCustom() {
        var url = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        if !url.lowercased().hasPrefix("http") { url = "https://" + url }
        let name = newName.trimmingCharacters(in: .whitespaces).isEmpty ? url : newName
        var list = customShortcuts
        list.append(WebShortcut(name: name, url: url))
        saveCustom(list)
        newName = ""; newURL = ""
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                // Thanh địa chỉ + điều hướng
                HStack(spacing: 8) {
                    Button { model.back() } label: { Image(systemName: "chevron.left") }
                        .disabled(!model.canGoBack)
                    Button { model.forward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!model.canGoForward)

                    HStack(spacing: 6) {
                        Image(systemName: model.isLoading ? "arrow.triangle.2.circlepath" : "globe")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("Nhập địa chỉ web hoặc từ khoá...", text: $model.urlText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.webSearch)
                            .focused($addressFocused)
                            .submitLabel(.go)
                            .onSubmit { model.go(); addressFocused = false }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())

                    Button { model.isLoading ? model.onCommand?(.stop) : model.reload() } label: {
                        Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                    }
                }
                .padding(.horizontal)

                // Phím tắt nhanh
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shortcuts, id: \.0) { s in
                            Button { model.open(s.2); addressFocused = false } label: {
                                Label(s.0, systemImage: s.1).font(.caption)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                        // Lối tắt do người dùng thêm (game/app riêng)
                        ForEach(customShortcuts) { s in
                            Button { model.open(s.url); addressFocused = false } label: {
                                Label(s.name, systemImage: "star.fill").font(.caption)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Theme.accent.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    saveCustom(customShortcuts.filter { $0.id != s.id })
                                } label: { Label("Xoá", systemImage: "trash") }
                            }
                        }
                        // Nút thêm lối tắt
                        Button { newName = ""; newURL = ""; showAddShortcut = true } label: {
                            Label("Thêm", systemImage: "plus").font(.caption)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }

                if model.isLoading { ProgressView().frame(maxWidth: .infinity) }

                BrowserWebView(model: model, home: home)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Giải trí")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Thêm game / app (web)", isPresented: $showAddShortcut) {
                TextField("Tên (vd: Game của tôi)", text: $newName)
                TextField("Link (vd: crazygames.com)", text: $newURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Thêm") { addCustom() }
                Button("Huỷ", role: .cancel) { }
            } message: {
                Text("Dán link game/website để thêm vào lối tắt và chơi ngay trong app.")
            }
        }
    }
}
