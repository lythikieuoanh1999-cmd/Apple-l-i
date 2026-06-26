import SwiftUI
import AVKit

// ======================== Live — phòng live + bình luận như TikTok ========================
struct LiveView: View {
    @EnvironmentObject var store: AppStore
    @State private var rooms: [LiveRoom] = []
    @State private var loading = false
    @State private var error: String?

    // tạo phòng
    @State private var showCreate = false
    @State private var newTitle = ""
    @State private var newHLS = ""
    @State private var openRoom: LiveRoom?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    KHeroHeader(icon: "dot.radiowaves.left.and.right",
                                title: "Live",
                                subtitle: "Mở phòng live · bình luận thời gian thực")

                    Button { newTitle = ""; newHLS = ""; showCreate = true } label: {
                        Label("Mở phòng live", systemImage: "video.fill.badge.plus")
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color.red).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if loading { ProgressView().frame(maxWidth: .infinity) }
                    if let error { Text(error).foregroundStyle(.red).font(.caption) }
                    if rooms.isEmpty && !loading {
                        Text("Chưa có ai live. Hãy mở phòng đầu tiên!")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.top, 30)
                    }

                    ForEach(rooms) { r in
                        Button { openRoom = r } label: { roomCard(r) }
                            .buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showCreate) { createSheet }
            .fullScreenCover(item: $openRoom) { r in
                LiveRoomView(room: r)
            }
        }
    }

    private func roomCard(_ r: LiveRoom) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.heroGradient)
                    .frame(width: 64, height: 64)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.title ?? "Live").font(.subheadline.bold()).lineLimit(1)
                Text("@\(r.username)").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label("\(r.viewers)", systemImage: "eye.fill")
                    Label("\(r.likes)", systemImage: "heart.fill")
                }.font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("LIVE").font(.caption2.bold()).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.red).clipShape(Capsule())
        }
        .padding(10).kCard(14)
    }

    private var createSheet: some View {
        NavigationStack {
            Form {
                Section("Tiêu đề") {
                    TextField("VD: Giao lưu tối thứ 7", text: $newTitle)
                }
                Section("Link phát hình (HLS .m3u8 — tuỳ chọn)") {
                    TextField("http://IP-VPS:8080/hls/streamkey.m3u8", text: $newHLS)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Để trống nếu chỉ live bằng chữ. Dán link HLS nếu bạn phát hình qua OBS/app RTMP về máy chủ.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Section {
                    Button("Bắt đầu live") { Task { await create() } }
                }
            }
            .navigationTitle("Mở phòng live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showCreate = false } } }
        }
    }

    private func load() async {
        loading = true; error = nil
        do { rooms = try await store.api.liveRooms() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    private func create() async {
        do {
            let r = try await store.api.liveCreate(title: newTitle, hlsUrl: newHLS)
            showCreate = false
            await load()
            // mở phòng vừa tạo
            if let room = try? await store.api.liveInfo(r.id) { openRoom = room }
        } catch { self.error = error.localizedDescription }
    }
}

// ======================== Phòng live (xem + bình luận) ========================
struct LiveRoomView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let room: LiveRoom

    @State private var comments: [LiveComment] = []
    @State private var lastId = 0
    @State private var input = ""
    @State private var likes = 0
    @State private var viewers = 0
    @State private var info: LiveRoom?
    @State private var player: AVPlayer?

    private var isHost: Bool { room.username == store.username }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Khu phát hình
                ZStack {
                    if let player {
                        VideoPlayer(player: player).aspectRatio(contentMode: .fit)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 44)).foregroundStyle(.white.opacity(0.8))
                            Text("Phòng live bằng bình luận")
                                .foregroundStyle(.white.opacity(0.85)).font(.subheadline)
                            Text("Chủ phòng có thể phát hình qua OBS/app RTMP (dán link HLS khi mở phòng).")
                                .font(.caption2).foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center).padding(.horizontal, 30)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bình luận
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(comments) { c in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(c.username ?? "ẩn danh").font(.caption.bold())
                                        .foregroundStyle(Theme.gold)
                                    Text(c.content).font(.caption).foregroundStyle(.white)
                                }
                                .id(c.id)
                            }
                        }.padding(.horizontal)
                    }
                    .frame(height: 180)
                    .onChange(of: comments.count) { _ in
                        if let last = comments.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }

                // Nhập bình luận + tim
                HStack(spacing: 8) {
                    TextField("Bình luận...", text: $input)
                        .padding(10).background(Color.white.opacity(0.15))
                        .foregroundStyle(.white).clipShape(Capsule())
                        .submitLabel(.send)
                        .onSubmit { Task { await send() } }
                    Button { Task { await send() } } label: {
                        Image(systemName: "paperplane.fill").foregroundStyle(.white)
                    }
                    Button { Task { await like() } } label: {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                    }
                }.padding()
            }

            // Thanh trên: thông tin + đóng
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Text("@\(room.username)").font(.caption.bold()).foregroundStyle(.white)
                        Label("\(viewers)", systemImage: "eye.fill").font(.caption2)
                        Label("\(likes)", systemImage: "heart.fill").font(.caption2)
                    }
                    .padding(8).background(.black.opacity(0.4)).clipShape(Capsule())
                    .foregroundStyle(.white)
                    Spacer()
                    Button { Task { await leave() } } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.white)
                    }
                }.padding()
                Spacer()
            }
        }
        .task { await start() }
        .onDisappear { player?.pause() }
    }

    private func start() async {
        likes = room.likes; viewers = room.viewers
        try? await store.api.liveJoin(room.id)
        if let i = try? await store.api.liveInfo(room.id) {
            info = i; likes = i.likes; viewers = i.viewers + 1
            if let h = i.hlsUrl, !h.isEmpty, let url = URL(string: h) {
                player = AVPlayer(url: url); player?.play()
            }
        }
        // vòng lặp nạp bình luận
        while !Task.isCancelled {
            if let cs = try? await store.api.liveComments(room.id, after: lastId), !cs.isEmpty {
                comments.append(contentsOf: cs)
                lastId = cs.last?.id ?? lastId
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }
    }
    private func send() async {
        let t = input.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        input = ""
        try? await store.api.liveComment(room.id, content: t)
        if let cs = try? await store.api.liveComments(room.id, after: lastId), !cs.isEmpty {
            comments.append(contentsOf: cs); lastId = cs.last?.id ?? lastId
        }
    }
    private func like() async {
        if let r = try? await store.api.liveLike(room.id) { likes = r.likes }
    }
    private func leave() async {
        if isHost { _ = try? await store.api.liveEnd(room.id) }  // chủ phòng đóng → kết thúc live
        dismiss()
    }
}
