import SwiftUI

// ======================== Khám phá — lưới nút đẹp, gom các tính năng phụ ========================
enum HubDest: String, Identifiable {
    case library, read, fun, games, tools, github, settings, admin
    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Thư viện"
        case .read:    return "Đọc (TTS)"
        case .fun:     return "Giải trí"
        case .games:   return "Trò chơi"
        case .tools:   return "Công cụ"
        case .github:  return "GitHub"
        case .settings:return "Cài đặt"
        case .admin:   return "Quản trị"
        }
    }
    var subtitle: String {
        switch self {
        case .library: return "Video · file đã tải"
        case .read:    return "Đọc văn bản · giọng mới"
        case .fun:     return "Phim · nhạc · web"
        case .games:   return "Chơi game trong app"
        case .tools:   return "Ảnh · tin tức · tiện ích"
        case .github:  return "Tải/xoá file lên repo"
        case .settings:return "Tài khoản · giao diện"
        case .admin:   return "Quản lý người dùng"
        }
    }
    var icon: String {
        switch self {
        case .library: return "clock.arrow.circlepath"
        case .read:    return "speaker.wave.2.fill"
        case .fun:     return "play.tv.fill"
        case .games:   return "gamecontroller.fill"
        case .tools:   return "square.grid.2x2.fill"
        case .github:  return "chevron.left.forwardslash.chevron.right"
        case .settings:return "gearshape.fill"
        case .admin:   return "person.2.badge.gearshape.fill"
        }
    }
    var colors: [Color] {
        switch self {
        case .library: return [Color(red: 0.0, green: 0.6, blue: 0.95), Color(red: 0.0, green: 0.4, blue: 0.85)]
        case .read:    return [Color(red: 0.0, green: 0.78, blue: 0.7), Color(red: 0.0, green: 0.55, blue: 0.7)]
        case .fun:     return [Color(red: 0.95, green: 0.3, blue: 0.5), Color(red: 0.75, green: 0.2, blue: 0.55)]
        case .games:   return [Color(red: 0.55, green: 0.4, blue: 0.95), Color(red: 0.35, green: 0.3, blue: 0.9)]
        case .tools:   return [Color(red: 0.95, green: 0.6, blue: 0.1), Color(red: 0.9, green: 0.4, blue: 0.1)]
        case .github:  return [Color(red: 0.2, green: 0.22, blue: 0.28), Color(red: 0.1, green: 0.11, blue: 0.15)]
        case .settings:return [Color(red: 0.4, green: 0.45, blue: 0.55), Color(red: 0.25, green: 0.3, blue: 0.4)]
        case .admin:   return [Color(red: 1.0, green: 0.78, blue: 0.0), Color(red: 0.9, green: 0.55, blue: 0.0)]
        }
    }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct ExploreHubView: View {
    @EnvironmentObject var store: AppStore
    @State private var dest: HubDest?

    private var items: [HubDest] {
        var a: [HubDest] = [.library, .read, .fun, .games, .tools, .github, .settings]
        if store.isAdmin { a.append(.admin) }
        return a
    }
    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    KHeroHeader(icon: "square.grid.2x2.fill",
                                title: "Khám phá",
                                subtitle: "Tất cả tính năng của KENIOS")

                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(items) { it in
                            Button { dest = it } label: { card(it) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Khám phá")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) } }
            .sheet(item: $dest) { d in destView(d) }
        }
    }

    private func card(_ it: HubDest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: it.icon)
                .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(it.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: it.colors.first!.opacity(0.4), radius: 8, x: 0, y: 4)
            Text(it.title).font(.headline).foregroundStyle(.primary)
            Text(it.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .kCard(18)
    }

    @ViewBuilder
    private func destView(_ d: HubDest) -> some View {
        switch d {
        case .library:  LibraryView()
        case .read:     TTSView()
        case .fun:      MediaWebView()
        case .games:    GameZoneView()
        case .tools:    CreatorToolsView()
        case .github:   GitHubView()
        case .settings: SettingsView()
        case .admin:    AdminView()
        }
    }
}
