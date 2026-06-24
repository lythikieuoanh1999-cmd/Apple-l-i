import SwiftUI
import AVFoundation

// ======================== Engine TTS (đọc văn bản, phát nền) ========================
final class TTSEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()

    @Published var isSpeaking = false
    @Published var isPaused = false

    @Published var voiceId: String = ""          // identifier của AVSpeechSynthesisVoice
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate   // ~0.5
    @Published var pitch: Float = 1.0             // 0.5 ... 2.0
    @Published var volume: Float = 1.0            // 0 ... 1

    override init() {
        super.init()
        synth.delegate = self
        // chọn mặc định 1 giọng tiếng Việt nếu có
        if let vi = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("vi") }) {
            voiceId = vi.identifier
        } else if let any = AVSpeechSynthesisVoice.speechVoices().first {
            voiceId = any.identifier
        }
    }

    /// Bật phiên audio dạng playback để tiếp tục đọc khi khoá màn hình / chuyển app khác.
    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? s.setActive(true, options: [])
    }

    func speak(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        activateSession()
        let u = AVSpeechUtterance(string: t)
        if let v = AVSpeechSynthesisVoice(identifier: voiceId) { u.voice = v }
        u.rate = rate
        u.pitchMultiplier = pitch
        u.volume = volume
        synth.speak(u)          // tự xếp hàng nếu đang đọc cái khác
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isPaused = false
    }
    func pauseOrContinue() {
        if synth.isPaused { synth.continueSpeaking(); isPaused = false }
        else if synth.isSpeaking { synth.pauseSpeaking(at: .word); isPaused = true }
    }

    // delegate
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { isSpeaking = true }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        if !s.isSpeaking { isSpeaking = false; isPaused = false }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { isSpeaking = false }
}

// ======================== Loại sự kiện livestream ========================
struct LiveEventType: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let template: String     // dùng {name} và {content}
}

private let kLiveEvents: [LiveEventType] = [
    .init(id: "join",    label: "Người vào",   icon: "person.fill.badge.plus", template: "Chào mừng {name} đã vào phòng"),
    .init(id: "gift",    label: "Tặng quà",    icon: "gift.fill",              template: "Cảm ơn {name} đã tặng {content}"),
    .init(id: "comment", label: "Bình luận",   icon: "text.bubble.fill",       template: "{name} bình luận: {content}"),
    .init(id: "follow",  label: "Follow",      icon: "heart.fill",             template: "Cảm ơn {name} đã theo dõi"),
    .init(id: "share",   label: "Chia sẻ",     icon: "square.and.arrow.up.fill", template: "Cảm ơn {name} đã chia sẻ live"),
]

// ======================== Giao diện ========================
struct TTSView: View {
    @StateObject private var tts = TTSEngine()

    @State private var freeText = ""
    @State private var personName = ""
    @State private var content = ""
    @State private var selectedEvent = "gift"
    @State private var search = ""

    private var voices: [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
            .sorted { ($0.language, $0.name) < ($1.language, $1.name) }
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.language.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ----- Thông báo livestream -----
                    section("Thông báo livestream") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(kLiveEvents) { e in
                                    Button { selectedEvent = e.id } label: {
                                        Label(e.label, systemImage: e.icon).font(.caption)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(selectedEvent == e.id ? Theme.accent.opacity(0.25) : Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        textField("Tên người (name)", $personName)
                        if selectedEvent == "gift" || selectedEvent == "comment" {
                            textField(selectedEvent == "gift" ? "Quà (content)" : "Nội dung bình luận", $content)
                        }
                        Button {
                            tts.speak(renderEvent())
                        } label: {
                            Label("Đọc thông báo", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(personName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Text("Xem trước: \(renderEvent())").font(.caption2).foregroundStyle(.secondary)
                    }

                    // ----- Đọc văn bản tự do -----
                    section("Đọc văn bản") {
                        TextEditor(text: $freeText)
                            .font(.body).frame(minHeight: 110)
                            .padding(6).background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button { tts.speak(freeText) } label: {
                            Label("Đọc", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // ----- Điều khiển phát -----
                    HStack {
                        Button { tts.pauseOrContinue() } label: {
                            Label(tts.isPaused ? "Tiếp tục" : "Tạm dừng",
                                  systemImage: tts.isPaused ? "play.fill" : "pause.fill")
                        }.buttonStyle(.bordered).disabled(!tts.isSpeaking && !tts.isPaused)
                        Spacer()
                        Button(role: .destructive) { tts.stop() } label: {
                            Label("Dừng", systemImage: "stop.fill")
                        }.buttonStyle(.bordered).disabled(!tts.isSpeaking && !tts.isPaused)
                    }

                    // ----- Tinh chỉnh giọng -----
                    section("Tuỳ chỉnh giọng") {
                        slider("Tốc độ", value: $tts.rate,
                               range: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
                        slider("Cao độ", value: $tts.pitch, range: 0.5...2.0)
                        slider("Âm lượng", value: $tts.volume, range: 0...1)
                    }

                    // ----- Chọn giọng -----
                    section("Giọng đọc (\(AVSpeechSynthesisVoice.speechVoices().count) giọng)") {
                        textField("Tìm theo tên / ngôn ngữ (vd: vi, English)", $search)
                        VStack(spacing: 0) {
                            ForEach(voices, id: \.identifier) { v in
                                Button { tts.voiceId = v.identifier } label: {
                                    HStack {
                                        Image(systemName: tts.voiceId == v.identifier ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(Theme.accent)
                                        VStack(alignment: .leading) {
                                            Text(v.name).font(.subheadline)
                                            Text("\(v.language) · \(qualityText(v.quality))")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }.padding(.vertical, 6)
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }
                        Text("Muốn thêm giọng tự nhiên hơn: iOS → Cài đặt → Trợ năng → Nội dung nói → Giọng nói → tải thêm.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Đọc (TTS)")
        }
    }

    // ----- helpers -----
    private func renderEvent() -> String {
        let e = kLiveEvents.first { $0.id == selectedEvent } ?? kLiveEvents[0]
        let name = personName.isEmpty ? "bạn" : personName
        return e.template
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{content}", with: content.isEmpty ? "" : content)
            .trimmingCharacters(in: .whitespaces)
    }
    private func qualityText(_ q: AVSpeechSynthesisVoiceQuality) -> String {
        switch q {
        case .enhanced: return "nâng cao"
        case .premium:  return "cao cấp"
        default:        return "thường"
        }
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold())
            content()
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func textField(_ ph: String, _ text: Binding<String>) -> some View {
        TextField(ph, text: text)
            .padding(8).background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func slider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue)).font(.caption2).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
