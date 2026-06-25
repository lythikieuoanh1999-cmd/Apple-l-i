import SwiftUI
import AVFoundation
import MediaPlayer

// ======================== Engine TTS (đọc văn bản, phát nền) ========================
final class TTSEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    enum EngineType: String, CaseIterable, Identifiable {
        case system = "system"
        case google = "google"
        case siri = "siri"
        case elevenlabs = "elevenlabs"
        
        var id: String { self.rawValue }
        var label: String {
            switch self {
            case .system: return "Mặc định (iOS)"
            case .google: return "Chị Google (Online)"
            case .siri: return "Giọng Siri (iOS)"
            case .elevenlabs: return "Giọng ElevenLabs"
            }
        }
    }

    private let synth = AVSpeechSynthesizer()
    private var silentPlayer: AVAudioPlayer?
    
    // Google TTS Queue
    private var googleQueue: [String] = []
    private var googlePlayer: AVPlayer?
    private var isPlayingGoogle = false

    // ElevenLabs (đa ngôn ngữ — đọc tiếng Việt)
    // Key lưu trong Keychain (mã hoá iOS) — KHÔNG dùng UserDefaults cho secret.
    @Published var elevenKey: String = Keychain.load("elevenlabs_api_key") ?? "" {
        didSet {
            let trimmed = elevenKey.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                Keychain.delete("elevenlabs_api_key")
            } else {
                Keychain.save("elevenlabs_api_key", trimmed)
            }
        }
    }
    // Voice ID của ElevenLabs — nhập từ tài khoản elevenlabs.io của bạn.
    @Published var elevenVoiceId: String = UserDefaults.standard.string(forKey: "eleven_voice_id") ?? "" {
        didSet {
            UserDefaults.standard.set(elevenVoiceId, forKey: "eleven_voice_id")
            let vid = elevenVoiceId.trimmingCharacters(in: .whitespaces)
            if vid.isEmpty {
                elevenVoiceName = ""
                UserDefaults.standard.removeObject(forKey: "eleven_voice_name")
            } else {
                fetchElevenVoiceName(vid)
            }
        }
    }
    // Tên giọng hiển thị — tự động lấy từ API khi nhập Voice ID
    @Published var elevenVoiceName: String = UserDefaults.standard.string(forKey: "eleven_voice_name") ?? ""

    func fetchElevenVoiceName(_ vid: String) {
        let key = elevenKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, let url = URL(string: "https://api.elevenlabs.io/v1/voices/\(vid)") else { return }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "xi-api-key")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data else { return }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = obj["name"] as? String {
                DispatchQueue.main.async {
                    self.elevenVoiceName = name
                    UserDefaults.standard.set(name, forKey: "eleven_voice_name")
                }
            }
        }.resume()
    }
    // Preset tông giọng TikTok đang chọn (mặc định: TikTok Nhẹ)
    @Published var elevenToneId: String = UserDefaults.standard.string(forKey: "eleven_tone_id") ?? "tiktok_calm" {
        didSet { UserDefaults.standard.set(elevenToneId, forKey: "eleven_tone_id") }
    }
    private var currentTone: ElevenTonePreset {
        kElevenTonePresets.first { $0.id == elevenToneId } ?? kElevenTonePresets[0]
    }
    private var elevenPlayer: AVAudioPlayer?
    private var elevenQueue: [String] = []
    private var isPlayingEleven = false

    @Published var isSpeaking = false
    @Published var isPaused = false

    @Published var voiceId: String = ""          // identifier của AVSpeechSynthesisVoice
    @Published var rate: Float = UserDefaults.standard.object(forKey: "tts_rate") as? Float ?? AVSpeechUtteranceDefaultSpeechRate {
        didSet { UserDefaults.standard.set(rate, forKey: "tts_rate") }
    }
    @Published var pitch: Float = UserDefaults.standard.object(forKey: "tts_pitch") as? Float ?? 1.0 {
        didSet { UserDefaults.standard.set(pitch, forKey: "tts_pitch") }
    }
    @Published var volume: Float = UserDefaults.standard.object(forKey: "tts_volume") as? Float ?? 1.0 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "tts_volume")
            // Cập nhật âm lượng ngay cho audio đang phát (Google / ElevenLabs), không cần đợi đọc câu mới.
            googlePlayer?.volume = volume
            elevenPlayer?.volume = volume
        }
    }
    // Số đoạn còn đang chờ đọc trong hàng đợi (Google/ElevenLabs) — hiện ra UI để biết app có bị "ứ" bình luận không.
    @Published var pendingCount: Int = 0
    // Giới hạn hàng đợi khi live quá đông bình luận → bỏ bớt đoạn cũ, ưu tiên đọc đoạn mới gần thời điểm hiện tại.
    var maxQueueSize: Int = 20
    
    @Published var engineType: EngineType = .system {
        didSet {
            UserDefaults.standard.set(engineType.rawValue, forKey: "tts_engine_type")
        }
    }

    override init() {
        super.init()
        synth.delegate = self
        // chọn mặc định 1 giọng tiếng Việt nếu có
        if let vi = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("vi") }) {
            voiceId = vi.identifier
        } else if let any = AVSpeechSynthesisVoice.speechVoices().first {
            voiceId = any.identifier
        }
        
        if let savedEngine = UserDefaults.standard.string(forKey: "tts_engine_type"),
           let type = EngineType(rawValue: savedEngine) {
            self.engineType = type
        }
        setupRemoteCommands()   // điều khiển từ Control Center / màn khoá
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption),
                                                name: AVAudioSession.interruptionNotification, object: nil)
    }

    /// Tự khôi phục đọc/phát nền sau khi cuộc gọi đến/đi hoặc Siri… làm gián đoạn audio session.
    @objc private func handleAudioInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended {
            activateSession()
            if silentPlayer != nil { startBackgroundMode() }
            if isPlayingEleven, !isPaused { elevenPlayer?.play() }
            if isPlayingGoogle, !isPaused { googlePlayer?.play() }
        }
    }

    /// Bật phiên audio dạng playback để tiếp tục đọc khi khoá màn hình / chuyển app khác.
    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? s.setActive(true, options: [])
    }

    func speak(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        activateSession()
        // Tự bật chế độ nền (giữ audio sống khi chuyển app / khoá màn hình)
        if silentPlayer == nil { startBackgroundMode() }
        updateNowPlaying(playing: true)   // hiện ở Control Center / màn khoá

        switch engineType {
        case .google:
            playGoogleTTS(t)
        case .siri:
            playSiriTTS(t)
        case .elevenlabs:
            playElevenLabsTTS(t)
        case .system:
            playSystemTTS(t)
        }
    }
    
    private func playSystemTTS(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        if let v = AVSpeechSynthesisVoice(identifier: voiceId) { u.voice = v }
        u.rate = rate
        u.pitchMultiplier = pitch
        u.volume = volume
        synth.speak(u)          // tự xếp hàng nếu đang đọc cái khác
    }
    
    private func playSiriTTS(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let siriVoice = voices.first { v in
            v.language.hasPrefix("vi") && v.identifier.lowercased().contains("siri")
        } ?? voices.first { v in
            v.language.hasPrefix("vi")
        } ?? voices.first { v in
            v.identifier.lowercased().contains("siri")
        }
        
        if let v = siriVoice {
            u.voice = v
        }
        u.rate = rate
        u.pitchMultiplier = pitch
        u.volume = volume
        synth.speak(u)
    }
    
    private func playElevenLabsTTS(_ text: String) {
        // Dùng ElevenLabs chỉ khi có cả API key VÀ Voice ID
        let key = elevenKey.trimmingCharacters(in: .whitespaces)
        let vid = elevenVoiceId.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty && !vid.isEmpty {
            playElevenLabs(text)
            return
        }
        // Chưa nhập Voice ID → fallback Google TTS
        playGoogleTTS(text)
    }

    // Hàm dự phòng: đọc bằng giọng Việt trên thiết bị khi Google TTS không khả dụng
    private func playElevenLabsOfflineFallback(_ text: String) {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let viVoices = voices.filter { $0.language.hasPrefix("vi") }
        let viVoice = viVoices.first { $0.quality == .premium }
            ?? viVoices.first { $0.quality == .enhanced }
            ?? viVoices.first { $0.name.lowercased().contains("nam") }
            ?? viVoices.first
        guard let v = viVoice else { return } // không có giọng Việt, bỏ qua
        let u = AVSpeechUtterance(string: text)
        u.voice = v
        u.rate = min(rate, 0.52)               // Tốc độ vừa phải
        u.pitchMultiplier = min(pitch, 0.80)   // pitch trầm tự nhiên
        u.volume = volume
        u.preUtteranceDelay = 0.05             // giảm delay đầu câu
        synth.speak(u)
    }
    
    private func playGoogleTTS(_ text: String) {
        // Google TTS giới hạn ~200 ký tự/yêu cầu → chia 180 và đọc lần lượt TOÀN BỘ.
        let chunks = splitTextIntoChunks(text, maxLen: 180)
        for chunk in chunks {
            googleQueue.append(chunk)
        }
        // Khi live quá đông bình luận, hàng đợi có thể phình to khiến TTS đọc trễ rất lâu so với thực tế.
        // Giữ lại các đoạn MỚI NHẤT, bỏ bớt đoạn cũ để app luôn "đuổi kịp" livestream.
        if googleQueue.count > maxQueueSize {
            googleQueue.removeFirst(googleQueue.count - maxQueueSize)
        }
        pendingCount = googleQueue.count + elevenQueue.count
        if !isPlayingGoogle {
            playNextGoogleItem()
        }
    }
    
    private func splitTextIntoChunks(_ text: String, maxLen: Int) -> [String] {
        var chunks: [String] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".?!,;:\n"))
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if trimmed.count <= maxLen {
                chunks.append(trimmed)
            } else {
                let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
                var currentChunk = ""
                
                for word in words {
                    let candidate = currentChunk.isEmpty ? word : "\(currentChunk) \(word)"
                    if candidate.count <= maxLen {
                        currentChunk = candidate
                    } else {
                        if !currentChunk.isEmpty {
                            chunks.append(currentChunk)
                        }
                        currentChunk = word
                    }
                }
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
            }
        }
        return chunks
    }
    
    private func playNextGoogleItem() {
        guard !googleQueue.isEmpty else {
            isPlayingGoogle = false
            isSpeaking = false
            pendingCount = elevenQueue.count
            return
        }
        
        isPlayingGoogle = true
        isSpeaking = true
        let text = googleQueue.removeFirst()
        pendingCount = googleQueue.count + elevenQueue.count
        
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            playNextGoogleItem()
            return
        }
        
        let urlString = "https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=\(encodedText)"
        guard let url = URL(string: urlString) else {
            playNextGoogleItem()
            return
        }
        
        // QUAN TRỌNG: Google chặn rất nhiều request không có User-Agent giống trình duyệt thật
        // (trả về lỗi hoặc audio rỗng) → luôn đính kèm User-Agent để giảm tỉ lệ bị từ chối.
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
            ]
        ])
        let playerItem = AVPlayerItem(asset: asset)
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(googleItemDidPlayToEndTime), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(googleItemFailedToPlay), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        
        if googlePlayer == nil {
            googlePlayer = AVPlayer(playerItem: playerItem)
        } else {
            googlePlayer?.replaceCurrentItem(with: playerItem)
        }
        
        googlePlayer?.volume = volume
        googlePlayer?.play()
        
        // Timeout 5 giây: nếu Google không trả về audio → fallback offline
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self, self.isPlayingGoogle else { return }
            if let status = self.googlePlayer?.currentItem?.status, status == .failed {
                // Google fail → dùng giọng offline nếu đang ở ElevenLabs mode
                if self.engineType == .elevenlabs {
                    self.playElevenLabsOfflineFallback(text)
                }
                self.playNextGoogleItem()
            }
        }
    }
    
    @objc private func googleItemDidPlayToEndTime(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.playNextGoogleItem()
        }
    }
    
    @objc private func googleItemFailedToPlay(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.playNextGoogleItem()
        }
    }

    // ===== ElevenLabs (đa ngôn ngữ · đọc tiếng Việt) =====
    private func playElevenLabs(_ text: String) {
        elevenQueue.append(text)
        if elevenQueue.count > maxQueueSize {
            elevenQueue.removeFirst(elevenQueue.count - maxQueueSize)
        }
        pendingCount = googleQueue.count + elevenQueue.count
        if !isPlayingEleven { playNextEleven() }
    }

    private func playNextEleven() {
        guard !elevenQueue.isEmpty else {
            isPlayingEleven = false
            isSpeaking = false
            pendingCount = googleQueue.count
            updateNowPlaying(playing: false)
            return
        }
        isPlayingEleven = true
        isSpeaking = true
        updateNowPlaying(playing: true)
        let text = elevenQueue.removeFirst()
        pendingCount = googleQueue.count + elevenQueue.count
        let key = elevenKey.trimmingCharacters(in: .whitespaces)
        let vid = elevenVoiceId.trimmingCharacters(in: .whitespaces)
        guard !vid.isEmpty, let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(vid)") else {
            playNextEleven(); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue(key, forHTTPHeaderField: "xi-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        // Dùng model do người dùng chọn trong ElevenLabsKeyView (lưu UserDefaults)
        let model = UserDefaults.standard.string(forKey: "eleven_model") ?? "eleven_multilingual_v2"
        let tone = currentTone
        let body: [String: Any] = [
            "text": text,
            "model_id": model,
            "language_code": "vi",
            "voice_settings": [
                "stability": tone.stability,
                "similarity_boost": tone.similarityBoost,
                "style": tone.style,
                "use_speaker_boost": tone.speakerBoost
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if let data, code == 200, !data.isEmpty {
                    do {
                        self.activateSession()
                        let player = try AVAudioPlayer(data: data)
                        player.delegate = self
                        player.volume = self.volume
                        player.prepareToPlay()
                        player.play()
                        self.elevenPlayer = player
                    } catch {
                        self.playNextEleven()
                    }
                } else {
                    // Lỗi key/mạng → bỏ đoạn này, đọc tiếp phần còn lại
                    self.playNextEleven()
                }
            }
        }.resume()
    }

    // ===== Now Playing (hiện ở Control Center / màn khoá) =====
    func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.removeTarget(nil); c.pauseCommand.removeTarget(nil); c.stopCommand.removeTarget(nil)
        c.playCommand.isEnabled = true; c.pauseCommand.isEnabled = true; c.stopCommand.isEnabled = true
        c.playCommand.addTarget { [weak self] _ in self?.pauseOrContinue(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pauseOrContinue(); return .success }
        c.stopCommand.addTarget { [weak self] _ in self?.stop(); return .success }
    }

    private func updateNowPlaying(playing: Bool) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "KENIOS đang đọc"
        info[MPMediaItemPropertyArtist] = "KENIOS AI"
        info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        googleQueue.removeAll()
        googlePlayer?.pause()
        googlePlayer = nil
        isPlayingGoogle = false
        elevenQueue.removeAll()
        elevenPlayer?.stop()
        elevenPlayer = nil
        isPlayingEleven = false
        isSpeaking = false
        isPaused = false
        pendingCount = 0
        updateNowPlaying(playing: false)
        stopBackgroundMode()
    }

    /// Bỏ qua đoạn đang đọc, chuyển ngay sang đoạn tiếp theo trong hàng đợi (hữu ích khi live bình luận đông, đọc không kịp).
    func skipCurrent() {
        if isPlayingEleven {
            elevenPlayer?.stop()
            playNextEleven()
        } else if isPlayingGoogle {
            googlePlayer?.pause()
            playNextGoogleItem()
        } else if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
    }

    // ElevenLabs phát xong 1 đoạn → đọc đoạn tiếp theo
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player === elevenPlayer { playNextEleven() }
    }

    func pauseOrContinue() {
        if isPlayingEleven {
            if isPaused { elevenPlayer?.play(); isPaused = false }
            else if isSpeaking { elevenPlayer?.pause(); isPaused = true }
        } else if engineType == .google {
            if isPaused {
                googlePlayer?.play()
                isPaused = false
            } else if isSpeaking {
                googlePlayer?.pause()
                isPaused = true
            }
        } else {
            if synth.isPaused { synth.continueSpeaking(); isPaused = false }
            else if synth.isSpeaking { synth.pauseSpeaking(at: .word); isPaused = true }
        }
    }

    func startBackgroundMode() {
        activateSession()
        guard let silentData = createSilentWAV() else { return }
        do {
            let player = try AVAudioPlayer(data: silentData)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            self.silentPlayer = player
        } catch {
            print("Lỗi khởi tạo silent player: \(error)")
        }
    }
    
    func stopBackgroundMode() {
        silentPlayer?.stop()
        silentPlayer = nil
    }
    
    private func createSilentWAV() -> Data? {
        let sampleRate: Int32 = 8000
        let channels: Int16 = 1
        let bps: Int16 = 16
        let seconds = 2
        let byteRate = sampleRate * Int32(channels) * Int32(bps / 8)
        let blockAlign = channels * (bps / 8)
        let dataSize = byteRate * Int32(seconds)
        
        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        var totalSizeLE = (dataSize + 36).littleEndian
        header.append(Data(bytes: &totalSizeLE, count: 4))
        header.append(contentsOf: "WAVEfmt ".utf8)
        var fmtSizeLE: Int32 = 16
        header.append(Data(bytes: &fmtSizeLE, count: 4))
        var formatLE: Int16 = 1 // PCM
        header.append(Data(bytes: &formatLE, count: 2))
        var channelsLE = channels.littleEndian
        header.append(Data(bytes: &channelsLE, count: 2))
        var sampleRateLE = sampleRate.littleEndian
        header.append(Data(bytes: &sampleRateLE, count: 4))
        var byteRateLE = byteRate.littleEndian
        header.append(Data(bytes: &byteRateLE, count: 4))
        var blockAlignLE = blockAlign.littleEndian
        header.append(Data(bytes: &blockAlignLE, count: 2))
        var bpsLE = bps.littleEndian
        header.append(Data(bytes: &bpsLE, count: 2))
        header.append(contentsOf: "data".utf8)
        var dataSizeLE = dataSize.littleEndian
        header.append(Data(bytes: &dataSizeLE, count: 4))
        
        let silence = Data(repeating: 0, count: Int(dataSize))
        header.append(silence)
        return header
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // delegate
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { isSpeaking = true }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        if !s.isSpeaking { isSpeaking = false; isPaused = false; updateNowPlaying(playing: false) }
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

// ======================== Kiểu giọng (preset cao độ / tốc độ) ========================
struct VoiceStyle: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let pitch: Float
    let rate: Float
}

