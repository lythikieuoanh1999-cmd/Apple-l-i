import SwiftUI

// ======================== Trợ lý rảnh tay (voice → AI streaming → đọc to) ========================
struct AssistantView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var recorder = VoiceRecorder()
    @StateObject private var tts = TTSEngine()

    @State private var provider = ""
    @State private var transcript = ""     // câu hỏi
    @State private var answer = ""         // câu trả lời (hiện dần)
    @State private var streaming = false
    @State private var transcribing = false
    @State private var speakReply = true
    @State private var error: String?
    @State private var convId: Int?

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
                Text(answer.isEmpty ? "Bấm micro để hỏi — AI trả lời hiện dần và tự đọc to." : answer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(answer.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !transcript.isEmpty {
                Text("Bạn: \(transcript)").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                TextField("Hoặc gõ câu hỏi...", text: $transcript)
                    .padding(10).background(Color(.secondarySystemBackground)).clipShape(Capsule())
                Button { Task { await ask() } } label: { Image(systemName: "paperplane.fill") }
                    .disabled(streaming || transcript.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button { Task { await toggleVoice() } } label: {
                ZStack {
                    Circle().fill(recorder.isRecording ? Color.red : Theme.accent).frame(width: 76, height: 76)
                    if transcribing { ProgressView().tint(.white) }
                    else { Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill").font(.title).foregroundStyle(.white) }
                }
            }
            Text(recorder.isRecording ? "Đang nghe... bấm để dừng"
                 : (streaming ? "AI đang trả lời..." : "Bấm để nói"))
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Toggle("Đọc to câu trả lời", isOn: $speakReply).font(.caption)
                if tts.isSpeaking {
                    Button { tts.stop() } label: { Label("Dừng đọc", systemImage: "stop.fill").font(.caption) }
                }
            }

            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding()
        .navigationTitle("Trợ lý rảnh tay")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if provider.isEmpty {
                provider = store.configuredKeys.first
                    ?? store.providers.first(where: { $0.free })?.id
                    ?? store.providers.first?.id ?? "gemini"
            }
        }
    }

    private func toggleVoice() async {
        if recorder.isRecording {
            guard let data = recorder.stop() else { return }
            transcribing = true; error = nil
            do {
                let r = try await store.api.transcribe(provider: "openai",
                                                       audioBase64: data.base64EncodedString(),
                                                       mime: "audio/m4a")
                transcript = r.text
                transcribing = false
                if !transcript.trimmingCharacters(in: .whitespaces).isEmpty { await ask() }
            } catch {
                self.error = error.localizedDescription
                transcribing = false
            }
        } else {
            recorder.requestPermission { granted in
                guard granted else { self.error = "Cần quyền micro."; return }
                do { try recorder.start() } catch { self.error = error.localizedDescription }
            }
        }
    }

    private func ask() async {
        let q = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !provider.isEmpty else { return }
        tts.stop()
        answer = ""; streaming = true; error = nil
        do {
            let cid = try await store.api.chatStream(provider: provider, message: q,
                                                     conversationId: convId) { delta in
                Task { @MainActor in answer += delta }
            }
            convId = cid
            if speakReply && !answer.isEmpty { tts.speak(answer) }
        } catch { self.error = error.localizedDescription }
        streaming = false
    }
}
