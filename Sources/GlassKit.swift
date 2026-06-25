import SwiftUI

// Hiệu ứng Liquid Glass của iOS 26. Trên iOS cũ hơn tự động dùng material.
// Lưu ý: cần build bằng Xcode 26 (SDK iOS 26) để biên dịch glassEffect.
extension View {
    @ViewBuilder
    func kGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func kGlassInteractive<S: Shape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.interactive(), in: shape)
            }
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
