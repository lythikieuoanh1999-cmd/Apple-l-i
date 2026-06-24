import Foundation

enum APIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}

struct APIClient {
    let baseURL: String
    var token: String?

    private var root: String {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private func makeURL(_ path: String) throws -> URL {
        guard let u = URL(string: root + path) else {
            throw APIError.message("URL máy chủ không hợp lệ.")
        }
        return u
    }

    private func send(_ path: String, method: String = "GET",
                      json: [String: Any]? = nil, auth: Bool = true) async throws -> Data {
        var req = URLRequest(url: try makeURL(path))
        req.httpMethod = method
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let json { req.httpBody = try JSONSerialization.data(withJSONObject: json) }

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.message("Không kết nối được máy chủ. Kiểm tra IP/URL & mạng.")
        }
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.message("Phản hồi không hợp lệ.")
        }
        if !(200..<300).contains(http.statusCode) {
            var detail = "Lỗi máy chủ (\(http.statusCode))."
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let d = obj["detail"] as? String { detail = d }
            throw APIError.message(detail)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(T.self, from: data)
    }

    // ---- Hệ thống ----
    func getConfig() async throws -> ServerConfig {
        try decode(try await send("/config", auth: false))
    }
    func getProviders() async throws -> [Provider] {
        try decode(try await send("/providers", auth: false))
    }

    // ---- Tài khoản ----
    func register(_ username: String, _ password: String, email: String?, phone: String?) async throws -> AuthResponse {
        var body: [String: Any] = ["username": username, "password": password]
        if let email, !email.isEmpty { body["email"] = email }
        if let phone, !phone.isEmpty { body["phone"] = phone }
        return try decode(try await send("/auth/register", method: "POST", json: body, auth: false))
    }
    func login(_ username: String, _ password: String) async throws -> AuthResponse {
        try decode(try await send("/auth/login", method: "POST",
                                  json: ["username": username, "password": password], auth: false))
    }
    func forgot(_ username: String) async throws -> ForgotResponse {
        try decode(try await send("/auth/forgot-password", method: "POST",
                                  json: ["username": username], auth: false))
    }
    func reset(_ token: String, _ newPassword: String) async throws -> MessageResponse {
        try decode(try await send("/auth/reset-password", method: "POST",
                                  json: ["token": token, "new_password": newPassword], auth: false))
    }
    func updateProfile(email: String?, phone: String?, newPassword: String?) async throws -> MessageResponse {
        var body: [String: Any] = [:]
        if let email { body["email"] = email }
        if let phone { body["phone"] = phone }
        if let newPassword, !newPassword.isEmpty { body["new_password"] = newPassword }
        return try decode(try await send("/auth/update-profile", method: "POST", json: body))
    }

    // ---- API key (user) ----
    func saveKey(provider: String, apiKey: String) async throws -> MessageResponse {
        try decode(try await send("/keys", method: "POST",
                                  json: ["provider": provider, "api_key": apiKey]))
    }
    func listKeys() async throws -> [KeyInfo] {
        try decode(try await send("/keys"))
    }
    func deleteKey(provider: String) async throws -> MessageResponse {
        try decode(try await send("/keys/\(provider)", method: "DELETE"))
    }
    func testKey(provider: String, apiKey: String) async throws -> MessageResponse {
        try decode(try await send("/keys/test", method: "POST",
                                  json: ["provider": provider, "api_key": apiKey]))
    }

    // ---- Chat ----
    func chat(provider: String, message: String, image: String?,
              fileBase64: String? = nil, fileMime: String? = nil,
              attachments: [[String: String]]? = nil,
              model: String?, conversationId: Int?, system: String? = nil,
              webSearch: Bool? = nil, fileIds: [Int]? = nil) async throws -> ChatResponse {
        var body: [String: Any] = ["provider": provider, "message": message]
        if let image { body["image"] = image }
        if let fileBase64 { body["file_base64"] = fileBase64 }
        if let fileMime { body["file_mime"] = fileMime }
        if let attachments { body["attachments"] = attachments }
        if let model { body["model"] = model }
        if let conversationId { body["conversation_id"] = conversationId }
        if let system { body["system"] = system }
        if let webSearch { body["web_search"] = webSearch }
        if let fileIds { body["file_ids"] = fileIds }
        return try decode(try await send("/chat", method: "POST", json: body))
    }
    func ensemble(providers: [String], message: String, judge: String?) async throws -> EnsembleResponse {
        var body: [String: Any] = ["providers": providers, "message": message]
        if let judge { body["judge"] = judge }
        return try decode(try await send("/chat/ensemble", method: "POST", json: body))
    }

