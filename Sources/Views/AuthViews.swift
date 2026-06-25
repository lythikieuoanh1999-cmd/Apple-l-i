import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?
    @State private var goRegister = false
    @State private var showConnections = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.accent)
                        .frame(width: 76, height: 76)
                        .overlay(Image(systemName: "square").font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white))
                        .padding(.top, 40)
                    Text("KENIOS").font(.title.bold())
                    Text("Multi-AI Assistant").font(.subheadline).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username").font(.caption).foregroundStyle(.secondary)
                        TextField("kenios_user", text: $username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .padding(12).background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("Mật khẩu").font(.caption).foregroundStyle(.secondary)
                        SecureField("••••••••", text: $password)
                            .padding(12).background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.padding(.horizontal)

                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }

                    Button { Task { await doLogin() } } label: {
                        HStack {
                            if loading { ProgressView().tint(.white).padding(.trailing, 6) }
                            Text("Đăng nhập").bold().frame(maxWidth: .infinity)
                        }.padding().background(Theme.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }.padding(.horizontal).disabled(loading)

                    NavigationLink("Quên mật khẩu?") { ForgotPasswordView() }
                        .font(.subheadline).foregroundStyle(Theme.accent)

                    HStack { Rectangle().frame(height: 1).opacity(0.2); Text("hoặc").font(.caption).foregroundStyle(.secondary); Rectangle().frame(height: 1).opacity(0.2) }
                        .padding(.horizontal)

                    NavigationLink { RegisterView() } label: {
                        Text("Tạo tài khoản mới").frame(maxWidth: .infinity).padding()
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.secondary.opacity(0.4)))
                    }.padding(.horizontal)

                    if store.baseURL.isEmpty {
                        NavigationLink { ServerSetupView() } label: {
                            HStack {
                                Image(systemName: "globe").foregroundStyle(.orange)
                                Text("Chưa có máy chủ — bấm để kết nối").font(.caption)
                            }
                            .padding().frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }.padding(.horizontal)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "globe").foregroundStyle(Theme.accent)
                            VStack(alignment: .leading) {
                                Text("Máy chủ \(store.serverType)").font(.caption).foregroundStyle(.secondary)
                                Text(store.baseURL).font(.caption).foregroundStyle(Theme.accent).lineLimit(1)
                            }
                            Spacer()
                            Button("Đổi") { showConnections = true }.font(.caption)
                        }
                        .padding().background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
                    }
                }
            }
            .sheet(isPresented: $showConnections) { ConnectionsView() }
        }
    }

    private func doLogin() async {
        loading = true; error = nil
        do {
            let resp = try await store.api.login(username, password)
            store.setAuth(resp)
            await store.loadProviders(); await store.loadKeys()
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct RegisterView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var loading = false
    @State private var error: String?

    // OTP — mã xác nhận email
    @State private var codeSent = false
    @State private var code = ""
    @State private var sendingCode = false
    @State private var otpInfo: String?

    private var emailValid: Bool { email.contains("@") && email.contains(".") }

    var body: some View {
        Form {
            Section("Tạo tài khoản") {
                TextField("Username * (≥3 ký tự)", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Mật khẩu * (≥6 ký tự)", text: $password)
                TextField("Email (để nhận mã xác nhận)", text: $email)
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                TextField("Số điện thoại (tuỳ chọn)", text: $phone).keyboardType(.phonePad)
            }

            // Xác nhận email bằng mã (OTP)
            if emailValid {
                Section("Xác nhận email") {
                    Button {
                        Task { await sendCode() }
                    } label: {
                        HStack {
                            if sendingCode { ProgressView().padding(.trailing, 6) }
                            Text(codeSent ? "Gửi lại mã" : "Gửi mã xác nhận")
                        }
                    }.disabled(sendingCode)

                    if codeSent {
                        TextField("Nhập mã 6 số", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    if let otpInfo {
                        Text(otpInfo).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            Section {
                Button { Task { await doRegister() } } label: {
                    HStack { if loading { ProgressView().padding(.trailing, 6) }; Text("Tạo tài khoản") }
                }
                .disabled(loading || (emailValid && (!codeSent || code.count < 4)))
            }
            if emailValid && !codeSent {
                Text("Hãy bấm \"Gửi mã xác nhận\" và nhập mã trong hộp thư trước khi tạo tài khoản.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Đăng ký")
    }

    private func sendCode() async {
        sendingCode = true; error = nil; otpInfo = nil
        do {
            let r = try await store.api.sendOtp(email: email)
            codeSent = true
            switch r.channel {
            case "external": otpInfo = "Đã gửi mã tới \(email). Kiểm tra hộp thư (cả mục Spam)."
            case "internal": otpInfo = "Đã gửi mã vào hộp thư KenMail \(email)."
            default:
                otpInfo = r.hint ?? "Chưa gửi được mã. Kiểm tra cấu hình email trên máy chủ."
            }
            if let dbg = r.debugCode { otpInfo = "Mã (chế độ thử): \(dbg)" }
        } catch { self.error = error.localizedDescription }
        sendingCode = false
    }

    private func doRegister() async {
        loading = true; error = nil
        do {
            let resp = try await store.api.register(username, password, email: email, phone: phone,
                                                    code: emailValid ? code : nil)
            store.setAuth(resp); await store.loadProviders(); dismiss()
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject var store: AppStore
    @State private var username = ""
    @State private var token = ""
    @State private var newPassword = ""
    @State private var info: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Bước 1 · Lấy mã đặt lại") {
                TextField("Tên đăng nhập", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Gửi yêu cầu") { Task { await getCode() } }
            }
            Section("Bước 2 · Đặt mật khẩu mới") {
                TextField("Mã đặt lại", text: $token).autocorrectionDisabled()
                SecureField("Mật khẩu mới (≥6 ký tự)", text: $newPassword)
                Button("Đổi mật khẩu") { Task { await doReset() } }
            }
            if let info { Text(info).foregroundStyle(.green).font(.footnote) }
            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
        }
        .navigationTitle("Quên mật khẩu")
    }

    private func getCode() async {
        error = nil; info = nil
        do {
            let r = try await store.api.forgot(username)
            if let t = r.resetToken { token = t }
            info = r.message
        } catch { self.error = error.localizedDescription }
    }
    private func doReset() async {
        error = nil; info = nil
        do { let r = try await store.api.reset(token, newPassword); info = r.message }
        catch { self.error = error.localizedDescription }
    }
}
