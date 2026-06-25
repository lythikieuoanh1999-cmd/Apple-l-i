# Phân phối app theo UDID + bắt "Tin cậy" (ad-hoc)

Mục tiêu: người dùng phải **đăng ký UDID** và **Tin cậy chứng chỉ** mới dùng được app.
Đây là kiểu phân phối **ad-hoc** của Apple.

## Cần gì
- **Tài khoản Apple Developer** ($99/năm) — để ký ad-hoc, đăng ký tối đa **100 thiết bị/năm**.
- Một máy **macOS** (hoặc dịch vụ ký) để ký lại IPA.

## Luồng hoạt động
1. **Thu UDID** (đã có sẵn trong app/backend này):
   - Mở app → **Tiện ích → Phân phối → Đăng ký thiết bị (UDID)** → copy/chia sẻ link.
   - Hoặc gửi thẳng link: `http://IP-VPS/enroll/start`
   - Người dùng mở link bằng **Safari trên iPhone** → bấm **"Lấy UDID"** → cài hồ sơ cấu hình → UDID **tự gửi về máy chủ**.
   - Admin xem danh sách UDID trong app (mục Phân phối) hoặc `GET /devices` (cần token admin).

2. **Đăng ký UDID vào Apple Developer:**
   - https://developer.apple.com → Certificates, Identifiers & Profiles → **Devices** → thêm các UDID.
   - Tạo **Provisioning Profile (Ad Hoc)** chứa các thiết bị đó + App ID `com.kenios.codebox`.

3. **Ký IPA cho các UDID:**
   - Trên macOS: `xcodebuild ... -exportOptionsPlist (method: ad-hoc)` với profile ở bước 2,
     hoặc dùng công cụ như **iOS App Signer**.
   - Bản IPA đã ký chỉ chạy trên các máy có UDID đã đăng ký.

4. **Cài + Tin cậy:**
   - Người dùng cài IPA đã ký (AltStore/Apple Configurator/MDM/itms-services).
   - Vào **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị** → bấm tên nhà phát triển → **Tin cậy**.
   - Mở app → dùng được.

## Lưu ý quan trọng
- Phần **thu UDID** đã code sẵn (endpoint `/enroll/*` + màn hình trong app).
- Phần **ký theo UDID** *bắt buộc* cần tài khoản Apple Developer của bạn — mình không ký thay được.
- Bản **IPA chưa ký** (từ GitHub Actions) **không** giới hạn theo UDID; muốn "vào lấy UDID + Tin cậy mới dùng" thì phải ký ad-hoc như trên.
- Endpoint `/enroll/start` nên chạy qua **HTTPS** để iOS cài hồ sơ mượt (Nginx + certbot).

## Test nhanh
- Mở `http://IP-VPS/enroll/start` trên iPhone (Safari) → lấy UDID → kiểm tra hiện trong app (Phân phối).
