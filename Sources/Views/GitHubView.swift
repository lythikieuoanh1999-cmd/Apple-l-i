import SwiftUI
import UniformTypeIdentifiers

// ======================== GitHub — đăng nhập & tải file lên repo (kiểu app "Source") ========================

struct GHUser: Decodable {
    let login: String
    let avatar_url: String?
    let name: String?
}

struct GHRepo: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let full_name: String
    let `private`: Bool
    let default_branch: String?
    let html_url: String?
}

enum GitHubError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? {
        switch self {
        case .http(let c, let m):
            if c == 401 { return "Token sai hoặc hết hạn (401). Tạo token mới với quyền 'repo'." }
            return "GitHub lỗi \(c): \(m.prefix(180))"
        }
    }
}

final class GitHubAPI {
    let token: String
    init(token: String) { self.token = token }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let urlStr = path.hasPrefix("http") ? path : "https://api.github.com" + path
        guard let url = URL(string: urlStr) else { throw GitHubError.http(0, "URL sai") }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        r.setValue("KENIOS-App", forHTTPHeaderField: "User-Agent")
        if let body {
            r.httpBody = body
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        r.timeoutInterval = 60
        let (data, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw GitHubError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    func me() async throws -> GHUser {
        try JSONDecoder().decode(GHUser.self, from: request("/user"))
    }
    func repos() async throws -> [GHRepo] {
        try JSONDecoder().decode([GHRepo].self,
            from: request("/user/repos?per_page=100&sort=updated&affiliation=owner"))
    }
    func createRepo(name: String, isPrivate: Bool) async throws -> GHRepo {
        let body = try JSONSerialization.data(withJSONObject: [
            "name": name, "private": isPrivate, "auto_init": true])
        return try JSONDecoder().decode(GHRepo.self,
            from: request("/user/repos", method: "POST", body: body))
    }
    // Lấy sha nếu file đã tồn tại (để cập nhật thay vì lỗi)
    func existingSha(fullName: String, path: String, branch: String) async -> String? {
        let p = "/repos/\(fullName)/contents/\(path)?ref=\(branch)"
        guard let data = try? await request(p) else { return nil }
        struct C: Decodable { let sha: String }
        return (try? JSONDecoder().decode(C.self, from: data))?.sha
    }
    func uploadFile(fullName: String, path: String, contentBase64: String,
                    message: String, branch: String, sha: String?) async throws {
        var obj: [String: Any] = ["message": message, "content": contentBase64, "branch": branch]
        if let sha { obj["sha"] = sha }
        let body = try JSONSerialization.data(withJSONObject: obj)
        _ = try await request("/repos/\(fullName)/contents/\(path)", method: "PUT", body: body)
    }
}

struct GitHubView: View {
    @AppStorage("github_token") private var token = ""
    @State private var user: GHUser?
    @State private var repos: [GHRepo] = []
    @State private var loading = false
    @State private var error: String?

    // login fields
    @State private var tokenInput = ""
    @State private var showTokenBrowser = false

    // create repo
    @State private var showCreate = false
    @State private var newRepoName = ""
    @State private var newRepoPrivate = true

    var body: some View {
        NavigationStack {
            Group {
                if user == nil {
                    loginView
                } else {
                    repoListView
                }
            }
            .navigationTitle("GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if !token.isEmpty && user == nil { await validate(token) }
            }
            .sheet(isPresented: $showTokenBrowser) {
                NavigationStack {
                    TokenBrowser()
                        .navigationTitle("Tạo Token GitHub")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) {
                            Button("Xong") { showTokenBrowser = false }
                        } }
                }
            }
        }
    }

