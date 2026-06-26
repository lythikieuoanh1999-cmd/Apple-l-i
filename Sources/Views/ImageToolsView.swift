import SwiftUI
import PhotosUI
import Vision
import Photos
import CoreImage.CIFilterBuiltins

// ======================== Công cụ ảnh: tách nền · cải thiện (nét + độ phân giải) · nén ========================
// Hỗ trợ CHỌN NHIỀU ẢNH xử lý cùng lúc.
struct ImageToolsView: View {
    private static let ctx = CIContext(options: [.useSoftwareRenderer: false])

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var originals: [UIImage] = []
    @State private var results: [UIImage] = []
    @State private var mode = 0            // 0 tách nền, 1 cải thiện, 2 nén
    @State private var scaleIdx = 1        // 0 giữ nguyên, 1 x2, 2 x4
    @State private var sharpen = 0.7
    @State private var quality = 0.6
    @State private var processing = false
    @State private var progress = ""
    @State private var info: String?
    @State private var error: String?
    @State private var saveMsg: String?

    private let scales: [(String, CGFloat)] = [("Giữ nguyên", 1), ("x2 · nét hơn", 2), ("x4 · HD", 4)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    Label(originals.isEmpty ? "Chọn ảnh (được nhiều ảnh)" : "Đã chọn \(originals.count) ảnh — đổi",
                          systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !originals.isEmpty {
                    Picker("", selection: $mode) {
                        Text("Tách nền").tag(0)
                        Text("Cải thiện").tag(1)
                        Text("Nén ảnh").tag(2)
                    }.pickerStyle(.segmented)

                    if mode == 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Độ phân giải").font(.caption).foregroundStyle(.secondary)
                            Picker("Độ phân giải", selection: $scaleIdx) {
                                ForEach(0..<scales.count, id: \.self) { Text(scales[$0].0).tag($0) }
                            }.pickerStyle(.segmented)
                            HStack { Text("Độ nét"); Spacer(); Text(String(format: "%.1f", sharpen)) }.font(.caption)
                            Slider(value: $sharpen, in: 0.2...1.5)
                        }.padding().kCard(12)
                    } else if mode == 2 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("Chất lượng"); Spacer(); Text("\(Int(quality*100))%") }.font(.caption)
                            Slider(value: $quality, in: 0.1...0.9)
                        }.padding().kCard(12)
                    } else {
                        Text("Tách nền dùng AI nhận chủ thể, cắt sạch viền nền (cần iOS 17+).")
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    Button { Task { await runAll() } } label: {
                        HStack {
                            if processing { ProgressView().tint(.white) }
                            Text(processing ? (progress.isEmpty ? "Đang xử lý..." : progress) : "Xử lý \(originals.count) ảnh").bold()
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(processing ? Color.gray : Theme.purple).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.disabled(processing)

                    if let info { Text(info).font(.caption).foregroundStyle(.green) }

                    if !results.isEmpty {
                        Button { Task { await saveAll() } } label: {
                            Label("Lưu tất cả vào Thư viện máy", systemImage: "square.and.arrow.down.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(Theme.accent.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if let saveMsg { Text(saveMsg).font(.caption).foregroundStyle(saveMsg.contains("✓") ? .green : .red) }

                        ForEach(Array(results.enumerated()), id: \.offset) { idx, img in
                            VStack(spacing: 8) {
                                Image(uiImage: img).resizable().scaledToFit()
                                    .frame(maxHeight: 240)
                                    .background(checker)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                ShareLink(item: Image(uiImage: img),
                                          preview: SharePreview("kenios_\(idx+1)", image: Image(uiImage: img))) {
                                    Label("Lưu / chia sẻ ảnh \(idx+1)", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }.padding()
        }
        .navigationTitle("Công cụ ảnh")
        .onChange(of: pickerItems) { _ in loadPicked() }
    }

    private var checker: some View { Color.gray.opacity(0.15) }

    private func loadPicked() {
        Task {
            var imgs: [UIImage] = []
            for it in pickerItems {
                if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    imgs.append(img)
                }
            }
            originals = imgs; results = []; info = nil; error = nil; saveMsg = nil
        }
    }

    private func runAll() async {
        processing = true; error = nil; info = nil; results = []; saveMsg = nil
        await Task.yield()
        var out: [UIImage] = []
        for (i, img) in originals.enumerated() {
            progress = "Đang xử lý \(i+1)/\(originals.count)..."
            await Task.yield()
            switch mode {
            case 0:
                if #available(iOS 17.0, *) {
                    if let r = Self.removeBackground(img) { out.append(r) }
                } else { error = "Tách nền cần iOS 17 trở lên." }
            case 1:
                if let r = Self.enhance(img, scale: scales[scaleIdx].1, sharpen: sharpen) { out.append(r) }
            default:
                if let data = img.jpegData(compressionQuality: quality), let r = UIImage(data: data) { out.append(r) }
            }
        }
        results = out
        progress = ""
        if !out.isEmpty {
            info = mode == 0 ? "Đã tách nền \(out.count) ảnh (PNG trong suốt, sạch viền)."
                : mode == 1 ? "Đã cải thiện \(out.count) ảnh."
                : "Đã nén \(out.count) ảnh."
        } else if error == nil {
            error = "Không xử lý được ảnh đã chọn."
        }
        processing = false
    }

    private func saveAll() async {
        saveMsg = nil
        let status = await withCheckedContinuation { (c: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { c.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else {
            saveMsg = "Chưa được cấp quyền lưu vào Thư viện ảnh."; return
        }
        var ok = 0
        for img in results {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                }
                ok += 1
            } catch { }
        }
        saveMsg = "Đã lưu \(ok)/\(results.count) ảnh vào máy ✓"
    }

    // MARK: - Tách nền sạch viền
    @available(iOS 17.0, *)
    static func removeBackground(_ input: UIImage) -> UIImage? {
        guard let cg = input.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let req = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([req])
            guard let res = req.results?.first else { return nil }
            let maskBuf = try res.generateScaledMaskForImage(forInstances: res.allInstances, from: handler)
            let orig = CIImage(cgImage: cg)
            var maskCI = CIImage(cvPixelBuffer: maskBuf)
            // Căn mask về đúng kích thước ảnh gốc
            if maskCI.extent.width > 0 && maskCI.extent.height > 0 {
                let sx = orig.extent.width / maskCI.extent.width
                let sy = orig.extent.height / maskCI.extent.height
                maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            }
            // Co mask ~1px để loại viền nền còn dính (chống "lem"), rồi làm mượt nhẹ
            let erode = CIFilter.morphologyMinimum(); erode.inputImage = maskCI; erode.radius = 1.2
            maskCI = (erode.outputImage ?? maskCI).cropped(to: orig.extent)
            let soft = CIFilter.gaussianBlur(); soft.inputImage = maskCI; soft.radius = 0.6
            maskCI = (soft.outputImage ?? maskCI).cropped(to: orig.extent)
            // Ghép chủ thể lên nền trong suốt theo mask
            let blend = CIFilter.blendWithMask()
            blend.inputImage = orig
            blend.backgroundImage = CIImage.empty()
            blend.maskImage = maskCI
            guard let out = blend.outputImage,
                  let cgOut = ctx.createCGImage(out, from: orig.extent) else { return nil }
            return UIImage(cgImage: cgOut)
        } catch { return nil }
    }

    // MARK: - Cải thiện: nâng độ phân giải (Lanczos) + giảm nhiễu + làm nét
    static func enhance(_ img: UIImage, scale: CGFloat, sharpen: Double) -> UIImage? {
        guard let cg = img.cgImage else { return nil }
        var ci = CIImage(cgImage: cg)
        if scale != 1.0 {
            let f = CIFilter.lanczosScaleTransform()
            f.inputImage = ci; f.scale = Float(scale); f.aspectRatio = 1.0
            ci = f.outputImage ?? ci
        }
        let nr = CIFilter.noiseReduction()
        nr.inputImage = ci; nr.noiseLevel = 0.02; nr.sharpness = 0.4
        ci = nr.outputImage ?? ci
        let um = CIFilter.unsharpMask()
        um.inputImage = ci; um.radius = 2.5; um.intensity = Float(sharpen)
        ci = um.outputImage ?? ci
        let extent = ci.extent
        guard !extent.isInfinite, let out = ctx.createCGImage(ci, from: extent) else { return nil }
        return UIImage(cgImage: out)
    }
}
