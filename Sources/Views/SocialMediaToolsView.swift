import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import WebKit
import Photos

// Điểm phát Live (RTMP + stream key) lưu lại để phát đa nền tảng
struct LiveTarget: Identifiable, Codable {
    var id = UUID()
    var name: String
    var rtmp: String
    var key: String
}

struct SocialMediaToolsView: View {
    @EnvironmentObject var store: AppStore

    @State private var selectedSegment = 0 // 0: AI Generator, 1: Downloader, 2: Live Tools

    // Phát Live đa nền tảng (nhập stream key / link)
    @AppStorage("kenios_live_targets") private var liveTargetsRaw = "[]"
    @State private var ltName = ""
    @State private var ltRtmp = "rtmp://"
    @State private var ltKey = ""
    @State private var ltLink = ""
    
    // Downloader States
    @State private var videoURL = ""
    @State private var videoQuality = "1080"
    @State private var downloading = false
    @State private var downloadedFileId: Int?
    @State private var downloadedFileName: String?
    @State private var downloadedFileSize: Int = 0
    @State private var downloaderError: String?
    @State private var previewURL: URL?
    @State private var savingToPhotos = false
    @State private var saveMessage: String?
    
    // Live Tools States
    @State private var livePlatform = "tiktok"
    @State private var liveCookies = ""
    @State private var liveAccessToken = ""
    @State private var showBrowser = false
    @State private var browserURL = ""
    @State private var streamRTMP = ""
    @State private var streamKey = ""
    @State private var streamError: String?
    @State private var fetchingStream = false
    @State private var browserSiteName = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Banner sang trọng
                KHeroHeader(icon: "globe.badge.ellipsis",
                            title: "Mạng xã hội",
                            subtitle: "Sáng tạo nội dung · Tải video · Live đa nền tảng")
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Segmented picker
                Picker("", selection: $selectedSegment) {
                    Text("Sửa Video").tag(0)
                    Text("Tải Video").tag(1)
                    Text("Live Tools").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedSegment == 0 {
                    VideoEditorView()
                } else if selectedSegment == 1 {
                    downloaderPane
                } else {
                    liveToolsPane
                }
            }
            .navigationTitle("Mạng xã hội")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ThreeDLogoText(size: 20)
                }
            }
            .quickLookPreview($previewURL)
            .sheet(isPresented: $showBrowser) {
                CookieBrowserView(urlString: browserURL) { cookies in
                    self.liveCookies = cookies
                    saveCookieToLibrary(cookies: cookies, siteName: browserSiteName)
                }
            }
        }
    }

    // MARK: - Downloader Pane
    private var downloaderPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Link TikTok · Facebook · Pinterest · YouTube").font(.subheadline).bold()
                    TextField("Dán link video ở đây...", text: $videoURL)
                        .padding(12)
                        .kGlass(RoundedRectangle(cornerRadius: 12))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // Chọn độ phân giải
                VStack(alignment: .leading, spacing: 6) {
                    Text("Độ phân giải").font(.caption).foregroundStyle(.secondary)
                    Picker("Độ phân giải", selection: $videoQuality) {
                        Text("720p").tag("720")
                        Text("1080p").tag("1080")
                        Text("2K").tag("2k")
                        Text("4K").tag("4k")
                        Text("Cao nhất").tag("best")
                    }
                    .pickerStyle(.segmented)
                }

                // Submit button
                Button {
                    Task { await runDownload() }
                } label: {
                    HStack {
                        if downloading {
                            ProgressView().tint(.white)
                            Text("Đang cào & tải xuống...")
                        } else {
                            Image(systemName: "arrow.down.circle")
                            Text("Tải video về hệ thống")
                        }
                    }
                    .font(.headline).bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(downloading || videoURL.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(downloading || videoURL.trimmingCharacters(in: .whitespaces).isEmpty)
                
                // Download Success View
                if let fileId = downloadedFileId, let name = downloadedFileName {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        
                        VStack(spacing: 4) {
                            Text("Tải thành công!").font(.headline)
                            Text(name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            Text(humanSize(downloadedFileSize)).font(.caption).foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            // Xem trước
                            Button {
                                Task { await previewDownloaded(fileId) }
                            } label: {
                                Label("Xem trước", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            // Mở thư viện trong app
                            Button {
                                store.tab = 3 // LibraryView tag
                            } label: {
                                Label("Thư viện app", systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Lưu vào Thư viện ảnh của máy (camera roll)
                        Button {
                            Task { await saveToPhotos(fileId) }
                        } label: {
                            HStack {
                                if savingToPhotos { ProgressView().tint(.white) }
                                Image(systemName: "square.and.arrow.down.fill")
                                Text(savingToPhotos ? "Đang lưu vào máy..." : "Lưu vào Thư viện máy")
                            }
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(savingToPhotos ? Color.gray : Theme.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(savingToPhotos)

                        if let saveMessage {
                            Text(saveMessage)
                                .font(.caption)
                                .foregroundStyle(saveMessage.contains("✓") ? .green : .red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
                
                if let err = downloaderError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
                
                // Guide/Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Hướng dẫn sử dụng:").font(.footnote).bold()
                    Text("• Hỗ trợ tải video TikTok không logo bằng cách tự động cào API TikWM.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("• Hỗ trợ tải video Facebook HD/SD trực tiếp từ mã nguồn HTML.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("• Tất cả video tải về sẽ lưu trực tiếp vào mục Tài liệu trong Thư viện của bạn để có thể xem lại bất kỳ lúc nào bằng QuickLook.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .kCard(12)
            }
            .padding()
        }
    }
    
    // MARK: - Live Tools Pane
    private var liveToolsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: Cookie Extractor Browser
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Bộ trích xuất Cookie tài khoản").font(.headline)
                    Text("Đăng nhập tài khoản mạng xã hội của bạn thông qua trình duyệt an toàn tích hợp dưới đây để tự động lấy Cookie.")
                        .font(.caption).foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Button {
                            browserURL = "https://www.tiktok.com/login"
                            browserSiteName = "tiktok"
                            showBrowser = true
                        } label: {
                            Label("TikTok", systemImage: "play.tv")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            browserURL = "https://m.facebook.com/"
                            browserSiteName = "facebook"
                            showBrowser = true
                        } label: {
                            Label("Facebook", systemImage: "person.2")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            browserURL = "https://m.youtube.com/"
                            browserSiteName = "youtube"
                            showBrowser = true
                        } label: {
                            Label("YouTube", systemImage: "video")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .kCard(16)
                
                // Section 2: Get Stream Key
                VStack(alignment: .leading, spacing: 12) {
                    Text("2. Tạo Live Stream & Lấy Stream Key").font(.headline)
                    
                    Picker("Chọn nền tảng phát", selection: $livePlatform) {
                        Text("TikTok Live").tag("tiktok")
                        Text("Facebook Live").tag("facebook")
                    }
                    .pickerStyle(.segmented)
                    
                    if livePlatform == "tiktok" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dán Cookie TikTok (Đã trích xuất hoặc tự nhập)").font(.caption).bold()
                            TextEditor(text: $liveCookies)
                                .frame(height: 80)
                                .padding(6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nhập Facebook Access Token").font(.caption).bold()
                            TextField("EAA...", text: $liveAccessToken)
                                .padding(12)
                                .kGlass(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Button {
                        Task { await fetchStreamKey() }
                    } label: {
                        HStack {
                            if fetchingStream {
                                ProgressView().tint(.white)
                                Text("Đang tạo Live...")
                            } else {
                                Image(systemName: "video.fill")
                                Text("Tạo Live & Lấy RTMP + Key")
                            }
                        }
                        .font(.headline).bold().foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(fetchingStream ? Color.gray : Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(fetchingStream)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .kCard(16)
                
                // Display Results
                if !streamRTMP.isEmpty && !streamKey.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kết quả cấu hình phát trực tiếp").font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Máy chủ RTMP (Server URL):").font(.caption).bold()
                            HStack {
                                Text(streamRTMP).font(.system(.caption, design: .monospaced)).lineLimit(1)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = streamRTMP
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                            .padding(8).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Khóa luồng (Stream Key):").font(.caption).bold()
                            HStack {
                                Text(streamKey).font(.system(.caption, design: .monospaced)).lineLimit(1)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = streamKey
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                            .padding(8).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding()
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Text("💡 Copy hai dòng trên cấu hình vào OBS Studio hoặc các ứng dụng Livestream trên máy tính để phát Live.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                }

                // Section 3: Phát Live đa nền tảng bằng stream key / link
                multiLivePane

                if let err = streamError {
                    Text(err).foregroundStyle(.red).font(.caption).padding(.horizontal)
                }
            }
            .padding()
        }
    }

    // MARK: - Phát Live đa nền tảng (stream key / link)
    private var multiLivePane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3. Phát Live đa nền tảng (stream key / link)").font(.headline)
            Text("Dán sẵn RTMP URL + Stream Key của TikTok / YouTube / Facebook... Lưu nhiều điểm phát rồi copy vào OBS/app phát để live cùng lúc.")
                .font(.caption).foregroundStyle(.secondary)

            // Tách nhanh từ 1 link gộp rtmp://.../streamkey
            VStack(alignment: .leading, spacing: 6) {
                Text("Dán link gộp (rtmp://máy-chủ/.../stream-key)").font(.caption).bold()
                HStack {
                    TextField("rtmp://...", text: $ltLink)
                        .font(.system(.caption, design: .monospaced))
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                        .padding(10).background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button("Tách") { splitLink() }
                        .buttonStyle(.bordered)
                        .disabled(!ltLink.contains("/"))
                }
            }

            TextField("Tên (vd: TikTok của tôi)", text: $ltName)
                .padding(10).background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            TextField("RTMP URL (vd: rtmp://...)", text: $ltRtmp)
                .font(.system(.caption, design: .monospaced))
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(10).background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            TextField("Stream Key", text: $ltKey)
                .font(.system(.caption, design: .monospaced))
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(10).background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                addTarget()
            } label: {
                Label("Lưu điểm phát", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Theme.accent).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(ltKey.trimmingCharacters(in: .whitespaces).isEmpty || ltRtmp.count < 8)

            ForEach(liveTargets) { t in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.red)
                        Text(t.name).font(.subheadline.bold())
                        Spacer()
                        Button(role: .destructive) { removeTarget(t) } label: {
                            Image(systemName: "trash").font(.caption)
                        }
                    }
                    keyRow("RTMP", t.rtmp)
                    keyRow("Key", t.key)
                    Button {
                        UIPasteboard.general.string = "Server: \(t.rtmp)\nKey: \(t.key)"
                    } label: {
                        Label("Copy cả RTMP + Key", systemImage: "doc.on.doc").font(.caption)
                    }.buttonStyle(.bordered)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("📌 iOS không tự đẩy hình từ camera khi app chưa ký. Dùng OBS Studio (máy tính) hoặc app phát RTMP, dán Server + Key vào để live. Có thể lưu nhiều nền tảng để restream.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .kCard(16)
    }

    private func keyRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
            Text(value).font(.system(.caption2, design: .monospaced)).lineLimit(1)
            Spacer()
            Button { UIPasteboard.general.string = value } label: { Image(systemName: "doc.on.doc").font(.caption2) }
        }
        .padding(8).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var liveTargets: [LiveTarget] {
        (try? JSONDecoder().decode([LiveTarget].self, from: Data(liveTargetsRaw.utf8))) ?? []
    }
    private func saveTargets(_ list: [LiveTarget]) {
        if let d = try? JSONEncoder().encode(list) {
            liveTargetsRaw = String(data: d, encoding: .utf8) ?? "[]"
        }
    }
    private func splitLink() {
        let link = ltLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = link.lastIndex(of: "/") else { return }
        ltRtmp = String(link[..<idx])
        ltKey = String(link[link.index(after: idx)...])
    }
    private func addTarget() {
        var list = liveTargets
        let name = ltName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Điểm phát \(list.count + 1)" : ltName
        list.append(LiveTarget(name: name,
                               rtmp: ltRtmp.trimmingCharacters(in: .whitespaces),
                               key: ltKey.trimmingCharacters(in: .whitespaces)))
        saveTargets(list)
        ltName = ""; ltRtmp = "rtmp://"; ltKey = ""; ltLink = ""
    }
    private func removeTarget(_ t: LiveTarget) {
        saveTargets(liveTargets.filter { $0.id != t.id })
    }
    
    // MARK: - Helpers
    private func runDownload() async {
        downloading = true
        downloadedFileId = nil
        downloadedFileName = nil
        downloaderError = nil
        saveMessage = nil
        do {
            let res = try await store.api.socialDownload(url: videoURL, quality: videoQuality)
            downloadedFileId = res.fileId
            downloadedFileName = res.filename
            downloadedFileSize = res.size
            videoURL = ""
        } catch {
            downloaderError = error.localizedDescription
        }
        downloading = false
    }
    
    private func previewDownloaded(_ fileId: Int) async {
        do {
            let (tempURL, filename) = try await store.api.downloadFileRaw(fileId)
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let destinationURL = cacheDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: tempURL, to: destinationURL)
            self.previewURL = destinationURL
        } catch {
            downloaderError = error.localizedDescription
        }
    }

    // Lưu video/ảnh đã tải về vào Thư viện ảnh của máy (camera roll)
    private func saveToPhotos(_ fileId: Int) async {
        savingToPhotos = true
        saveMessage = nil
        do {
            // Tải file về thư mục tạm
            let (tempURL, filename) = try await store.api.downloadFileRaw(fileId)
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let destinationURL = cacheDir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: tempURL, to: destinationURL)

            // Xin quyền thêm vào Photos
            let status = await withCheckedContinuation { (cont: CheckedContinuation<PHAuthorizationStatus, Never>) in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { cont.resume(returning: $0) }
            }
            guard status == .authorized || status == .limited else {
                saveMessage = "Chưa được cấp quyền lưu vào Thư viện ảnh. Vào Cài đặt > KENIOS > Ảnh để bật."
                savingToPhotos = false
                return
            }

            let ext = (filename as NSString).pathExtension.lowercased()
            let isImage = ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains(ext)

            try await PHPhotoLibrary.shared().performChanges {
                if isImage {
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: destinationURL)
                } else {
                    PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
                }
            }
            saveMessage = isImage ? "Đã lưu ảnh vào Thư viện máy ✓" : "Đã lưu video vào Thư viện máy ✓"
        } catch {
            saveMessage = "Lưu thất bại: \(error.localizedDescription)"
        }
        savingToPhotos = false
    }

    private func fetchStreamKey() async {
        fetchingStream = true
        streamRTMP = ""
        streamKey = ""
        streamError = nil
        do {
            let res: StreamKeyResponse
            if livePlatform == "tiktok" {
                res = try await store.api.getTikTokStreamKey(cookies: liveCookies)
            } else {
                res = try await store.api.getFacebookStreamKey(accessToken: liveAccessToken)
            }
            streamRTMP = res.rtmpUrl
            streamKey = res.streamKey
        } catch {
            streamError = error.localizedDescription
        }
        fetchingStream = false
    }
    
    private func saveCookieToLibrary(cookies: String, siteName: String) {
        Task {
            do {
                let filename = "cookie_\(siteName)_\(Int(Date().timeIntervalSince1970)).txt"
                let dataB64 = Data(cookies.utf8).base64EncodedString()
                _ = try await store.api.uploadFile(name: filename, category: "document", dataBase64: dataB64)
            } catch {
                print("Error saving cookie: \(error)")
            }
        }
    }
    
    private func humanSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Cookie Browser View (WKWebView Sheet)
struct CookieBrowserView: View {
    let urlString: String
    let onExtract: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var loading = true
    
    var body: some View {
        NavigationStack {
            WebViewWrapper(urlString: urlString, loading: $loading)
                .navigationTitle("Đăng nhập tài khoản")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Hủy") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Trích xuất Cookie") {
                            Task {
                                let cookies = await extractCookies()
                                onExtract(cookies)
                                dismiss()
                            }
                        }
                        .bold()
                    }
                }
                .overlay {
                    if loading {
                        ProgressView()
                    }
                }
        }
    }
    
    private func extractCookies() async -> String {
        let store = WKWebsiteDataStore.default().httpCookieStore
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                store.getAllCookies { cookies in
                    // Format cookies as JSON
                    let cookieArray = cookies.map { cookie -> [String: Any] in
                        let dict: [String: Any] = [
                            "name": cookie.name,
                            "value": cookie.value,
                            "domain": cookie.domain,
                            "path": cookie.path
                        ]
                        return dict
                    }
                    
                    if let data = try? JSONSerialization.data(withJSONObject: cookieArray, options: .prettyPrinted),
                       let jsonStr = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: jsonStr)
                    } else {
                        // Fallback to Netscape format
                        let netscapeLines = cookies.map { cookie -> String in
                            let expires = Int(cookie.expiresDate?.timeIntervalSince1970 ?? 0)
                            return "\(cookie.domain)\tTRUE\t\(cookie.path)\t\(cookie.isSecure ? "TRUE" : "FALSE")\t\(expires)\t\(cookie.name)\t\(cookie.value)"
                        }
                        continuation.resume(returning: netscapeLines.joined(separator: "\n"))
                    }
                }
            }
        }
    }
}

// MARK: - WKWebView UIViewRepresentable
struct WebViewWrapper: UIViewRepresentable {
    let urlString: String
    @Binding var loading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.loading = false
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.loading = true
        }
    }
}