let kVoiceStyles: [VoiceStyle] = [
    .init(id: "normal",   label: "Thường",    icon: "person.wave.2",        pitch: 1.0,  rate: 0.50),
    .init(id: "anime_f",  label: "Anime nữ",  icon: "sparkles",             pitch: 1.7,  rate: 0.54),
    .init(id: "anime_m",  label: "Anime nam", icon: "bolt.fill",            pitch: 0.75, rate: 0.52),
    .init(id: "child",    label: "Trẻ em",    icon: "figure.child",         pitch: 1.9,  rate: 0.50),
    .init(id: "warm",     label: "Trầm ấm",   icon: "moon.zzz.fill",        pitch: 0.82, rate: 0.46),
    .init(id: "fast",     label: "Nhanh",     icon: "hare.fill",            pitch: 1.05, rate: 0.60),
    .init(id: "slow",     label: "Chậm rõ",   icon: "tortoise.fill",        pitch: 1.0,  rate: 0.40),
    .init(id: "robot",    label: "Robot",     icon: "cpu",                  pitch: 0.6,  rate: 0.48),
    // Preset trầm tự nhiên: pitch thấp, tốc độ vừa
    .init(id: "tiktok_deep", label: "Trầm TikTok", icon: "music.note.tv.fill", pitch: 0.80, rate: 0.52),
]