    // MARK: - Đăng nhập
    private var loginView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                KHeroHeader(icon: "chevron.left.forwardslash.chevron.right",
                            title: "GitHub",
                            subtitle: "Đăng nhập để tải file / mã nguồn lên repo của bạn")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Cách đăng nhập").font(.headline)
                    Label("Bấm \"Mở GitHub & tạo token\" — đăng nhập tài khoản GitHub ngay trong app.", systemImage: "1.circle.fill")
                    Label("Ở trang token, chọn quyền \"repo\" rồi bấm Generate, copy token.", systemImage: "2.circle.fill")
                    Label("Quay lại đây, dán token vào ô dưới và bấm Đăng nhập.", systemImage: "3.circle.fill")
                }
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .kCard(16)

                Button {
                    showTokenBrowser = true
                } label: {
                    Label("Mở GitHub & tạo token", systemImage: "safari.fill")
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Access Token").font(.caption).foregroundStyle(.secondary)
                    SecureField("ghp_xxxxxxxx hoặc github_pat_xxxx", text: $tokenInput)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).kCard(12)
                }

                Button {
                    Task { await validate(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)) }
                } label: {
                    HStack {
                        if loading { ProgressView().tint(.white) }
                        Text(loading ? "Đang kiểm tra..." : "Đăng nhập")
                    }
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(tokenInput.isEmpty || loading ? Color.gray : Theme.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(tokenInput.isEmpty || loading)

                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .padding()
        }
    }

    // MARK: - Danh sách repo
    private var repoListView: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: user?.avatar_url ?? "")) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill").resizable()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 48, height: 48).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.name ?? user?.login ?? "—").font(.headline)
                        Text("@\(user?.login ?? "")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Đăng xuất", role: .destructive) { logout() }
                        .font(.caption)
                }
            }

            Section {
                Button {
                    newRepoName = ""; newRepoPrivate = true; showCreate = true
                } label: {
                    Label("Tạo repo mới", systemImage: "plus.circle.fill")
                }
            }

            Section("Repo của bạn (\(repos.count))") {
                if loading && repos.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                ForEach(repos) { repo in
                    NavigationLink {
                        GitHubRepoView(api: GitHubAPI(token: token), repo: repo)
                    } label: {
                        HStack {
                            Image(systemName: repo.`private` ? "lock.fill" : "book.closed.fill")
                                .foregroundStyle(repo.`private` ? Theme.gold : Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.name).font(.subheadline.bold())
                                Text(repo.full_name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let error { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .refreshable { await loadRepos() }
        .alert("Tạo repo mới", isPresented: $showCreate) {
            TextField("Tên repo (vd: my-app)", text: $newRepoName)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Tạo") { Task { await createRepo() } }
            Button("Huỷ", role: .cancel) { }
        } message: {
            Text("Repo sẽ ở chế độ riêng tư. Bạn có thể tải file lên ngay sau khi tạo.")
        }
    }

    // MARK: - Actions
    private func validate(_ tk: String) async {
        guard !tk.isEmpty else { return }
        loading = true; error = nil
        do {
            let api = GitHubAPI(token: tk)
            let u = try await api.me()
            token = tk; tokenInput = ""
            user = u
            await loadRepos()
        } catch {
            self.error = error.localizedDescription
            user = nil
        }
        loading = false
    }
    private func loadRepos() async {
        guard !token.isEmpty else { return }
        loading = true
        do { repos = try await GitHubAPI(token: token).repos() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    private func createRepo() async {
        let name = newRepoName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        loading = true; error = nil
        do {
            _ = try await GitHubAPI(token: token).createRepo(name: name, isPrivate: newRepoPrivate)
            await loadRepos()
        } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func logout() {
        token = ""; user = nil; repos = []; error = nil
    }
}

// MARK: - Màn hình repo: tải file lên
struct GitHubRepoView: View {
    let api: GitHubAPI
    let repo: GHRepo

    @State private var folder = ""
    @State private var showImporter = false
    @State private var uploading = false
    @State private var log: [String] = []
    @State private var error: String?

    private var branch: String { repo.default_branch ?? "main" }

    var body: some View {
        Form {
            Section("Đích tải lên") {
                LabeledContent("Repo", value: repo.full_name)
                LabeledContent("Nhánh", value: branch)
                TextField("Thư mục (để trống = gốc repo)", text: $folder)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    HStack {
                        if uploading { ProgressView().padding(.trailing, 4) }
                        Label(uploading ? "Đang tải lên..." : "Chọn file để tải lên",
                              systemImage: "arrow.up.doc.fill")
                    }
                }
                .disabled(uploading)
            } footer: {
                Text("Chọn 1 hoặc nhiều file (ảnh, mã nguồn, tài liệu...). File sẽ được commit thẳng vào repo qua GitHub API.")
            }

            if !log.isEmpty {
                Section("Kết quả") {
                    ForEach(log, id: \.self) { line in
                        Text(line).font(.caption).foregroundStyle(line.contains("✓") ? .green : .red)
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(.caption) }

            Section {
                if let urlStr = repo.html_url, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label("Mở repo trên GitHub", systemImage: "safari")
                    }
                }
            }
        }
        .navigationTitle(repo.name)
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { Task { await upload(urls) } }
        }
    }

    private func upload(_ urls: [URL]) async {
        uploading = true; error = nil; log = []
        let dir = folder.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let name = url.lastPathComponent
            let path = dir.isEmpty ? name : "\(dir)/\(name)"
            do {
                let data = try Data(contentsOf: url)
                let b64 = data.base64EncodedString()
                let sha = await api.existingSha(fullName: repo.full_name, path: path, branch: branch)
                try await api.uploadFile(fullName: repo.full_name, path: path,
                                         contentBase64: b64,
                                         message: "Tải lên \(name) từ KENIOS",
                                         branch: branch, sha: sha)
                log.append("✓ \(path) (\(humanSize(data.count)))")
            } catch {
                log.append("✗ \(name): \(error.localizedDescription)")
            }
        }
        uploading = false
    }
}

// Trình duyệt mở trang tạo token GitHub (đăng nhập ngay trong app)
struct TokenBrowser: View {
    @StateObject private var model = BrowserModel()
    var body: some View {
        BrowserWebView(model: model,
                       home: "https://github.com/settings/tokens/new?scopes=repo&description=KENIOS")
            .ignoresSafeArea(edges: .bottom)
    }
}
