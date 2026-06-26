import SwiftUI

/// Chữ 7 sắc cầu vồng **chạy nối tiếp liên tục** (dùng cho logo + tiêu đề).
struct RainbowText: View {
    let text: String
    var size: CGFloat = 22
    var weight: Font.Weight = .black
    var design: Font.Design = .rounded

    // 7 sắc cầu vồng (lặp lại màu đầu để vòng màu liền mạch)
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .indigo, .purple, .red]

    var body: some View {
        TimelineView(.animation) { tl in
            // Quay vòng màu theo thời gian (5s/vòng) → các màu "chạy" liên tục
            let secs = tl.date.timeIntervalSinceReferenceDate
            let hue = secs.truncatingRemainder(dividingBy: 5) / 5 * 360
            Text(text)
                .font(.system(size: size, weight: weight, design: design))
                .foregroundStyle(
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                )
                .hueRotation(.degrees(hue))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// Logo chữ **KENIOS** — giờ là chữ cầu vồng động, dùng ở toolbar mọi màn hình.
struct ThreeDLogoText: View {
    var size: CGFloat = 22
    var body: some View {
        RainbowText(text: "KENIOS", size: size)
    }
}

/// Phiên bản lớn cho màn hình đăng nhập
struct ThreeDLogoLarge: View {
    var body: some View {
        VStack(spacing: 6) {
            RainbowText(text: "KENIOS", size: 40)
            Text("Mạng xã hội · Video · Giải trí · Công cụ")
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
