import SwiftUI
import PhotosUI
import Vision
import CoreImage.CIFilterBuiltins

// ======================== Công cụ ảnh: tách nền · nén · làm nét ========================
struct ImageToolsView: View {
    @State private var picker: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var result: UIImage?
    @State private var mode = 0   // 0 tách nền, 1 nén, 2 làm nét
    @State private var quality = 0.5
    @State private var processing = false
    @State private var info: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $picker, matching: .images) {
                    Label(original == nil ? "Chọn ảnh" : "Đổi ảnh khác", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let original {
                    Picker("", selection: $mode) {
                        Text("Tách nền").tag(0)
                        Text("Nén ảnh").tag(1)
                        Text("Làm nét").tag(2)
                    }.pickerStyle(.segmented)

                    if mode == 1 {
                        HStack { Text("Chất lượng"); Spacer(); Text("\(Int(quality*100))%") }
                        Slider(value: $quality, in: 0.1...0.9)
                    }

                    Button { Task { await run(original) } } label: {
                        HStack {
                            if processing { ProgressView().tint(.white) }
                            Text(processing ? "Đang xử lý..." : "Xử lý ảnh").bold()
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(processing ? Color.gray : Theme.purple).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.disabled(processing)

                    // Xem trước
                    HStack(alignment: .top, spacing: 10) {
                        VStack { Text("Gốc").font(.caption2).foregroundStyle(.secondary)
                            Image(uiImage: original).resizable().scaledToFit()
                                .frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        if let result {
                            VStack { Text("Kết quả").font(.caption2).foregroundStyle(.secondary)
                                Image(uiImage: result).resizable().scaledToFit()
                                    .frame(maxHeight: 200)
                                    .background(checkerboard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10)) }
                        }
                    }

                    if let info { Text(info).font(.caption).foregroundStyle(.green) }
                    if let result {
                        ShareLink(item: Image(uiImage: result),
                                  preview: SharePreview("kenios_image", image: Image(uiImage: result))) {
                            Label("Lưu / tải về", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }.padding()
        }
        .navigationTitle("Công cụ ảnh")
        .onChange(of: picker) { _ in loadPicked() }
    }

    private var checkerboard: some View {
        Color.gray.opacity(0.15)
    }

    private func loadPicked() {
        guard let picker else { return }
        Task {
            if let data = try? await picker.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                original = img; result = nil; info = nil; error = nil
            }
        }
    }

    private func run(_ img: UIImage) async {
        processing = true; error = nil; info = nil; result = nil
        await Task.yield()
        switch mode {
        case 0:
            if #available(iOS 17.0, *) {
                if let r = Self.removeBackground(img) { result = r; info = "Đã tách nền (PNG trong suốt)." }
                else { error = "Không tách được nền (ảnh không có chủ thể rõ)." }
            } else { error = "Tách nền cần iOS 17 trở lên." }
        case 1:
            if let data = img.jpegData(compressionQuality: quality), let r = UIImage(data: data) {
                result = r; info = "Đã nén còn \(humanSize(data.count))."
            } else { error = "Không nén được ảnh." }
        default:
            if let r = Self.sharpen(img) { result = r; info = "Đã làm nét ảnh." }
            else { error = "Không làm nét được." }
        }
        processing = false
    }

    @available(iOS 17.0, *)
    static func removeBackground(_ input: UIImage) -> UIImage? {
        guard let cg = input.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let req = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([req])
            guard let res = req.results?.first else { return nil }
            let buf = try res.generateMaskedImage(ofInstances: res.allInstances,
                                                   from: handler, croppedToInstancesExtent: false)
            let ci = CIImage(cvPixelBuffer: buf)
            let ctx = CIContext()
            if let out = ctx.createCGImage(ci, from: ci.extent) { return UIImage(cgImage: out) }
        } catch { return nil }
        return nil
    }

    static func sharpen(_ img: UIImage) -> UIImage? {
        guard let cg = img.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let f = CIFilter.unsharpMask()
        f.inputImage = ci; f.radius = 2.5; f.intensity = 0.8
        let ctx = CIContext()
        guard let out = f.outputImage, let cgOut = ctx.createCGImage(out, from: ci.extent) else { return nil }
        return UIImage(cgImage: cgOut)
    }
}
