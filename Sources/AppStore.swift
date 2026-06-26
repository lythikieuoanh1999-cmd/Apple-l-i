import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var baseURL: String
    @Published var serverType: String
    @Published var token: String?
    @Published var username: String?
    @Published var email: String?
    @Published var phone: String?
    @Published var isAdmin: Bool = false
    @Published var plan: String = "free"
    @Published var credits: Int = 0
    @Published var publicId: String = ""

    // Bảo trì (admin bật → khoá app người dùng)
    @Published var maintenance: Bool = false
    @Published var maintenanceMessage: String = ""

    /// Admin luôn Pro vĩnh viễn; còn lại tuỳ gói.
    var isPro: Bool { isAdmin || plan.lowercased() == "pro" }

    @Published var providers: [Provider] = []
    @Published var configuredKeys: Set<String> = []
    @Published var conversations: [Conversation] = []

    @Published var tab: Int = 0
    @Published var activeConversation: Conversation?

    @Published var isDark: Bool
    @Published var language: String
    @Published var systemPrompt: String

    @Published var profiles: [ServerProfile] = []

    @Published var biometricsEnabled: Bool
    @Published var favorites: [FavoriteMessage] = []
    @Published var promptTemplates: [PromptTemplate] = []

    @Published var friends: [FriendItem] = []
    @Published var friendRequests: [FriendRequestItem] = []
    @Published var directMessages: [Int: [DirectMessageItem]] = [:]

    private let d = UserDefaults.standard

    init() {
        let savedURL = d.string(forKey: "baseURL") ?? ""
        baseURL = savedURL.isEmpty ? Config.defaultServerURL : savedURL
        serverType = d.string(forKey: "serverType") ?? Config.defaultServerType
        username = d.string(forKey: "username")
        email = d.string(forKey: "email")
        phone = d.string(forKey: "phone")
        token = Keychain.load("token")
        isAdmin = d.bool(forKey: "isAdmin")
        plan = d.string(forKey: "plan") ?? "free"
        credits = d.integer(forKey: "credits")
        publicId = d.string(forKey: "publicId") ?? ""
        isDark = d.object(forKey: "isDark") as? Bool ?? true
        language = d.string(forKey: "language") ?? "vi"
        systemPrompt = d.string(forKey: "systemPrompt") ?? ""
        biometricsEnabled = d.bool(forKey: "biometricsEnabled")
        if let data = d.data(forKey: "profiles"),
           let list = try? JSONDecoder().decode([ServerProfile].self, from: data) {
            profiles = list
        }
    }

    var api: APIClient { APIClient(baseURL: baseURL, token: token) }
    var isConfigured: Bool { !baseURL.trimmingCharacters(in: .whitespaces).isEmpty }
    var isLoggedIn: Bool { token != nil }

    func setDark(_ v: Bool) { isDark = v; d.set(v, forKey: "isDark") }
    func setLanguage(_ v: String) { language = v; d.set(v, forKey: "language") }
    func setSystemPrompt(_ v: String) { systemPrompt = v; d.set(v, forKey: "systemPrompt") }
    func setBiometrics(_ v: Bool) { biometricsEnabled = v; d.set(v, forKey: "biometricsEnabled") }

    func saveServer(url: String, type: String) {
        baseURL = url; serverType = type
        d.set(url, forKey: "baseURL"); d.set(type, forKey: "serverType")
    }

    // --- Hồ sơ kết nối (mỗi khách có VPS/hosting riêng) ---
    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) { d.set(data, forKey: "profiles") }
    }
    func addProfile(name: String, type: String, url: String) {
        let p = ServerProfile(name: name, type: type, url: url)
        profiles.append(p); persistProfiles()
        selectProfile(p)
    }
    func selectProfile(_ p: ServerProfile) { saveServer(url: p.url, type: p.type) }
    func deleteProfile(_ p: ServerProfile) {
        profiles.removeAll { $0.id == p.id }; persistProfiles()
    }

    func setAuth(_ resp: AuthResponse) {
        token = resp.token; username = resp.user.username
        email = resp.user.email; phone = resp.user.phone
        isAdmin = resp.user.isAdmin ?? false
        plan = resp.user.plan ?? "free"
        credits = resp.user.credits ?? 0
        publicId = resp.user.publicId ?? ""
        Keychain.save("token", resp.token)
        d.set(resp.user.username, forKey: "username")
        d.set(resp.user.email ?? "", forKey: "email")
        d.set(resp.user.phone ?? "", forKey: "phone")
        d.set(isAdmin, forKey: "isAdmin")
        d.set(plan, forKey: "plan")
        d.set(credits, forKey: "credits")
        d.set(publicId, forKey: "publicId")
    }

    /// Tải lại hồ sơ + trạng thái bảo trì.
    func refreshMe() async {
        if let me = try? await api.getMe() {
            isAdmin = me.isAdmin ?? false
            plan = me.plan ?? "free"
            publicId = me.publicId ?? publicId
            d.set(isAdmin, forKey: "isAdmin"); d.set(plan, forKey: "plan")
            d.set(publicId, forKey: "publicId")
        }
        if let st = try? await api.appStatus() {
            maintenance = st.maintenance
            maintenanceMessage = st.message
        }
    }

    func refreshCredits() async {
        if let c = try? await api.myCredits() {
            credits = c.credits; plan = c.plan
            d.set(plan, forKey: "plan"); d.set(credits, forKey: "credits")
        }
    }

    func updateLocalUser(email: String?, phone: String?) {
        if let email { self.email = email; d.set(email, forKey: "email") }
        if let phone { self.phone = phone; d.set(phone, forKey: "phone") }
    }

    func logout() {
        token = nil; username = nil; isAdmin = false; plan = "free"; credits = 0
        Keychain.delete("token")
        providers = []; configuredKeys = []; conversations = []
        activeConversation = nil; tab = 0
        favorites = []; promptTemplates = []
        friends = []; friendRequests = []; directMessages = [:]
        d.set(false, forKey: "isAdmin")
    }

    func loadProviders() async {
        if let l = try? await api.getProviders() { providers = l }
        // KENIOS AI tự host: không cần key → luôn coi là đã cấu hình
        if providers.contains(where: { $0.id == "kenios" }) { configuredKeys.insert("kenios") }
    }
    func loadKeys() async {
        if let l = try? await api.listKeys() {
            var s = Set(l.map { $0.provider })
            if providers.contains(where: { $0.id == "kenios" }) { s.insert("kenios") }
            configuredKeys = s
        }
    }
    func refreshConversations() async { if let l = try? await api.conversations() { conversations = l } }
    func openConversation(_ c: Conversation?) { activeConversation = c; tab = 0 }

    func refreshFavorites() async {
        if let l = try? await api.listFavorites() { favorites = l }
    }

    func refreshPrompts() async {
        if let l = try? await api.listPrompts() { promptTemplates = l }
    }

    func refreshFriends() async {
        if let l = try? await api.listFriends() { friends = l }
    }

    func refreshFriendRequests() async {
        if let l = try? await api.listFriendRequests() { friendRequests = l }
    }

    func refreshDirectMessages(friendId: Int) async {
        if let l = try? await api.getDirectMessages(friendId: friendId) {
            directMessages[friendId] = l
        }
    }
}
