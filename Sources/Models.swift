import Foundation

struct Provider: Identifiable, Decodable, Hashable {
    let id: String
    let label: String
    let models: [String]
    let defaultModel: String
    let vision: Bool
    let free: Bool
    let code: Bool?
}

struct UserInfo: Decodable, Hashable {
    let id: Int
    let username: String
    let email: String?
    let phone: String?
    let isAdmin: Bool?
    let plan: String?
    let credits: Int?
    let lang: String?
}

struct AuthResponse: Decodable { let token: String; let user: UserInfo }

struct SavedFile: Decodable, Hashable { let id: Int; let name: String }

struct ChatResponse: Decodable {
    let reply: String
    let conversationId: Int
    let provider: String
    let savedFiles: [SavedFile]?
    let tokensUsed: Int?
}

struct EnsembleResponse: Decodable {
    let best: String
    let judge: String
    let answers: [String: String]
}

struct Conversation: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String?
    let provider: String?
    let updatedAt: Int?
    let pinned: Int?
    let shareToken: String?
}

struct ChatMessage: Identifiable, Decodable {
    let id = UUID()
    let role: String
    let content: String
    var provider: String? = nil
    enum CodingKeys: String, CodingKey { case role, content }
    init(role: String, content: String, provider: String? = nil) {
        self.role = role; self.content = content; self.provider = provider
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decode(String.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        provider = nil
    }
}

struct ConversationDetail: Decodable {
    let conversationId: Int
    let messages: [ChatMessage]
}

struct MessageResponse: Decodable { let message: String }
struct ForgotResponse: Decodable { let message: String; let resetToken: String? }
struct KeyInfo: Decodable { let provider: String; let configured: Bool }
struct ServerConfig: Decodable { let name: String; let providers: [Provider] }
struct VoiceResponse: Decodable { let text: String }

struct FileItem: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let category: String?
    let size: Int?
    let createdAt: Int?
}
struct FileDetail: Decodable {
    let name: String
    let category: String?
    let dataBase64: String
}
struct UploadResponse: Decodable { let id: Int; let name: String; let size: Int }

struct AdminUser: Identifiable, Decodable, Hashable {
    let id: Int
    let username: String
    let email: String?
    let phone: String?
    let isAdmin: Int?
    let banned: Int?
    let plan: String?
    let credits: Int?
    let createdAt: Int?
}

struct ServerProfile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: String   // "VPS" | "Hosting"
    var url: String
}

// ---- Sandbox / Code tools ----
struct CodeRunResult: Decodable {
    let stdout: String
    let stderr: String
    let returncode: Int
}
struct FileRunResult: Decodable, Identifiable {
    let id = UUID()
    let file: String
    let stdout: String
    let stderr: String
    let returncode: Int
    enum CodingKeys: String, CodingKey { case file, stdout, stderr, returncode }
}
struct CodeAIResult: Decodable {
    let result: String
    let task: String
    let provider: String
}

// ---- Thanh toán / Credits ----
struct CreditsResponse: Decodable {
    let credits: Int
    let plan: String
}
struct PaymentPackage: Identifiable, Decodable, Hashable {
    let id: String
    let credits: Int
    let amount: Int
    let label: String
}
struct BankInfo: Decodable {
    let bank: String
    let account: String
    let name: String
    let content: String
}
struct PaymentCreateResponse: Decodable {
    let paymentId: Int
    let ref: String
    let amount: Int
    let credits: Int
    let label: String
    let message: String
    let bankInfo: BankInfo
    let qrUrl: String?
}
struct PaymentRecord: Identifiable, Decodable, Hashable {
    let id: Int
    let amount: Int
    let credits: Int
    let status: String
    let ref: String?
    let createdAt: Int?
}

struct ErrorLog: Identifiable, Decodable, Hashable {
    let id: Int
    let userId: Int?
    let username: String?
    let context: String?
    let detail: String?
    let createdAt: Int?
}

struct BankSettings: Decodable, Hashable {
    var bankCode: String
    var bankShort: String
    var bankAccount: String
    var bankName: String
    var bankWebhook: String
    var bankApikey: String = ""
}

// ---- Đính kèm (Attachment) ----
struct AttachmentItem: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var data: Data
    var mime: String
    var type: String  // "image" or "file"
    var selected: Bool = true
    var thumbnail: Data?  // for image preview
}

// ---- Prompt mẫu ----
struct PromptTemplate: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let content: String
    let category: String?
    let isPublic: Int?
    let userId: Int?
}

// ---- Chia sẻ hội thoại ----
struct ShareResponse: Decodable { let shareToken: String; let shareUrl: String }

