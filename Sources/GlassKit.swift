import SwiftUI

// Thẻ nền kiểu "kính mờ" dùng vật liệu hệ thống (ultraThinMaterial).
// Tương thích mọi Xcode/SDK (iOS 15+) → IPA build chắc chắn thành công,
// không phụ thuộc API Liquid Glass (glassEffect) của SDK iOS 26.
extension View {
    func kGlass<S: Shape>(_ shape: S) -> some View {
        self.background(.ultraThinMaterial, in: shape)
    }

    @ViewBuilder
    func kGlassInteractive<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        if let tint {
            self.background(tint.opacity(0.18), in: shape)
                .background(.ultraThinMaterial, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    // Nền thẻ navy cao cấp dùng chung cho các khối nội dung
    func kCard(_ radius: CGFloat = 16) -> some View {
        self
            .background(Theme.cardNavy)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

// Banner gradient sang trọng cho đầu mỗi màn hình
struct KHeroHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}
