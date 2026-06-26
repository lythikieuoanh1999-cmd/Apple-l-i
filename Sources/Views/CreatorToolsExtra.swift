import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

// ======================== Watermark chữ lên ảnh ========================
struct WatermarkView: View {
    @State private var picker: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var result: UIImage?
    @State private var text = "@KENIOS"
    @State private var position = 4   // 0 TL,1 TR,2 center,3 BL,4 BR
    @State private var info: String?

    private let posNames = ["Trên trái", "Trên phải", "Giữa", "Dưới trái", "Dưới phải"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $picker, matching: .images) {
                    Label(original == nil ? "Chọn ảnh" : "Đổi ảnh", systemImage: "photo")
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if original != nil {
                    TextField("Chữ watermark", text: $text)
                        .padding(12).kCard(12)
                    Picker("Vị trí", selection: $position) {
                        ForEach(0..<posNames.count, id: \.self) { Text(posNames[$0]).tag($0) }
                    }.pickerStyle(.menu)

                    Button { apply() } label: {
                        Text("Chèn watermark").bold()
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Theme.purple).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let result {
                        Image(uiImage: result).resizable().scaledToFit()
                            .frame(maxHeight: 280).clipShape(RoundedRectangle(cornerRadius: 12))
                        ShareLink(item: Image(uiImage: result),
                                  preview: SharePreview("kenios_watermark", image: Image(uiImage: result))) {
                            Label("Lưu / tải về", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                if let info { Text(info).font(.caption).foregroundStyle(.secondary) }
            }.padding()
        }
        .navigationTitle("Watermark ảnh")
        .onChange(of: picker) { _ in
            Task {
                if let d = try? await picker?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    original = img; result = nil
                }
            }
        }
    }

    private func apply() {
        guard let base = original else { return }
        let renderer = UIGraphicsImageRenderer(size: base.size)
        result = renderer.image { _ in
            base.draw(at: .zero)
            let fontSize = max(18, base.size.width * 0.06)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                .strokeColor: UIColor.black.withAlphaComponent(0.6),
                .strokeWidth: -3
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let sz = str.size()
            let m = base.size.width * 0.03
            let w = base.size.width, h = base.size.height
            let pt: CGPoint
            switch position {
            case 0: pt = CGPoint(x: m, y: m)
            case 1: pt = CGPoint(x: w - sz.width - m, y: m)
            case 2: pt = CGPoint(x: (w - sz.width)/2, y: (h - sz.height)/2)
            case 3: pt = CGPoint(x: m, y: h - sz.height - m)
            default: pt = CGPoint(x: w - sz.width - m, y: h - sz.height - m)
            }
            str.draw(at: pt)
        }
        info = "Đã chèn watermark."
    }
}

// ======================== Đổi đuôi ảnh (PNG ⇄ JPG) ========================
struct ImageConvertView: View {
    @State private var picker: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var format = 0     // 0 JPG, 1 PNG
    @State private var quality = 0.85
    @State private var outURL: URL?
    @State private var info: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $picker, matching: .images) {
                    Label(original == nil ? "Chọn ảnh" : "Đổi ảnh", systemImage: "photo")
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if let original {
                    Picker("Định dạng", selection: $format) {
                        Text("JPG").tag(0); Text("PNG").tag(1)
                    }.pickerStyle(.segmented)
                    if format == 0 {
                        HStack { Text("Chất lượng"); Spacer(); Text("\(Int(quality*100))%") }.font(.caption)
                        Slider(value: $quality, in: 0.3...1.0)
                    }
                    Image(uiImage: original).resizable().scaledToFit()
                        .frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 12))
                    Button { convert(original) } label: {
                        Text("Chuyển đổi & xuất").bold()
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Theme.purple).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if let outURL {
                        ShareLink(item: outURL) {
                            Label("Lưu / chia sẻ file", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                if let info { Text(info).font(.caption).foregroundStyle(.green) }
            }.padding()
        }
        .navigationTitle("Đổi đuôi ảnh")
        .onChange(of: picker) { _ in
            Task {
                if let d = try? await picker?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    original = img; outURL = nil
                }
            }
        }
    }

    private func convert(_ img: UIImage) {
        let data: Data?; let ext: String
        if format == 1 { data = img.pngData(); ext = "png" }
        else { data = img.jpegData(compressionQuality: quality); ext = "jpg" }
        guard let d = data else { info = "Lỗi chuyển đổi."; return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kenios_\(Int(Date().timeIntervalSince1970)).\(ext)")
        do { try d.write(to: url); outURL = url; info = "Đã xuất \(ext.uppercased()) · \(humanSize(d.count))" }
        catch { info = "Lỗi ghi file." }
    }
}

// ======================== Trích nhạc từ video (M4A) ========================
struct AudioExtractView: View {
    @State private var picker: PhotosPickerItem?
    @State private var inputURL: URL?
    @State private var exporting = false
    @State private var outURL: URL?
    @State private var info: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $picker, matching: .videos) {
                    Label(inputURL == nil ? "Chọn video" : "Đổi video", systemImage: "film")
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if inputURL != nil {
                    Button { Task { await extract() } } label: {
                        HStack {
                            if exporting { ProgressView().tint(.white) }
                            Text(exporting ? "Đang trích..." : "Trích âm thanh (M4A)").bold()
                        }
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(exporting ? Color.gray : Theme.purple).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.disabled(exporting)
                    if let outURL {
                        ShareLink(item: outURL) {
                            Label("Lưu / chia sẻ nhạc", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                if let info { Text(info).font(.caption).foregroundStyle(.green) }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding()
        }
        .navigationTitle("Trích nhạc")
        .onChange(of: picker) { _ in
            Task {
                error = nil; outURL = nil
                if let movie = try? await picker?.loadTransferable(type: EditMovie.self) {
                    inputURL = movie.url
                } else { error = "Không đọc được video." }
            }
        }
    }

    private func extract() async {
        guard let inputURL else { return }
        exporting = true; error = nil; info = nil; outURL = nil
        let asset = AVURLAsset(url: inputURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            error = "Không tạo được phiên trích."; exporting = false; return
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("kenios_audio_\(Int(Date().timeIntervalSince1970)).m4a")
        try? FileManager.default.removeItem(at: out)
        session.outputURL = out
        session.outputFileType = .m4a
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { c.resume() }
        }
        if session.status == .completed {
            outURL = out
            let attrs = try? FileManager.default.attributesOfItem(atPath: out.path)
            info = "Đã trích nhạc · \(humanSize((attrs?[.size] as? Int) ?? 0))"
        } else {
            error = "Trích thất bại: \(session.error?.localizedDescription ?? "lỗi không rõ")"
        }
        exporting = false
    }
}