// ---- Tìm kiếm tin nhắn ----
struct SearchResult: Identifiable, Decodable, Hashable {
    let id: Int
    let conversationId: Int
    let conversationTitle: String?
    let role: String
    let snippet: String
}

// ---- Tin nhắn yêu thích ----
struct FavoriteMessage: Identifiable, Decodable, Hashable {
    let id: Int
    let messageContent: String
    let conversationId: Int?
    let provider: String?
    let createdAt: Int?
}

// ---- Admin thống kê ----
struct AdminStats: Decodable {
    let totalUsers: Int
    let newUsers7d: Int
    let totalConversations: Int
    let totalMessages: Int
    let revenueTotal: Int
    let revenue30d: Int
    let totalFiles: Int
    let topProviders: [ProviderStat]
}

struct ProviderStat: Decodable, Hashable {
    let provider: String
    let count: Int
}

// ---- Admin API key quản lý ----
struct AdminKeyInfo: Identifiable, Decodable, Hashable {
    var id: String { provider }
    let provider: String
    let configured: Bool
}

// ---- Xuất mã zip ----
struct ZipResponse: Decodable {
    let zipBase64: String
    let filename: String
    let fileCount: Int
}

// ---- Phân hệ mạng xã hội ----
struct SocialGenResponse: Decodable {
    let content: String
}
struct SocialDownloadResponse: Decodable {
    let fileId: Int
    let filename: String
    let size: Int
}

struct StreamKeyResponse: Decodable {
    let rtmpUrl: String
    let streamKey: String
    let title: String?
}

// TikTok Live (đọc bình luận tự động)
struct TikTokLiveStatus: Decodable {
    let ok: Bool?
    let status: String
    let username: String?
}

struct TikTokLiveEvent: Decodable, Identifiable {
    let id: Int
    let type: String      // join | gift | comment | follow | share
    let name: String
    let content: String
}

struct TikTokLiveEventsResponse: Decodable {
    let status: String
    let error: String?
    let events: [TikTokLiveEvent]
    let last: Int
}

struct TranslateResponse: Decodable {
    let text: String
    let source: String?
}

// KenMail — email tích hợp
struct Mailbox: Decodable, Identifiable {
    let id: Int
    let address: String
    let createdAt: Int?
    let unseen: Int?
}
struct MailboxListResponse: Decodable {
    let mailboxes: [Mailbox]
    let domain: String
}
struct MailboxCreateResponse: Decodable {
    let id: Int
    let address: String
}
struct MailCredential: Decodable, Identifiable {
    var id: String { address }
    let address: String
    let password: String
}
struct MailBulkResponse: Decodable {
    let created: [MailCredential]
    let count: Int
}
struct MailItem: Decodable, Identifiable {
    let id: Int
    let direction: String     // in | out
    let fromAddr: String?
    let toAddr: String?
    let subject: String?
    let body: String?
    let createdAt: Int?
    let seen: Int?
}
struct MailInboxResponse: Decodable {
    let mails: [MailItem]
}

// OTP — mã xác nhận email
struct OtpSendResponse: Decodable {
    let sent: Bool
    let channel: String       // internal | external | none
    let hint: String?
    let debugCode: String?
}

struct EncryptResponse: Decodable {
    let result: String
}

struct BinaryAnalysisResponse: Decodable {
    let fileType: String
    let entryPoint: String?
    let architecture: String?
    let sections: [String]?
    let strings: [String]?
    let hexDump: String
}

struct AsmResponse: Decodable {
    let result: String
}

struct SSHResultResponse: Decodable {
    let stdout: String
    let stderr: String
    let exitCode: Int
}

struct HTTPTestResponse: Decodable {
    let status: Int
    let headers: [String: String]
    let body: String
}

struct SQLResultResponse: Decodable {
    let columns: [String]
    let rows: [[String]]
    let message: String?
}

struct CleanupResponse: Decodable {
    let deletedMessages: Int
    let deletedConversations: Int
    let freedSpace: String
    let message: String
}

struct UserSearchResult: Identifiable, Decodable, Hashable {
    let id: Int
    let username: String
}

struct FriendRequestItem: Identifiable, Decodable, Hashable {
    let id: Int
    let senderId: Int
    let senderName: String
    let receiverId: Int
    let receiverName: String
    let createdAt: Int
}

struct FriendItem: Identifiable, Decodable, Hashable {
    let id: Int
    let username: String
}

struct DirectMessageItem: Identifiable, Decodable, Hashable {
    let id: Int
    let senderId: Int
    let receiverId: Int
    let content: String
    let createdAt: Int
    let isRead: Int
}