    // ---- Lịch sử ----
    func conversations() async throws -> [Conversation] {
        try decode(try await send("/conversations"))
    }
    func conversation(_ id: Int) async throws -> ConversationDetail {
        try decode(try await send("/conversations/\(id)"))
    }
    func deleteConversation(_ id: Int) async throws -> MessageResponse {
        try decode(try await send("/conversations/\(id)", method: "DELETE"))
    }

    // ---- Admin (users, ban, password, plan, payments, errors, bank) ----
    func adminUsers() async throws -> [AdminUser] {
        try decode(try await send("/admin/users"))
    }
    func adminBan(_ uid: Int, banned: Bool) async throws -> MessageResponse {
        try decode(try await send("/admin/users/\(uid)/ban", method: "POST", json: ["banned": banned]))
    }
    func adminSetPassword(_ uid: Int, newPassword: String) async throws -> MessageResponse {
        try decode(try await send("/admin/users/\(uid)/password", method: "POST",
                                  json: ["new_password": newPassword]))
    }
    func adminSetPlan(_ uid: Int, plan: String) async throws -> MessageResponse {
        try decode(try await send("/admin/users/\(uid)/plan", method: "POST", json: ["plan": plan]))
    }
    func adminConfirmPayment(_ pid: Int) async throws -> MessageResponse {
        try decode(try await send("/admin/payments/\(pid)/confirm", method: "POST"))
    }
    func adminErrors() async throws -> [ErrorLog] {
        try decode(try await send("/admin/errors"))
    }
    func adminClearErrors() async throws -> MessageResponse {
        try decode(try await send("/admin/errors", method: "DELETE"))
    }
    func adminGetBank() async throws -> BankSettings {
        try decode(try await send("/admin/payment/settings"))
    }
    func adminSetBank(_ s: BankSettings) async throws -> MessageResponse {
        try decode(try await send("/admin/payment/settings", method: "POST", json: [
            "bank_code": s.bankCode, "bank_short": s.bankShort,
            "bank_account": s.bankAccount, "bank_name": s.bankName,
            "bank_webhook": s.bankWebhook, "bank_apikey": s.bankApikey
        ]))
    }

    // ---- Admin API keys (server-side) ----
    func adminSaveKey(provider: String, apiKey: String) async throws -> MessageResponse {
        try decode(try await send("/admin/keys", method: "POST",
                                  json: ["provider": provider, "api_key": apiKey]))
    }
    func adminListKeys() async throws -> [AdminKeyInfo] {
        try decode(try await send("/admin/keys"))
    }
    func adminDeleteKey(provider: String) async throws -> MessageResponse {
        try decode(try await send("/admin/keys/\(provider)", method: "DELETE"))
    }

    // ---- Admin thống kê ----
    func adminStats() async throws -> AdminStats {
        try decode(try await send("/admin/stats"))
    }

    // ---- File ----
    func listFiles(category: String?) async throws -> [FileItem] {
        var path = "/files"
        if let category, category != "all" { path += "?category=\(category)" }
        return try decode(try await send(path))
    }
    func uploadFile(name: String, category: String, dataBase64: String) async throws -> UploadResponse {
        try decode(try await send("/files", method: "POST",
                                  json: ["name": name, "category": category, "data_base64": dataBase64]))
    }
    func uploadFileRaw(name: String, category: String, fileURL: URL) async throws -> UploadResponse {
        var path = "/files/upload?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"
        if !category.isEmpty {
            path += "&category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)"
        }
        var req = URLRequest(url: try makeURL(path))
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        let ext = fileURL.pathExtension.lowercased()
        let mime = mimeType(for: ext)
        req.setValue(mime, forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let (data, resp) = try await URLSession.shared.upload(for: req, fromFile: fileURL)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.message("Phản hồi không hợp lệ.")
        }
        if !(200..<300).contains(http.statusCode) {
            var detail = "Lỗi tải lên (\(http.statusCode))."
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let d = obj["detail"] as? String { detail = d }
            throw APIError.message(detail)
        }
        return try decode(data)
    }
    func downloadFile(_ id: Int) async throws -> FileDetail {
        try decode(try await send("/files/\(id)"))
    }
    func downloadFileRaw(_ id: Int) async throws -> (URL, String) {
        var req = URLRequest(url: try makeURL("/files/\(id)/download"))
        req.httpMethod = "GET"
        req.timeoutInterval = 600
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let (tempURL, resp) = try await URLSession.shared.download(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.message("Phản hồi không hợp lệ.")
        }
        if !(200..<300).contains(http.statusCode) {
            throw APIError.message("Lỗi tải xuống (\(http.statusCode)).")
        }
        
        var filename = "file"
        if let disp = http.value(forHTTPHeaderField: "Content-Disposition") {
            if let range = disp.range(of: "filename=\"") {
                let start = range.upperBound
                if let endRange = disp.range(of: "\"", range: start..<disp.endIndex) {
                    filename = String(disp[start..<endRange.lowerBound])
                }
            } else if let range = disp.range(of: "filename=") {
                let start = range.upperBound
                filename = String(disp[start...])
            }
        }
        return (tempURL, filename)
    }
    func deleteFile(_ id: Int) async throws -> MessageResponse {
        try decode(try await send("/files/\(id)", method: "DELETE"))
    }
    private func mimeType(for ext: String) -> String {
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        case "txt": return "text/plain"
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }

