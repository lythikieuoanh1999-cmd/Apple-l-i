import SwiftUI
import AVKit
import PhotosUI

// ======================== Video feed — "TikTok của riêng app" ========================
struct VideoFeedView: View {
    @EnvironmentObject var store: AppStore
    @State private var posts: [PostItem] = []
    @State private var loading = false
    @State private var error: String?

    // Đăng bài
    @State private var picker: PhotosPickerItem?
    @State private var caption = ""
    @State private var posting = false
    @State private var showCompose = false

    // Phát video
    @State private var playURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    KHeroHeader(icon: "play.rectangle.on.rectangle.fill",
                                title: "Video KENIOS",
                                subtitle: "Đăng & xem video ngay trong app của bạn")

                    Button { showCompose = true } label: {
                        Label("Đăng video mới", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Theme.accent).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let error { Text(error).foregroundStyle(.red).font(.caption) }
                    if posts.isEmpty && !loading {
                        Text("Chưa có video nào. Hãy đăng video đầu tiên!")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.top, 30)
                    }

                    ForEach(posts) { p in postCard(p) }
                }
                .padding()
            }
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) } }
            .task { await load() }
            .refreshable { await load() }
            .fullScreenCover(item: Binding(
                get: { playURL.map { PlayURL(url: $0) } },
                set: { playURL = $0?.url })) { item in
                FeedPlayer(url: item.url)
            }
            .sheet(isPresented: $showCompose) { composeSheet }
        }
    }

    private func postCard(_ p: PostItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.username).font(.subheadline.bold())
                    if let pid = p.publicId { Text("ID: \(pid)").font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                if p.username == store.username || store.isAdmin {
                    Button(role: .destructive) { Task { await delete(p) } } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                }
            }
            Button { Task { await play(p) } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardNavy)
                        .frame(height: 200)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 54)).foregroundStyle(.white.opacity(0.92))
                }
            }
            if let cap = p.caption, !cap.isEmpty {
                Text(cap).font(.subheadline)
            }
            HStack(spacing: 16) {
                Button { Task { await like(p) } } label: {
                    Label("\(p.likes)", systemImage: p.liked ? "heart.fill" : "heart")
                        .foregroundStyle(p.liked ? .red : .secondary)
                }
                Spacer()
            }.font(.subheadline)
        }
        .padding()
        .kCard(18)
    }

    private var composeSheet: some View {
        NavigationStack {
            Form {
                Section("Chọn video") {
                    PhotosPicker(selection: $picker, matching: .videos) {
                        Label(picker == nil ? "Chọn video từ máy" : "Đã chọn — đổi video",
                              systemImage: "film")
                    }
                }
                Section("Mô tả") {
                    TextField("Viết mô tả cho video...", text: $caption, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Button {
                        Task { await submitPost() }
                    } label: {
                        HStack {
                            if posting { ProgressView().padding(.trailing, 4) }
                            Text(posting ? "Đang đăng..." : "Đăng video")
                        }
                    }.disabled(picker == nil || posting)
                }
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("Đăng video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showCompose = false } } }
        }
    }

    // MARK: - Actions
    private func load() async {
        loading = true; error = nil
        do { posts = try await store.api.getFeed() }
        catch { self.error = error.localizedDescription }
        loading = false
    }

    private func play(_ p: PostItem) async {
        do { playURL = try await store.api.downloadPostVideo(p.id) }
        catch { self.error = error.localizedDescription }
    }

    private func like(_ p: PostItem) async {
        do {
            let r = try await store.api.likePost(p.id)
            if let idx = posts.firstIndex(where: { $0.id == p.id }) {
                posts[idx] = PostItem(id: p.id, caption: p.caption, likes: r.likes,
                                      createdAt: p.createdAt, fileId: p.fileId,
                                      username: p.username, publicId: p.publicId,
                                      name: p.name, mime: p.mime, liked: r.liked)
            }
        } catch { self.error = error.localizedDescription }
    }

    private func delete(_ p: PostItem) async {
        do { _ = try await store.api.deletePost(p.id); posts.removeAll { $0.id == p.id } }
        catch { self.error = error.localizedDescription }
    }

    private func submitPost() async {
        guard let picker else { return }
        posting = true; error = nil
        do {
            guard let movie = try await picker.loadTransferable(type: EditMovie.self) else {
                error = "Không đọc được video."; posting = false; return
            }
            let up = try await store.api.uploadFileRaw(
                name: "video_\(Int(Date().timeIntervalSince1970)).mp4",
                category: "video", fileURL: movie.url)
            _ = try await store.api.createPost(fileId: up.id, caption: caption)
            caption = ""; self.picker = nil; showCompose = false
            await load()
        } catch { self.error = error.localizedDescription }
        posting = false
    }
}

private struct PlayURL: Identifiable { let url: URL; var id: String { url.absoluteString } }

struct FeedPlayer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Đóng") { dismiss() } } }
        }
    }
}
