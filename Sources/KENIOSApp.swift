import SwiftUI

@main
struct KENIOSApp: App {
    @StateObject private var store = AppStore()

    init() {
        // ===== Giao diện tối kiểu Instagram: nền đen, chữ trắng =====
        let black = UIColor.black

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = black
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = black
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        // Nền đen cho MỌI danh sách/Form trên toàn app (đồng bộ kiểu Instagram)
        UITableView.appearance().backgroundColor = black
        UICollectionView.appearance().backgroundColor = black

        // Thanh công cụ bàn phím / toolbar tối
        let bar = UIToolbarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = black
        UIToolbar.appearance().standardAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)                // xanh Instagram
                .preferredColorScheme(.dark)        // nền tối mặc định
        }
    }
}