// ======================== Preset tông giọng ElevenLabs ========================
struct ElevenTonePreset: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let stability: Double       // 0.0 (phong phú/linh hoạt) → 1.0 (ổn định/đơ)
    let similarityBoost: Double // 0.0 → 1.0 (bám sát giọng gốc)
    let style: Double           // 0.0 → 1.0 (cảm xúc/ngữ điệu)
    let speakerBoost: Bool
}

let kElevenTonePresets: [ElevenTonePreset] = [
    // Xu hướng TikTok — giọng đọc bình luận live điển hình
    .init(id: "tiktok_calm",   label: "TikTok Nhẹ",   icon: "music.note.tv.fill",
          stability: 0.50, similarityBoost: 0.85, style: 0.25, speakerBoost: true),
    .init(id: "tiktok_hype",   label: "TikTok Hype",  icon: "bolt.fill",
          stability: 0.28, similarityBoost: 0.88, style: 0.65, speakerBoost: true),
    .init(id: "tiktok_deep",   label: "Trầm sâu",     icon: "waveform.path.ecg",
          stability: 0.60, similarityBoost: 0.92, style: 0.10, speakerBoost: true),
    .init(id: "tiktok_warm",   label: "Ấm áp",        icon: "moon.zzz.fill",
          stability: 0.55, similarityBoost: 0.80, style: 0.35, speakerBoost: true),
    .init(id: "tiktok_clear",  label: "Rõ ràng",      icon: "speaker.wave.3.fill",
          stability: 0.72, similarityBoost: 0.95, style: 0.05, speakerBoost: true),
    .init(id: "tiktok_emote",  label: "Cảm xúc",      icon: "heart.fill",
          stability: 0.22, similarityBoost: 0.82, style: 0.80, speakerBoost: true),
]

