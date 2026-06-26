import SwiftUI
import CoreImage.CIFilterBuiltins

// ======================== KENIOS — Bộ công cụ tiện ích cho nội dung ========================
struct CreatorToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    KHeroHeader(icon: "square.grid.2x2.fill",
                                title: "Công cụ",
                                subtitle: "Bộ tiện ích sáng tạo · offline, nhanh gọn")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Ảnh & Video") {
                    navLink("Công cụ ảnh (tách nền · cải thiện · nén · nhiều ảnh)", "wand.and.stars", ImageToolsView())
                    navLink("Watermark chữ lên ảnh", "signature", WatermarkView())
                    navLink("Đổi đuôi ảnh (PNG ⇄ JPG)", "arrow.left.arrow.right.square", ImageConvertView())
                    navLink("Trích nhạc từ video (M4A)", "music.note", AudioExtractView())
                }
                Section("Giọng đọc") {
                    navLink("Giọng đọc nâng cao (máy + Google online)", "waveform", NewVoiceTTSView())
                }
                Section("Internet · Tin tức · Mạng xã hội") {
                    navLink("Tin tức · Thời sự · Mạng xã hội", "newspaper.fill", NewsToolsView())
                }
                Section("Văn bản & Caption") {
                    navLink("Đếm ký tự / từ", "textformat.123", CaptionCounterView())
                    navLink("Chữ kiểu (fancy)", "sparkles", FancyTextView())
                    navLink("Đổi HOA / thường", "textformat", TextCaseView())
                    navLink("Tạo hashtag", "number", HashtagGenView())
                }
                Section("Tạo & Bảo mật") {
                    navLink("Tạo mật khẩu mạnh", "key.fill", PasswordGenView())
                    navLink("Mã QR", "qrcode", QRMakerView())
                    navLink("Ngẫu nhiên (xu · xúc xắc · số)", "die.face.5", RandomView())
                }
                Section("Tính toán") {
                    navLink("Máy tính", "plus.forwardslash.minus", MiniCalcView())
                    navLink("Chuyển đổi đơn vị", "ruler", UnitConvertView())
                    navLink("Đếm ngày / tuổi", "calendar", DateDiffView())
                }
                Section("Năng suất") {
                    navLink("Ghi chú nhanh", "note.text", QuickNotesView())
                    navLink("Hẹn giờ đếm ngược", "timer", CountdownView())
                    navLink("Giờ vàng đăng bài", "clock.badge.checkmark", BestTimeView())
                }
            }
            .navigationTitle("Công cụ")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ThreeDLogoText(size: 20) } }
        }
    }

    private func navLink<V: View>(_ title: String, _ icon: String, _ dest: V) -> some View {
        NavigationLink { dest } label: { Label(title, systemImage: icon) }
    }
}

// MARK: - Đếm ký tự/từ
struct CaptionCounterView: View {
    @State private var text = ""
    var body: some View {
        Form {
            Section { TextEditor(text: $text).frame(minHeight: 160) }
            Section("Thống kê") {
                row("Ký tự", "\(text.count)")
                row("Ký tự (không dấu cách)", "\(text.filter { !$0.isWhitespace }.count)")
                row("Từ", "\(text.split { $0 == " " || $0 == "\n" }.count)")
                row("Dòng", "\(text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count)")
            }
            Section {
                Button { UIPasteboard.general.string = text } label: { Label("Copy", systemImage: "doc.on.doc") }
            }
        }.navigationTitle("Đếm caption")
    }
    private func row(_ a: String, _ b: String) -> some View {
        HStack { Text(a); Spacer(); Text(b).bold().foregroundStyle(Theme.accent) }
    }
}

// MARK: - Chữ kiểu (fancy unicode)
struct FancyTextView: View {
    @State private var text = "KENIOS"
    private let styles: [(String, (Character) -> Character)] = [
        ("𝐁𝐨𝐥𝐝", { fancy($0, base: 0x1D400, baseUpper: 0x1D400, baseLower: 0x1D41A, baseDigit: 0x1D7CE) }),
        ("𝑰𝒕𝒂𝒍𝒊𝒄", { fancy($0, base: 0x1D434, baseUpper: 0x1D434, baseLower: 0x1D44E, baseDigit: nil) }),
        ("𝙼𝚘𝚗𝚘", { fancy($0, base: 0x1D670, baseUpper: 0x1D670, baseLower: 0x1D68A, baseDigit: 0x1D7F6) }),
        ("Ⓒⓘⓡⓒⓛⓔ", { circled($0) }),
    ]
    var body: some View {
        Form {
            Section { TextField("Nhập chữ...", text: $text) }
            ForEach(styles, id: \.0) { s in
                let out = String(text.map { s.1($0) })
                Section(s.0) {
                    Text(out).font(.title3)
                    Button { UIPasteboard.general.string = out } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption) }
                }
            }
        }.navigationTitle("Chữ kiểu")
    }
    static func fancy(_ c: Character, base: Int, baseUpper: Int, baseLower: Int, baseDigit: Int?) -> Character {
        guard let a = c.asciiValue else { return c }
        if a >= 65 && a <= 90, let s = Unicode.Scalar(baseUpper + Int(a - 65)) { return Character(s) }
        if a >= 97 && a <= 122, let s = Unicode.Scalar(baseLower + Int(a - 97)) { return Character(s) }
        if let bd = baseDigit, a >= 48 && a <= 57, let s = Unicode.Scalar(bd + Int(a - 48)) { return Character(s) }
        return c
    }
    static func circled(_ c: Character) -> Character {
        guard let a = c.asciiValue else { return c }
        if a >= 65 && a <= 90, let s = Unicode.Scalar(0x24B6 + Int(a - 65)) { return Character(s) }
        if a >= 97 && a <= 122, let s = Unicode.Scalar(0x24D0 + Int(a - 97)) { return Character(s) }
        return c
    }
}