    // ---- Giọng nói ----
    func transcribe(provider: String, audioBase64: String, mime: String) async throws -> VoiceResponse {
        try decode(try await send("/voice/transcribe", method: "POST",
                                  json: ["provider": provider, "audio_base64": audioBase64, "mime": mime]))
    }
    
    // ---- Giọng nói nâng cao (TTS) ----
    func synthesizeSpeech(text: String, provider: String) async throws -> String {
        let body: [String: Any] = ["text": text, "provider": provider]
        let data = try await send("/voice/synthesize", method: "POST", json: body)
        struct TTSResponse: Decodable { let audioBase64: String }
        let res: TTSResponse = try decode(data)
        return res.audioBase64
    }

    // ---- Sinh ảnh AI ----
    struct ImageGenResponse: Decodable {
        let id: Int
        let name: String
        let dataBase64: String
        let mime: String
    }
    func generateImage(prompt: String, provider: String) async throws -> ImageGenResponse {
        let body: [String: Any] = ["prompt": prompt, "provider": provider]
        return try decode(try await send("/image/generate", method: "POST", json: body))
    }

    // ---- Chạy code / Sandbox ----
    func runPython(code: String, stdin: String? = nil) async throws -> CodeRunResult {
        var body: [String: Any] = ["code": code]
        if let stdin { body["stdin"] = stdin }
        return try decode(try await send("/run/python", method: "POST", json: body))
    }
    func runCode(language: String, code: String, stdin: String? = nil) async throws -> CodeRunResult {
        var body: [String: Any] = ["code": code, "language": language]
        if let stdin { body["stdin"] = stdin }
        return try decode(try await send("/run/code", method: "POST", json: body))
    }
    func runTestFile(fileId: Int, args: String? = nil) async throws -> FileRunResult {
        var body: [String: Any] = ["file_id": fileId]
        if let args { body["args"] = args }
        return try decode(try await send("/run/test", method: "POST", json: body))
    }

    // ---- AI lập trình (review/debug/explain/convert/test/optimize/document/security) ----
    func codeAI(provider: String, code: String, language: String?, task: String,
                targetLang: String? = nil, model: String? = nil) async throws -> CodeAIResult {
        var body: [String: Any] = ["provider": provider, "code": code, "task": task]
        if let language { body["language"] = language }
        if let targetLang { body["target_lang"] = targetLang }
        if let model { body["model"] = model }
        return try decode(try await send("/code/ai", method: "POST", json: body))
    }

    // ---- Credits & Thanh toán ----
    func myCredits() async throws -> CreditsResponse {
        try decode(try await send("/me/credits"))
    }
    func paymentPackages() async throws -> [PaymentPackage] {
        try decode(try await send("/payment/packages", auth: false))
    }
    func createPayment(package: String, amount: Int) async throws -> PaymentCreateResponse {
        try decode(try await send("/payment/create", method: "POST",
                                  json: ["package": package, "amount": amount]))
    }
    func paymentHistory() async throws -> [PaymentRecord] {
        try decode(try await send("/payment/history"))
    }