// ======================== Giao diện ========================
struct TTSView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var tts = TTSEngine()

    @State private var freeText = ""
    @State private var personName = ""
    @State private var content = ""
    @State private var selectedEvent = "gift"
    @State private var search = ""
    private let previewSynth = AVSpeechSynthesizer()

    // ----- Dịch tự động sang tiếng Việt + lọc giọng -----
    @State private var translateToVi = true
    @State private var onlyVietnameseVoices = false

    // ----- TikTok Live: tự động đọc bình luận (như TikFinity) -----
    @State private var tiktokId = ""
    @State private var liveConnected = false
    @State private var liveStatus = ""
    @State private var liveError: String?
    @State private var lastEventId = 0
    @State private var pollTask: Task<Void, Never>?
    @State private var readTypes: Set<String> = ["comment", "gift", "follow", "share", "join"]
    @State private var liveFeed: [TikTokLiveEvent] = []

    // ----- Cấu hình câu phát (greetings) -----
    @State private var templateJoin = UserDefaults.standard.string(forKey: "tts_event_template_join") ?? "Chào mừng {name} đã vào phòng"
    @State private var templateGift = UserDefaults.standard.string(forKey: "tts_event_template_gift") ?? "Cảm ơn {name} đã tặng {content}"
    @State private var templateComment = UserDefaults.standard.string(forKey: "tts_event_template_comment") ?? "{name} bình luận: {content}"
    @State private var templateFollow = UserDefaults.standard.string(forKey: "tts_event_template_follow") ?? "Cảm ơn {name} đã theo dõi"
    @State private var templateShare = UserDefaults.standard.string(forKey: "tts_event_template_share") ?? "Cảm ơn {name} đã chia sẻ live"

    // Cache danh sách giọng 1 lần khi mở app (speechVoices() rất nặng — tránh gọi mỗi lần render gây lag/đứng)
    private static let cachedVoices: [AVSpeechSynthesisVoice] =
        AVSpeechSynthesisVoice.speechVoices().sorted { ($0.language, $0.name) < ($1.language, $1.name) }
    private static let cachedVietnameseCount: Int =
        cachedVoices.filter { $0.language.hasPrefix("vi") }.count

    private var voices: [AVSpeechSynthesisVoice] {
        var all = Self.cachedVoices
        if onlyVietnameseVoices {
            all = all.filter { $0.language.hasPrefix("vi") }
        }
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.language.localizedCaseInsensitiveContains(search)
        }
    }

    private var vietnameseVoiceCount: Int { Self.cachedVietnameseCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    KHeroHeader(icon: "speaker.wave.2.fill",
                                title: "Đọc văn bản",
                                subtitle: "TTS · đọc bình luận TikTok Live · chạy nền")

                    // ----- TikTok Live: tự động đọc bình luận -----
                    section("TikTok Live — tự động đọc bình luận") {
                        HStack {
                            Image(systemName: "music.note.tv.fill").foregroundStyle(.pink)
                            textField("ID / @username TikTok hoặc link LIVE", $tiktokId)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        // Chọn loại sự kiện sẽ đọc
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(kLiveEvents) { e in
                                    let on = readTypes.contains(e.id)
                                    Button {
                                        if on { readTypes.remove(e.id) } else { readTypes.insert(e.id) }
                                    } label: {
                                        Label(e.label, systemImage: on ? "checkmark.circle.fill" : e.icon)
                                            .font(.caption)
                                            .padding(.horizontal, 10).padding(.vertical, 7)
                                            .background(on ? Theme.accent.opacity(0.25) : Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        HStack {
                            if liveConnected {
                                Button(role: .destructive) { disconnectLive() } label: {
                                    Label("Ngắt kết nối", systemImage: "stop.circle.fill").frame(maxWidth: .infinity)
                                }.buttonStyle(.bordered)
                            } else {
                                Button { connectLive() } label: {
                                    Label("Kết nối & đọc", systemImage: "play.circle.fill").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(tiktokId.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }

                        HStack(spacing: 6) {
                            Circle().fill(liveStatusColor).frame(width: 8, height: 8)
                            Text(liveStatusText).font(.caption).foregroundStyle(.secondary)
                        }
                        if let liveError {
                            Text(liveError).font(.caption2).foregroundStyle(.red)
                        }

                        if !liveFeed.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(liveFeed.suffix(12).reversed()) { ev in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: kLiveEvents.first { $0.id == ev.type }?.icon ?? "text.bubble")
                                            .font(.caption2).foregroundStyle(Theme.accent)
                                        Text(renderLive(ev)).font(.caption2)
                                        Spacer()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Text("Nhập ID người đang LIVE → app tự đọc bình luận/quà bằng giọng đã chọn. Tiếp tục đọc khi khoá màn hình.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    // ----- Cấu hình câu phát (greetings) -----
                    section("Cấu hình câu phát (Greetings & Alerts)") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Hỗ trợ {name} để chèn tên người và {content} để chèn tên quà/bình luận.")
                                .font(.caption2).foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lời chào người vào phòng (Welcome):").font(.caption).bold()
                                textField("Chào mừng {name} đã vào phòng", $templateJoin)
                                    .onChange(of: templateJoin) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "tts_event_template_join")
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cảm ơn tặng quà (Gift):").font(.caption).bold()
                                textField("Cảm ơn {name} đã tặng {content}", $templateGift)
                                    .onChange(of: templateGift) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "tts_event_template_gift")
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Đọc bình luận (Comment):").font(.caption).bold()
                                textField("{name} bình luận: {content}", $templateComment)
                                    .onChange(of: templateComment) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "tts_event_template_comment")
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cảm ơn theo dõi (Follow):").font(.caption).bold()
                                textField("Cảm ơn {name} đã theo dõi", $templateFollow)
                                    .onChange(of: templateFollow) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "tts_event_template_follow")
                                    }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cảm ơn chia sẻ (Share):").font(.caption).bold()
                                textField("Cảm ơn {name} đã chia sẻ live", $templateShare)
                                    .onChange(of: templateShare) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "tts_event_template_share")
                                    }
                            }
                        }
                    }

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
                            speakTranslated(renderEvent())
                        } label: {
                            Label("Đọc thông báo", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(personName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Text("Xem trước: \(renderEvent())").font(.caption2).foregroundStyle(.secondary)
                    }

                    // ----- Đọc văn bản tự do -----
                    section("Đọc văn bản (tự dịch sang tiếng Việt)") {
                        TextEditor(text: $freeText)
                            .font(.body).frame(minHeight: 110)
                            .padding(6).background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button { speakTranslated(freeText) } label: {
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
                        Button { tts.skipCurrent() } label: {
                            Label("Bỏ qua", systemImage: "forward.end.fill")
                        }.buttonStyle(.bordered).disabled(!tts.isSpeaking)
                        Spacer()
                        Button(role: .destructive) { tts.stop() } label: {
                            Label("Dừng", systemImage: "stop.fill")
                        }.buttonStyle(.bordered).disabled(!tts.isSpeaking && !tts.isPaused)
                    }
                    if tts.pendingCount > 0 {
                        Text("Đang chờ đọc: \(tts.pendingCount) đoạn")
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    // ----- Động cơ & Tinh chỉnh giọng -----
                    section("Thiết lập Động cơ giọng nói") {
                        Text("Động cơ").font(.caption).foregroundStyle(.secondary)
                        Picker("Động cơ", selection: $tts.engineType) {
                            ForEach(TTSEngine.EngineType.allCases) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)
                        
                        Toggle(isOn: $translateToVi) {
                            Label("Tự dịch sang tiếng Việt khi đọc", systemImage: "character.bubble")
                                .font(.subheadline)
                        }.tint(Theme.accent)

                        Text("Kiểu giọng (Chỉ dành cho iOS · Siri · Google — không áp dụng cho ElevenLabs)").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(kVoiceStyles) { s in
                                    let on = (tts.pitch == s.pitch && tts.rate == s.rate)
                                    Button { tts.pitch = s.pitch; tts.rate = s.rate } label: {
                                        Label(s.label, systemImage: s.icon).font(.caption)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(on ? Theme.accent.opacity(0.25) : Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        slider("Tốc độ", value: $tts.rate,
                               range: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
                        slider("Cao độ", value: $tts.pitch, range: 0.5...2.0)
                        slider("Âm lượng", value: $tts.volume, range: 0...1)

                        // ElevenLabs — đọc tiếng Việt
                        if tts.engineType == .elevenlabs {
                            Divider().padding(.vertical, 4)

                            // --- Chọn tông giọng ElevenLabs ---
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tông giọng ElevenLabs")
                                    .font(.caption).foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(kElevenTonePresets) { tone in
                                            let on = tts.elevenToneId == tone.id
                                            Button { tts.elevenToneId = tone.id } label: {
                                                Label(tone.label, systemImage: tone.icon)
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                                    .background(on
                                                        ? Color.green.opacity(0.30)
                                                        : Color(.secondarySystemBackground))
                                                    .foregroundStyle(on ? .green : .primary)
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule().stroke(on ? Color.green : Color.clear, lineWidth: 1.5)
                                                    )
                                            }.buttonStyle(.plain)
                                        }
                                    }.padding(.vertical, 2)
                                }
                                Text("Chỉ áp dụng khi dùng ElevenLabs API key. Mỗi tông thay đổi cách đọc tiếng Việt (trầm, cảm xúc, rõ ràng…).")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }

                            Divider().padding(.vertical, 4)

                            // ---- Nhập Voice ID ----
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Voice ID")
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                TextField("Dán Voice ID từ ElevenLabs vào đây", text: $tts.elevenVoiceId)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onSubmit { tts.fetchElevenVoiceName(tts.elevenVoiceId) }
                                if !tts.elevenVoiceName.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.wave.2.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        Text("Giọng: \(tts.elevenVoiceName)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.green)
                                    }
                                } else if !tts.elevenVoiceId.trimmingCharacters(in: .whitespaces).isEmpty {
                                    HStack(spacing: 6) {
                                        ProgressView().scaleEffect(0.7)
                                        Text("Đang lấy tên giọng…")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Text("Vào elevenlabs.io → Voices → chép Voice ID dán vào đây. Tên giọng sẽ tự hiện sau khi nhập.")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }

                            Divider().padding(.vertical, 4)
                            NavigationLink {
                                ElevenLabsKeyView(elevenKey: $tts.elevenKey, elevenVoiceId: $tts.elevenVoiceId, elevenVoiceName: $tts.elevenVoiceName)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: tts.elevenKey.isEmpty
                                          ? "key.slash.fill" : "key.fill")
                                        .foregroundStyle(tts.elevenKey.isEmpty ? .orange : .green)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Cấu hình giọng ElevenLabs")
                                            .font(.subheadline.bold())
                                        Text(tts.elevenKey.isEmpty
                                             ? "Chưa có key — nhấn để thiết lập"
                                             : "✓ API key đã lưu (Keychain)")
                                            .font(.caption2)
                                            .foregroundStyle(tts.elevenKey.isEmpty ? .orange : .green)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // ----- Chọn giọng -----
                    if tts.engineType == .system {
                        section("Giọng đọc hệ thống (\(Self.cachedVoices.count) giọng · \(vietnameseVoiceCount) tiếng Việt)") {
                            Toggle(isOn: $onlyVietnameseVoices) {
                                Label("Chỉ hiện giọng tiếng Việt", systemImage: "flag.fill").font(.subheadline)
                            }.tint(Theme.accent)
                            textField("Tìm theo tên / ngôn ngữ (vd: vi, English)", $search)
                            VStack(spacing: 0) {
                                ForEach(voices, id: \.identifier) { v in
                                    HStack {
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
                                            }
                                        }.buttonStyle(.plain)
                                        Button {
                                            let u = AVSpeechUtterance(string: "Xin chào, đây là giọng đọc thử nghiệm.")
                                            u.voice = v
                                            u.rate = tts.rate
                                            previewSynth.speak(u)
                                        } label: {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundStyle(.secondary)
                                        }.buttonStyle(.plain)
                                    }.padding(.vertical, 6)
                                    Divider()
                                }
                            }
                            Text("Muốn thêm giọng tự nhiên hơn: iOS → Cài đặt → Trợ năng → Nội dung nói → Giọng nói → tải thêm.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Đọc (TTS)")
        }
    }

    // ----- TikTok Live helpers -----
    private var liveStatusText: String {
        if !liveConnected && liveStatus.isEmpty { return "Chưa kết nối" }
        switch liveStatus {
        case "connecting": return "Đang kết nối tới phòng LIVE..."
        case "connected":  return "Đã kết nối · đang đọc bình luận"
        case "ended":      return "Phiên LIVE đã kết thúc"
        case "error":      return "Lỗi kết nối"
        default:           return liveConnected ? "Đang đọc" : "Chưa kết nối"
        }
    }
    private var liveStatusColor: Color {
        switch liveStatus {
        case "connected": return .green
        case "connecting": return .orange
        case "error", "ended": return .red
        default: return .gray
        }
    }

    private func renderLive(_ ev: TikTokLiveEvent) -> String {
        let template: String
        switch ev.type {
        case "join": template = templateJoin
        case "gift": template = templateGift
        case "comment": template = templateComment
        case "follow": template = templateFollow
        case "share": template = templateShare
        default: template = "{name} bình luận: {content}"
        }
        let name = ev.name.isEmpty ? "bạn" : ev.name
        return template
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{content}", with: ev.content)
            .trimmingCharacters(in: .whitespaces)
    }

    private func connectLive() {
        let id = tiktokId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        liveError = nil; liveFeed = []; lastEventId = 0
        liveStatus = "connecting"; liveConnected = true
        
        tts.startBackgroundMode() // Giữ app chạy ngầm bằng silent audio loop
        
        Task {
            do {
                let s = try await store.api.tiktokLiveConnect(username: id)
                liveStatus = s.status
                startPolling(id)
            } catch {
                liveError = error.localizedDescription
                liveStatus = "error"; liveConnected = false
                tts.stopBackgroundMode()
            }
        }
    }

    private func startPolling(_ id: String) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                do {
                    let r = try await store.api.tiktokLiveEvents(username: id, after: lastEventId)
                    liveStatus = r.status
                    if let e = r.error { liveError = e }
                    for ev in r.events {
                        liveFeed.append(ev)
                        if readTypes.contains(ev.type) {
                            let text = await liveSpeechText(ev)
                            tts.speak(text)
                        }
                    }
                    if liveFeed.count > 120 { liveFeed.removeFirst(liveFeed.count - 120) }
                    lastEventId = r.last
                    if r.status == "ended" || r.status == "error" { break }
                } catch {
                    // bỏ qua lỗi mạng tạm thời, thử lại ở vòng sau
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func disconnectLive() {
        pollTask?.cancel(); pollTask = nil
        liveConnected = false
        liveStatus = ""
        tts.stopBackgroundMode() // Tắt chạy ngầm
        let id = tiktokId.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { try? await store.api.tiktokLiveDisconnect(username: id) }
    }

    /// Dịch nội dung 1 sự kiện live sang tiếng Việt (giữ tên người + mẫu câu Việt), rồi trả về câu để đọc.
    private func liveSpeechText(_ ev: TikTokLiveEvent) async -> String {
        var content = ev.content
        if translateToVi, !content.isEmpty {
            if let tr = try? await store.api.translate(text: content), !tr.text.isEmpty {
                content = tr.text
            }
        }
        let template: String
        switch ev.type {
        case "join": template = templateJoin
        case "gift": template = templateGift
        case "comment": template = templateComment
        case "follow": template = templateFollow
        case "share": template = templateShare
        default: template = "{name} bình luận: {content}"
        }
        let name = ev.name.isEmpty ? "bạn" : ev.name
        return template
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{content}", with: content)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Đọc 1 đoạn text: nếu bật dịch thì dịch sang tiếng Việt trước rồi mới đọc.
    private func speakTranslated(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if translateToVi {
            Task {
                if let tr = try? await store.api.translate(text: t), !tr.text.isEmpty {
                    tts.speak(tr.text)
                } else {
                    tts.speak(t)
                }
            }
        } else {
            tts.speak(t)
        }
    }

    // ----- helpers -----
    private func renderEvent() -> String {
        let template: String
        switch selectedEvent {
        case "join": template = templateJoin
        case "gift": template = templateGift
        case "comment": template = templateComment
        case "follow": template = templateFollow
        case "share": template = templateShare
        default: template = "{name} bình luận: {content}"
        }
        let name = personName.isEmpty ? "bạn" : personName
        return template
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