// MARK: - Đổi hoa/thường
struct TextCaseView: View {
    @State private var text = ""
    var body: some View {
        Form {
            Section { TextEditor(text: $text).frame(minHeight: 120) }
            out("CHỮ HOA", text.uppercased())
            out("chữ thường", text.lowercased())
            out("Chữ Đầu Hoa", text.capitalized)
        }.navigationTitle("Đổi kiểu chữ")
    }
    private func out(_ t: String, _ v: String) -> some View {
        Section(t) {
            Text(v.isEmpty ? "—" : v)
            Button { UIPasteboard.general.string = v } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption) }
        }
    }
}

// MARK: - Tạo hashtag
struct HashtagGenView: View {
    @State private var topic = ""
    @State private var result = ""
    private let trending = ["fyp", "xuhuong", "viral", "trending", "foryou", "tiktok", "reels", "viralvideo", "explore", "content"]
    var body: some View {
        Form {
            Section { TextField("Chủ đề (vd: nấu ăn, gym)", text: $topic) }
            Section {
                Button("Tạo hashtag") {
                    let words = topic.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
                    var tags = words.map { "#\($0)" } + words.map { "#\($0)viral" }
                    tags += trending.map { "#\($0)" }
                    result = Array(Set(tags)).prefix(30).joined(separator: " ")
                }.disabled(topic.isEmpty)
            }
            if !result.isEmpty {
                Section("Kết quả") {
                    Text(result).font(.callout)
                    Button { UIPasteboard.general.string = result } label: { Label("Copy", systemImage: "doc.on.doc") }
                }
            }
        }.navigationTitle("Hashtag")
    }
}

// MARK: - Tạo mật khẩu
struct PasswordGenView: View {
    @State private var length = 16.0
    @State private var useSymbols = true
    @State private var pwd = ""
    var body: some View {
        Form {
            Section {
                Text(pwd.isEmpty ? "—" : pwd).font(.system(.title3, design: .monospaced)).textSelection(.enabled)
                Button { UIPasteboard.general.string = pwd } label: { Label("Copy", systemImage: "doc.on.doc") }.disabled(pwd.isEmpty)
            }
            Section {
                HStack { Text("Độ dài"); Spacer(); Text("\(Int(length))") }
                Slider(value: $length, in: 6...40, step: 1)
                Toggle("Gồm ký tự đặc biệt", isOn: $useSymbols)
                Button("Tạo mật khẩu") { gen() }
            }
        }.navigationTitle("Mật khẩu").onAppear { gen() }
    }
    private func gen() {
        var chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
        if useSymbols { chars += "!@#$%^&*-_=+" }
        pwd = String((0..<Int(length)).map { _ in chars.randomElement()! })
    }
}

