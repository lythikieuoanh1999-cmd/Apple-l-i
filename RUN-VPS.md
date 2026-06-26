# Hướng dẫn chạy KENIOS trên VPS (qua Termius)

App KENIOS cần **backend** chạy trên VPS. Dưới đây là các bước từ A→Z.

---

## 0. Chuẩn bị
- VPS **Ubuntu 22.04+ / Debian 12+**, RAM ≥ 2GB (≥ 8–16GB nếu chạy KENIOS AI).
- Kết nối bằng **Termius**: New Host → nhập IP VPS, user `root`, mật khẩu → mở terminal.

---

## 1. Tải mã nguồn lên VPS
**Cách A — git (repo public):**
```bash
sudo -i
apt update -y && apt install -y git unzip
cd /opt
git clone -b claude/game-web-fixes-auto-click-qppnr5 https://github.com/lythikieuoanh1999-cmd/Apple-l-i.git kenios-src
cd kenios-src
```
**Cách B — repo private / không git:** mở tab **SFTP** của Termius → upload `KENIOS_project.zip` vào `/opt` → rồi:
```bash
cd /opt && unzip -o KENIOS_project.zip -d kenios-src && cd kenios-src
```

---

## 2. Chạy backend (1 lệnh — tự cài hết)
```bash
chmod +x start-vps.sh
sudo ADMIN_USER=kenios ADMIN_PASS='matkhau-cua-ban' PORT=8000 ./start-vps.sh
```
Script tự: cài Python + thư viện (gồm TikTokLive, aiosmtpd) → tạo **systemd service `kenios`** chạy nền 24/7 → cấu hình Nginx → in ra URL.

**Lệnh quản lý:**
```bash
systemctl status kenios     # xem trạng thái
systemctl restart kenios    # khởi động lại (sau khi sửa)
journalctl -u kenios -f     # xem log trực tiếp
```

---

## 3. (Tuỳ chọn) Bật KENIOS AI — AI riêng không cần key
```bash
MODEL=llama3.1 bash kenios-ai/install-ai.sh
systemctl restart kenios
```
- Cài Ollama + tải model + tự cấu hình `.env`. Model nhẹ cho CPU: `MODEL=qwen2.5:3b`.
- Xong: mở app → Chọn AI → **KENIOS AI · của bạn**.

---

## 4. (Tuỳ chọn) Gửi OTP qua email khi đăng ký
- Cần SMTP relay để gửi mail ra ngoài — thêm vào `/opt/kenios-src/.env`:
  ```
  SMTP_RELAY_HOST=smtp.gmail.com
  SMTP_RELAY_PORT=587
  SMTP_RELAY_USER=email@gmail.com
  SMTP_RELAY_PASS=app-password
  ```
  rồi `systemctl restart kenios`.
- Hoặc đặt `OTP_DEBUG=1` để test mà không cần email.

---

## 5. Nhập vào app
- **Cài đặt → Quản lý máy chủ** → nhập `http://IP-VPS` (Nginx cổng 80) hoặc `http://IP-VPS:8000`.
- Đăng ký / đăng nhập. Admin: `kenios` / mật khẩu bạn đặt ở bước 2.

---

## 6. Cấu hình thường dùng trong `.env` (`/opt/kenios-src/.env`)
```
PORT=8000
ADMIN_USER=kenios
ADMIN_PASS=...
OTP_DEBUG=0                 # =1 để test OTP khi chưa có mail
KENIOS_AI_ENABLE=1
KENIOS_AI_MODEL=llama3.1
```
Sửa xong luôn `systemctl restart kenios`.

---

## 7. Lỗi thường gặp
| Triệu chứng | Cách xử lý |
|---|---|
| App báo "Không kết nối được máy chủ" | Backend chưa chạy / sai URL-cổng → `systemctl status kenios`, mở cổng firewall |
| Chọn KENIOS AI báo lỗi kết nối | Chưa cài Ollama → chạy `kenios-ai/install-ai.sh` |
| AI khác báo 429 | Hết hạn mức free → đổi Groq/OpenRouter hoặc dùng KENIOS AI |
| Tải video lỗi | Thiếu `ffmpeg`/`yt-dlp` → chạy lại `start-vps.sh` |
| OTP không tới | Đặt SMTP_RELAY, hoặc `OTP_DEBUG=1` để test |
