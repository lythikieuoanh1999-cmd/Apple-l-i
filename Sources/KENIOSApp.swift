import SwiftUI

@main
struct KENIOSApp: App {
    @StateObject private var store = AppStore()

    init() {
        // ===== Giao diện navy cao cấp: nền xanh đen sâu, thẻ navy, chữ trắng =====
        let bg      = Theme.bgNavyUI     // nền sâu #0B0F1A
        let card    = Theme.cardNavyUI   // ô/thẻ #161A2B
        let tintCol = UIColor(red: 0.0, green: 0.58, blue: 0.96, alpha: 1)   // xanh accent

        // --- Thanh tab: mờ kính + viền tinh tế ---
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        tab.shadowColor = UIColor.white.withAlphaComponent(0.06)
        // Màu icon/chữ: chọn = accent, chưa chọn = xám nhạt
        let selected = tab.stackedLayoutAppearance.selected
        let normal   = tab.stackedLayoutAppearance.normal
        selected.iconColor = tintCol
        selected.titleTextAttributes = [.foregroundColor: tintCol]
        normal.iconColor = UIColor(white: 0.62, alpha: 1)
        normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.62, alpha: 1)]
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }

        // --- Thanh điều hướng ---
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        // --- Nền navy cho MỌI danh sách/Form; ô dạng thẻ navy nhạt hơn ---
        UITableView.appearance().backgroundColor = bg
        UITableViewCell.appearance().backgroundColor = card
        UICollectionView.appearance().backgroundColor = bg

        // --- Toolbar bàn phím ---
        let bar = UIToolbarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = bg
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
