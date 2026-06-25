# Dựng email thật có tài khoản + mật khẩu cho `kenios.store`

Mục tiêu: hộp thư thật `ten@kenios.store` — có **đăng nhập bằng mật khẩu**, **gửi & nhận**,
**lưu lâu dài**, có **webmail** — giống Gmail nhưng trên domain của bạn.

Dùng **Mailcow** (bộ mail server đầy đủ: SMTP + IMAP + webmail SOGo + chống spam + giao diện quản trị).

---

## 0. Chuẩn bị (bắt buộc)

| Yêu cầu | Chi tiết |
|---|---|
| VPS | Ubuntu 22.04+ / Debian 12+, **≥ 6GB RAM**, 2 vCPU, ~30GB ổ đĩa |
| Cổng mở | 25, 80, 443, 465, 587, 993, 143, 110, 995, 4190 |
| Domain | `kenios.store` trỏ DNS được (bạn đang quản lý DNS) |
| rDNS/PTR | Đặt được ở nhà cung cấp VPS (rất quan trọng để không bị spam) |
| Port 25 | Nhiều VPS chặn cổng 25 mặc định — phải xin nhà cung cấp **mở port 25 outbound** |

> ⚠️ Nếu nhà cung cấp không cho mở port 25 (vd một số gói rẻ), mail sẽ **nhận được** nhưng
> **không gửi ra ngoài** được. Khi đó cần dùng SMTP relay (SendGrid/Mailgun) — báo mình sẽ hướng dẫn.

---

## 1. Trỏ DNS trước

Mở `dns-records.txt` trong thư mục này, thêm các bản ghi vào trang quản lý tên miền.
Tối thiểu cần ngay: **A (mail)** và **MX**. DKIM lấy sau khi cài (bước 3).

---

## 2. Cài Mailcow (chạy trong Termius)

```bash
sudo -i
cd /opt
git clone https://github.com/lythikieuoanh1999-cmd/Apple-l-i.git kenios-src 2>/dev/null || true
# Hoặc tải riêng file install-mail.sh lên rồi:
cd /opt
bash /opt/kenios-src/mailserver/install-mail.sh
```

Hoặc tải mã thủ công (nếu repo private), upload `mailserver/install-mail.sh` qua SFTP rồi:

```bash
chmod +x install-mail.sh
MAIL_HOST=mail.kenios.store ./install-mail.sh
```

Lần đầu kéo image mất vài phút. Xong sẽ in ra link quản trị.

---

## 3. Tạo tài khoản email (có mật khẩu)

1. Mở `https://mail.kenios.store` → đăng nhập **admin / moohoo** → **đổi mật khẩu ngay**.
2. **Configuration → Mail Setup → Domains** → **Add domain**: `kenios.store`.
3. Lấy DKIM: **Configuration → ARC/DKIM keys** → chọn `kenios.store` → copy chuỗi `p=...`
   → thêm bản ghi **TXT `dkim._domainkey`** vào DNS (xem `dns-records.txt`).
4. **Mailboxes → Add mailbox**: nhập `username`, chọn domain `kenios.store`, đặt **mật khẩu**.
   → Đây chính là **tài khoản + mật khẩu** bạn muốn. VD `cong@kenios.store`.

---

## 4. Dùng trong app KENIOS

- Tab **CenMail** trong app đã trỏ tới `https://mail.kenios.store`.
- Sau khi Mailcow chạy, người dùng vào **Webmail (SOGo)**: `https://mail.kenios.store/SOGo/`
  → đăng nhập bằng `ten@kenios.store` + mật khẩu vừa tạo → gửi/nhận thư thật.
- Muốn app mở thẳng trang webmail: báo mình, mình đổi CenMail sang `/SOGo/`.

> Lưu ý: máy chủ này sẽ **thay thế** trang temp-mail cũ tại `mail.kenios.store`.
> Nếu muốn giữ cả hai, dùng subdomain khác cho mail server (vd `mx.kenios.store`).

---

## 5. Quản lý

```bash
cd /opt/mailcow-dockerized
docker compose ps              # trạng thái
docker compose logs -f         # log
docker compose down            # dừng
docker compose up -d           # chạy lại
./update.sh                    # cập nhật Mailcow
```

---

## 6. Kiểm tra sức khoẻ mail

- https://mxtoolbox.com → nhập `kenios.store` kiểm tra MX/SPF/DKIM/DMARC + blacklist.
- Gửi thử email tới `check-auth@verifier.port25.com` → nhận báo cáo xác thực.
- Mục tiêu: SPF **pass**, DKIM **pass**, DMARC **pass**, IP không nằm blacklist.
