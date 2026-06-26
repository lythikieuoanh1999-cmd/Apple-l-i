import SwiftUI

/// Thẻ khoá tính năng nâng cao cho người dùng gói Free.
struct ProLockCard: View {
    let feature: String
    @State private var showPay = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48)).foregroundStyle(Theme.gold)
                Text("Tính năng Pro").font(.title3.bold())
                Text("“\(feature)” chỉ dành cho gói Pro. Gói Free dùng được các tính năng cơ bản; nâng cấp Pro để mở khoá đầy đủ tính năng nâng cao.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                Button { showPay = true } label: {
                    Label("Nâng cấp Pro", systemImage: "crown")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Theme.buttonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }.padding(.horizontal, 24)
            }
            .padding(.top, 50)
        }
        .sheet(isPresented: $showPay) { PaymentView() }
    }
}

/// Huy hiệu PRO nhỏ.
struct ProTag: View {
    var body: some View {
        Text("PRO").font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.gold.opacity(0.22)).foregroundStyle(Theme.gold)
            .clipShape(Capsule())
    }
}
