import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if !store.isLoggedIn {
                LoginView()
            } else {
                MainTabView()
                    .overlay {
                        // Bảo trì: khoá app người dùng (admin vẫn dùng được)
                        if store.maintenance && !store.isAdmin {
                            MaintenanceOverlay(message: store.maintenanceMessage)
                        }
                    }
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(store.isDark ? .dark : .light)
    }
}

struct MaintenanceOverlay: View {
    let message: String
    var body: some View {
        ZStack {
            Theme.bgNavy.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 60)).foregroundStyle(Theme.gold)
                RainbowText(text: "KENIOS", size: 38)
                Text("Đang nâng cấp phiên bản")
                    .font(.title3.bold()).foregroundStyle(.white)
                Text(message.isEmpty
                     ? "Ứng dụng đang nâng cấp phiên bản. Vui lòng đợi trong giây lát."
                     : message)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
                ProgressView().tint(.white)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView(selection: $store.tab) {
            SocialMediaToolsView()
                .tabItem { Label("Mạng xã hội", systemImage: "globe.badge.ellipsis") }
                .tag(2)
            LibraryView()
                .tabItem { Label("Thư viện", systemImage: "clock.arrow.circlepath") }
                .tag(3)
            FriendsView()
                .tabItem { Label("Bạn bè", systemImage: "person.2.fill") }
                .tag(4)
            TTSView() // module đọc văn bản (TTS)
                .tabItem { Label("Đọc", systemImage: "speaker.wave.2.fill") }
                .tag(7)
            MediaWebView() // xem phim · nghe nhạc qua web
                .tabItem { Label("Giải trí", systemImage: "play.tv.fill") }
                .tag(8)
            GameZoneView() // khu trò chơi riêng
                .tabItem { Label("Trò chơi", systemImage: "gamecontroller.fill") }
                .tag(12)
            CreatorToolsView() // bộ công cụ tiện ích cho nội dung
                .tabItem { Label("Công cụ", systemImage: "square.grid.2x2.fill") }
                .tag(11)
            GitHubView() // đăng nhập GitHub · tải file lên repo
                .tabItem { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                .tag(13)
            VideoFeedView() // TikTok của riêng app
                .tabItem { Label("Video", systemImage: "play.rectangle.on.rectangle.fill") }
                .tag(14)
            SettingsView()
                .tabItem { Label("Cài đặt", systemImage: "gearshape.fill") }
                .tag(5)
            if store.isAdmin {
                AdminView()
                    .tabItem { Label("Quản trị", systemImage: "person.2.badge.gearshape.fill") }
                    .tag(6)
            }
        }
        .onAppear {
            if store.tab == 0 || store.tab == 1 || store.tab == 10 { store.tab = 2 }
            WelcomeVoice.playOnce()   // giọng chào mừng khi vào app
        }
        .task {
            // Giảm tải khởi động (đã bỏ Chat/AI key) → đỡ "đứng" khi mở app
            await store.loadProviders()
            await store.refreshCredits()
            await store.refreshMe()
            // Theo dõi bảo trì + gói theo chu kỳ
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                await store.refreshMe()
            }
        }
    }
}
