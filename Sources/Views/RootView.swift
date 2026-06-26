import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if !store.isLoggedIn {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(store.isDark ? .dark : .light)
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
            SettingsView()
                .tabItem { Label("Cài đặt", systemImage: "gearshape.fill") }
                .tag(5)
            if store.isAdmin {
                AdminView()
                    .tabItem { Label("Quản trị", systemImage: "person.2.badge.gearshape.fill") }
                    .tag(6)
            }
        }
        .onAppear { if store.tab == 0 || store.tab == 1 || store.tab == 10 { store.tab = 2 } }
        .task {
            // Giảm tải khởi động (đã bỏ Chat/AI key) → đỡ "đứng" khi mở app
            await store.loadProviders()
            await store.refreshCredits()
        }
    }
}