// MARK: - QR
struct QRMakerView: View {
    @State private var text = ""
    @State private var img: UIImage?
    var body: some View {
        Form {
            Section { TextField("Text / link...", text: $text, axis: .vertical).lineLimit(1...4) }
            Section {
                Button("Tạo QR") { img = Self.make(text) }.disabled(text.isEmpty)
                if let img {
                    Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(height: 200)
                    ShareLink(item: Image(uiImage: img), preview: SharePreview("QR", image: Image(uiImage: img))) {
                        Label("Lưu / chia sẻ", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }.navigationTitle("Mã QR")
    }
    static func make(_ s: String) -> UIImage? {
        let ctx = CIContext(); let f = CIFilter.qrCodeGenerator(); f.message = Data(s.utf8)
        guard let o = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = ctx.createCGImage(o, from: o.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Ngẫu nhiên
struct RandomView: View {
    @State private var coin = "—"; @State private var dice = 0; @State private var num = 0
    @State private var maxN = "100"
    var body: some View {
        Form {
            Section("Tung đồng xu") {
                Text(coin).font(.title2)
                Button("Tung") { coin = Bool.random() ? "Ngửa 🪙" : "Sấp 🪙" }
            }
            Section("Xúc xắc") {
                Text(dice == 0 ? "—" : "🎲 \(dice)").font(.title2)
                Button("Gieo") { dice = Int.random(in: 1...6) }
            }
            Section("Số ngẫu nhiên") {
                TextField("Tối đa", text: $maxN).keyboardType(.numberPad)
                Text("\(num)").font(.title2).foregroundStyle(Theme.accent)
                Button("Quay") { num = Int.random(in: 0...(Int(maxN) ?? 100)) }
            }
        }.navigationTitle("Ngẫu nhiên")
    }
}

// MARK: - Máy tính
struct MiniCalcView: View {
    @State private var expr = ""
    @State private var result = ""
    var body: some View {
        Form {
            Section {
                TextField("Vd: 12*3+5/2", text: $expr).keyboardType(.numbersAndPunctuation)
                Button("Tính") {
                    let e = expr.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/")
                    let ex = NSExpression(format: e)
                    if let v = ex.expressionValue(with: nil, context: nil) as? NSNumber {
                        result = "\(v)"
                    } else { result = "Lỗi biểu thức" }
                }.disabled(expr.isEmpty)
            }
            if !result.isEmpty { Section("Kết quả") { Text(result).font(.title3).bold().foregroundStyle(Theme.accent) } }
        }.navigationTitle("Máy tính")
    }
}

// MARK: - Chuyển đổi đơn vị
struct UnitConvertView: View {
    @State private var value = "1"
    @State private var kind = 0
    private let kinds = ["Độ dài (m→ft)", "Cân nặng (kg→lb)", "Nhiệt độ (°C→°F)", "Tiền (USD→VND)"]
    private func convert(_ v: Double) -> Double {
        switch kind {
        case 0: return v * 3.28084
        case 1: return v * 2.20462
        case 2: return v * 9 / 5 + 32
        default: return v * 25000
        }
    }
    var body: some View {
        Form {
            Picker("Loại", selection: $kind) { ForEach(0..<kinds.count, id: \.self) { Text(kinds[$0]).tag($0) } }
            TextField("Giá trị", text: $value).keyboardType(.decimalPad)
            Section("Kết quả") {
                Text(String(format: "%.4f", convert(Double(value) ?? 0)))
                    .font(.title3).bold().foregroundStyle(Theme.accent)
            }
        }.navigationTitle("Đổi đơn vị")
    }
}

// MARK: - Đếm ngày/tuổi
struct DateDiffView: View {
    @State private var from = Date()
    @State private var to = Date()
    private var days: Int { Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0 }
    var body: some View {
        Form {
            DatePicker("Từ ngày", selection: $from, displayedComponents: .date)
            DatePicker("Đến ngày", selection: $to, displayedComponents: .date)
            Section("Kết quả") {
                Text("\(abs(days)) ngày").font(.title3).bold().foregroundStyle(Theme.accent)
                Text("≈ \(abs(days)/365) năm \(abs(days)%365/30) tháng").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Đếm ngày")
    }
}

// MARK: - Ghi chú nhanh
struct QuickNotesView: View {
    @AppStorage("kenios_quicknote") private var note = ""
    var body: some View {
        Form {
            Section("Ghi chú (tự lưu)") { TextEditor(text: $note).frame(minHeight: 240) }
            Section {
                Button { UIPasteboard.general.string = note } label: { Label("Copy", systemImage: "doc.on.doc") }
                Button(role: .destructive) { note = "" } label: { Label("Xoá hết", systemImage: "trash") }
            }
        }.navigationTitle("Ghi chú")
    }
}

// MARK: - Hẹn giờ đếm ngược
struct CountdownView: View {
    @State private var minutes = 5
    @State private var remaining = 0
    @State private var running = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Form {
            Section {
                Text(timeStr).font(.system(size: 54, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity).foregroundStyle(running ? Theme.accent : .primary)
            }
            Section {
                Stepper("Phút: \(minutes)", value: $minutes, in: 1...180)
                HStack {
                    Button(running ? "Tạm dừng" : "Bắt đầu") {
                        if !running && remaining == 0 { remaining = minutes * 60 }
                        running.toggle()
                    }.buttonStyle(.borderedProminent)
                    Button("Đặt lại") { running = false; remaining = 0 }.buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Đếm ngược")
        .onReceive(timer) { _ in
            if running && remaining > 0 { remaining -= 1; if remaining == 0 { running = false } }
        }
    }
    private var timeStr: String {
        let s = remaining == 0 ? minutes * 60 : remaining
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Giờ vàng đăng bài
struct BestTimeView: View {
    var body: some View {
        Form {
            Section("TikTok") { Text("11:00 · 19:00 · 21:00 – 22:00") }
            Section("Facebook / Reels") { Text("12:00 – 13:00 · 18:00 – 20:00") }
            Section("YouTube") { Text("14:00 – 16:00 · 20:00 (cuối tuần)") }
            Section { Text("Khung giờ tham khảo theo giờ Việt Nam — thử nghiệm để tìm giờ hợp tệp khán giả của bạn.").font(.caption2).foregroundStyle(.secondary) }
        }.navigationTitle("Giờ vàng")
    }
}
