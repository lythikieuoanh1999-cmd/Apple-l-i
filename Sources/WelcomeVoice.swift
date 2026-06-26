import AVFoundation

/// Phát lời chào bằng giọng tiếng Việt một lần khi mở app.
enum WelcomeVoice {
    private static var spoken = false
    private static let synth = AVSpeechSynthesizer()   // giữ tham chiếu để không bị huỷ giữa chừng

    static func playOnce() {
        guard !spoken else { return }
        spoken = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let u = AVSpeechUtterance(string: "Chào mừng bạn đã đến với ứng dụng KENIOS")
            u.voice = AVSpeechSynthesisVoice(language: "vi-VN")
            u.rate = AVSpeechUtteranceDefaultSpeechRate
            u.pitchMultiplier = 1.05
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            synth.speak(u)
        }
    }
}
