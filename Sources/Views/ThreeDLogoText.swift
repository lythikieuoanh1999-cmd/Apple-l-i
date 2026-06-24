import SwiftUI

/// Logo chữ **KENIOS** nổi 3D — dùng ở góc trái toolbar mọi màn hình.
/// Kỹ thuật: Xếp chồng nhiều lớp text lệch pixel + gradient + shadow.
struct ThreeDLogoText: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            // ---- Shadow layers (3D depth) ----
            ForEach(0..<5, id: \.self) { i in
                Text("KENIOS")
                    .font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundStyle(
                        Color.black.opacity(0.35 - Double(i) * 0.06)
                    )
                    .offset(x: CGFloat(i) * 0.4, y: CGFloat(i) * 0.7)
            }
            // ---- Glow layer ----
            Text("KENIOS")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.6), Theme.accent.opacity(0.4), Theme.purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 4)
            // ---- Main gradient text ----
            Text("KENIOS")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, Theme.accent, Theme.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.accent.opacity(0.6), radius: 3, x: 0, y: 2)
                .shadow(color: Theme.purple.opacity(0.3), radius: 6, x: 0, y: 4)
        }
    }
}

/// Phiên bản lớn cho màn hình đăng nhập
struct ThreeDLogoLarge: View {
    var body: some View {
        VStack(spacing: 6) {
            ThreeDLogoText(size: 38)
            Text("Multi-AI Coding Assistant")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Badge nhãn gói cước (Free / PRO / ULTRA / MAX)
struct PlanBadge: View {
    let plan: String

    private var label: String {
        switch plan.lowercased() {
        case "pro": return "PRO"
        case "ultra": return "ULTRA"
        case "max": return "MAX"
        default: return "Free"
        }
    }

    private var color: Color {
        switch plan.lowercased() {
        case "pro": return .green
        case "ultra": return .blue
        case "max": return Theme.purple
        default: return .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                plan.lowercased() == "max"
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Theme.purple, .pink],
                        startPoint: .leading, endPoint: .trailing).opacity(0.25))
                    : AnyShapeStyle(color.opacity(0.2))
            )
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Markdown-ish text renderer (hỗ trợ code blocks, bold, italic)
struct MarkdownText: View {
    let text: String

    var body: some View {
        if #available(iOS 16.0, *), let attributed = try? AttributedString(markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(text)
                .textSelection(.enabled)
        }
    }
}

/// Attachment preview chip (ảnh nhỏ hoặc icon file) — dùng trong thanh ngang xem trước
struct AttachmentChipView: View {
    let item: AttachmentItem
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail hoặc icon
                if item.type == "image", let uiImage = UIImage(data: item.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: fileIcon(item.mime))
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                        )
                }

                // Nút xóa
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 6, y: -6)
            }

            // Dấu tích chọn / bỏ chọn
            Button(action: onToggle) {
                Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.selected ? .green : .secondary)
            }

            Text(item.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .frame(width: 60)
        }
    }

    private func fileIcon(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime == "application/pdf" { return "doc.richtext" }
        if mime.hasPrefix("text/") || mime.contains("json") || mime.contains("xml") {
            return "chevron.left.forwardslash.chevron.right"
        }
        return "doc"
    }
}

/// Token counter label
struct TokenCountView: View {
    let tokens: Int?

    var body: some View {
        if let t = tokens, t > 0 {
            HStack(spacing: 3) {
                Image(systemName: "number.circle")
                    .font(.system(size: 9))
                Text("~\(t) tokens")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.secondary)
        }
    }
}