    // ---- Prompt mẫu ----
    func listPrompts() async throws -> [PromptTemplate] {
        try decode(try await send("/prompts"))
    }
    func createPrompt(title: String, content: String, category: String?, isPublic: Bool) async throws -> MessageResponse {
        var body: [String: Any] = ["title": title, "content": content, "is_public": isPublic]
        if let category { body["category"] = category }
        return try decode(try await send("/prompts", method: "POST", json: body))
    }
    func deletePrompt(_ id: Int) async throws -> MessageResponse {
        try decode(try await send("/prompts/\(id)", method: "DELETE"))
    }

    // ---- Chia sẻ hội thoại ----
    func shareConversation(_ id: Int) async throws -> ShareResponse {
        try decode(try await send("/conversations/\(id)/share", method: "POST"))
    }

    // ---- Xuất hội thoại (raw data) ----
    func exportConversation(_ id: Int, format: String) async throws -> Data {
        try await send("/conversations/\(id)/export?format=\(format)")
    }

    // ---- Tìm kiếm tin nhắn ----
    func searchMessages(query: String) async throws -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try decode(try await send("/messages/search?q=\(encoded)"))
    }

    // ---- Tin nhắn yêu thích ----
    func listFavorites() async throws -> [FavoriteMessage] {
        try decode(try await send("/favorites"))
    }
    func addFavorite(content: String, conversationId: Int?, provider: String?) async throws -> MessageResponse {
        var body: [String: Any] = ["content": content]
        if let conversationId { body["conversation_id"] = conversationId }
        if let provider { body["provider"] = provider }
        return try decode(try await send("/favorites", method: "POST", json: body))
    }
    func removeFavorite(_ id: Int) async throws -> MessageResponse {
        try decode(try await send("/favorites/\(id)", method: "DELETE"))
    }

    // ---- Ghim hội thoại ----
    func pinConversation(_ id: Int) async throws -> MessageResponse {
        try decode(try await send("/conversations/\(id)/pin", method: "POST"))
    }

    // ---- Zip code ----
    func zipCode(text: String) async throws -> ZipResponse {
        try decode(try await send("/code/zip", method: "POST", json: ["text": text]))
    }

    // ---- Phân hệ mạng xã hội ----
    func socialGenerate(topic: String, platform: String, tone: String, mode: String, provider: String) async throws -> SocialGenResponse {
        let body: [String: Any] = [
            "topic": topic,
            "platform": platform,
            "tone": tone,
            "mode": mode,
            "provider": provider
        ]
        return try decode(try await send("/social/generator", method: "POST", json: body))
    }

    func socialDownload(url: String) async throws -> SocialDownloadResponse {
        let body: [String: Any] = ["url": url]
        return try decode(try await send("/social/download", method: "POST", json: body))
    }

    func getFacebookStreamKey(accessToken: String) async throws -> StreamKeyResponse {
        let body: [String: Any] = ["access_token": accessToken]
        return try decode(try await send("/social/stream/facebook", method: "POST", json: body))
    }

    func getTikTokStreamKey(cookies: String) async throws -> StreamKeyResponse {
        let body: [String: Any] = ["cookies": cookies]
        return try decode(try await send("/social/stream/tiktok", method: "POST", json: body))
    }

    // ---- TikTok Live: đọc bình luận tự động (như TikFinity) ----
    func tiktokLiveConnect(username: String) async throws -> TikTokLiveStatus {
        try decode(try await send("/social/tiktok/live/connect", method: "POST",
                                  json: ["username": username]))
    }
    func tiktokLiveEvents(username: String, after: Int) async throws -> TikTokLiveEventsResponse {
        let q = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        return try decode(try await send("/social/tiktok/live/events?username=\(q)&after=\(after)"))
    }
    func tiktokLiveDisconnect(username: String) async throws {
        _ = try await send("/social/tiktok/live/disconnect", method: "POST",
                           json: ["username": username])
    }

    func encryptCode(code: String, language: String, level: String) async throws -> EncryptResponse {
        let body: [String: Any] = ["code": code, "language": language, "level": level]
        return try decode(try await send("/code/encrypt", method: "POST", json: body))
    }

    func analyzeBinary(fileURL: URL) async throws -> BinaryAnalysisResponse {
        var req = URLRequest(url: try makeURL("/code/analyze"))
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        let filename = fileURL.lastPathComponent
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.message("Phản hồi không hợp lệ.")
        }
        if !(200..<300).contains(http.statusCode) {
            throw APIError.message("Lỗi phân tích (\(http.statusCode)).")
        }
        return try decode(data)
    }

    func translateAsm(input: String, mode: String, arch: String, provider: String) async throws -> AsmResponse {
        let body: [String: Any] = [
            "input": input,
            "mode": mode,
            "arch": arch,
            "provider": provider
        ]
        return try decode(try await send("/code/asm", method: "POST", json: body))
    }

    // ---- DevOps & DevOps Tools ----
    func runSSH(host: String, user: String, pass: String, cmd: String) async throws -> SSHResultResponse {
        let body: [String: Any] = [
            "host": host,
            "username": user,
            "password": pass,
            "command": cmd
        ]
        return try decode(try await send("/run/ssh", method: "POST", json: body))
    }

    func runHTTP(url: String, method: String, headers: [String: String], body: String) async throws -> HTTPTestResponse {
        let body: [String: Any] = [
            "url": url,
            "method": method,
            "headers": headers,
            "body": body
        ]
        return try decode(try await send("/run/http", method: "POST", json: body))
    }

    func runSQL(query: String) async throws -> SQLResultResponse {
        let body: [String: Any] = [
            "query": query
        ]
        return try decode(try await send("/run/sql", method: "POST", json: body))
    }

    func cleanupDatabase(days: Int) async throws -> CleanupResponse {
        let body: [String: Any] = ["days": days]
        return try decode(try await send("/db/cleanup", method: "POST", json: body))
    }

    // ---- Bạn bè & Tin nhắn trực tiếp (User-to-User) ----
    func searchUsers(query: String) async throws -> [UserSearchResult] {
        try decode(try await send("/users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"))
    }

    func sendFriendRequest(friendId: Int) async throws -> MessageResponse {
        try decode(try await send("/friends/request", method: "POST", json: ["friend_id": friendId]))
    }

    func listFriendRequests() async throws -> [FriendRequestItem] {
        try decode(try await send("/friends/requests"))
    }

    func respondToFriendRequest(requestId: Int, action: String) async throws -> MessageResponse {
        try decode(try await send("/friends/respond", method: "POST", json: ["request_id": requestId, "action": action]))
    }

    func listFriends() async throws -> [FriendItem] {
        try decode(try await send("/friends"))
    }

    func getDirectMessages(friendId: Int) async throws -> [DirectMessageItem] {
        try decode(try await send("/direct_messages/\(friendId)"))
    }

    func sendDirectMessage(receiverId: Int, content: String) async throws -> MessageResponse {
        try decode(try await send("/direct_messages", method: "POST", json: ["receiver_id": receiverId, "content": content]))
    }

    // ---- Proxy mạng (THÊM MỚI) ----
    func proxyList() async throws -> ProxyListResponse {
        try decode(try await send("/proxy/list"))
    }
    func proxyAdd(label: String?, scheme: String, host: String, port: Int,
                  username: String?, password: String?, region: String?,
                  source: String) async throws -> ProxyAddResponse {
        var body: [String: Any] = ["scheme": scheme, "host": host, "port": port, "source": source]
        if let label, !label.isEmpty { body["label"] = label }
        if let username, !username.isEmpty { body["username"] = username }
        if let password, !password.isEmpty { body["password"] = password }
        if let region, !region.isEmpty { body["region"] = region }
        return try decode(try await send("/proxy/add", method: "POST", json: body))
    }
    func proxyImport(text: String, scheme: String, region: String?,
                     source: String) async throws -> ProxyImportResponse {
        var body: [String: Any] = ["text": text, "scheme": scheme, "source": source]
        if let region, !region.isEmpty { body["region"] = region }
        return try decode(try await send("/proxy/import", method: "POST", json: body))
    }
    func proxyDelete(id: Int) async throws -> MessageResponse {
        try decode(try await send("/proxy/\(id)", method: "DELETE"))
    }
    func proxySelect(id: Int?) async throws -> ProxySelectResponse {
        var body: [String: Any] = [:]
        if let id { body["id"] = id }
        return try decode(try await send("/proxy/select", method: "POST", json: body))
    }
    func proxyTest(id: Int) async throws -> ProxyTestResponse {
        try decode(try await send("/proxy/test", method: "POST", json: ["id": id]))
    }
    func proxyVpsSpawn(count: Int) async throws -> ProxyVpsSpawnResponse {
        try decode(try await send("/proxy/vps/spawn", method: "POST", json: ["count": count]))
    }
    func proxyVpsDespawn(port: Int) async throws -> MessageResponse {
        try decode(try await send("/proxy/vps/despawn", method: "POST", json: ["port": port]))
    }
}

