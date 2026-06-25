import SwiftUI

enum Theme {
    static let accent = Color(red: 0.31, green: 0.55, blue: 1.0)     // xanh dương KENIOS
    static let purple = Color(red: 0.65, green: 0.45, blue: 0.95)
    static let gold   = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let neon   = Color(red: 0.0, green: 1.0, blue: 0.85)

    // Gradient cho nền card
    static let cardGradient = LinearGradient(
        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
        startPoint: .top, endPoint: .bottom)

    // Gradient cho nút chính (vibrant hơn: xanh ngọc → xanh dương → tím)
    static let buttonGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.78, blue: 0.92), accent, purple],
        startPoint: .leading, endPoint: .trailing)

    // Gradient nền sang trọng cho header / màn hình đăng nhập
    static let heroGradient = LinearGradient(
        colors: [accent.opacity(0.9), purple.opacity(0.85),
                 Color(red: 0.95, green: 0.45, blue: 0.7).opacity(0.8)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Màu gói cước
    static func planColor(_ plan: String) -> Color {
        switch plan.lowercased() {
        case "pro":   return .green
        case "ultra": return .blue
        case "max":   return purple
        default:      return .secondary
        }
    }

    static func planLabel(_ plan: String) -> String {
        switch plan.lowercased() {
        case "pro":   return "PRO"
        case "ultra": return "ULTRA"
        case "max":   return "MAX"
        default:      return "Free"
        }
    }
}

func providerColor(_ id: String) -> Color {
    switch id {
    case "kenios":      return Theme.gold   // AI riêng — màu vàng nổi bật (đỉnh)
    case "gemini":      return .blue
    case "openai":      return .green
    case "anthropic":   return Theme.purple
    case "groq":        return .green
    case "deepseek":    return .yellow
    case "xai":         return .red
    case "mistral":     return .pink
    case "openrouter":  return .teal
    case "perplexity":  return .cyan
    case "qwen":        return .orange
    case "moonshot":    return .indigo
    case "together":    return .mint
    case "fireworks":   return .orange
    case "cerebras":    return .cyan
    case "nvidia":      return .green
    case "cohere":      return .purple
    default:            return .gray
    }
}

func categoryIcon(_ category: String?) -> String {
    switch category {
    case "image":    return "photo"
    case "code":     return "chevron.left.forwardslash.chevron.right"
    case "document": return "doc.text"
    default:         return "doc"
    }
}

func humanSize(_ bytes: Int?) -> String {
    guard let b = bytes else { return "" }
    if b < 1024 { return "\(b) B" }
    if b < 1024 * 1024 { return String(format: "%.0f KB", Double(b) / 1024) }
    return String(format: "%.1f MB", Double(b) / 1024 / 1024)
}

func providerLabel(_ id: String, providers: [Provider]) -> String {
    providers.first(where: { $0.id == id })?.label ?? (id.isEmpty ? "Chọn AI" : id)
}

func isFree(_ id: String, providers: [Provider]) -> Bool {
    providers.first(where: { $0.id == id })?.free ?? false
}
