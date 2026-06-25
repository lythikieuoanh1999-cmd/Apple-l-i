import SwiftUI

// ======================== CenMail — Email tạm (mail.cenios.net) ========================
// Nhúng dịch vụ email tạm/clone của bạn (domain cenios.net) ngay trong app.
struct CenMailView: View {
    @StateObject private var model = BrowserModel()
    private let home = "https://mail.cenios.net"

    var body: some View {
        NavigationStack {
            BrowserWebView(model: model, home: home)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("CenMail")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { model.open(home) } label: { Image(systemName: "house") }
                        Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                    }
                }
        }
    }
}
