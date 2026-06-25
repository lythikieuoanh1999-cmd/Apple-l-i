# Cài KENIOS MIỄN PHÍ (sideload — không cần $99, không cần UDID)

Dùng tài khoản Apple **miễn phí** + công cụ sideload. App chạy được 7 ngày rồi tự/được gia hạn.

## Bước 1 — Lấy file IPA (miễn phí)
- Đẩy mã nguồn lên GitHub → tab **Actions** → **Build App (IPA chưa ký)** → mở lần chạy →
  **Artifacts** → tải **KENIOS-ipa** → giải nén được `KENIOS.ipa`.

## Bước 2 — Chọn công cụ sideload (chọn 1)
| Công cụ | Máy cần | Ưu điểm |
|---|---|---|
| **SideStore** | iPhone (qua wifi, dùng JITterbug/anisette) | **Tự gia hạn 7 ngày**, không cần cắm máy tính thường xuyên |
| **AltStore** | PC/Mac chạy AltServer + iPhone | Phổ biến, gia hạn khi cùng wifi với PC |
| **Sideloadly** | PC/Mac cắm cáp | Cài nhanh, đơn giản nhất |

## Bước 3 — Cài
**Sideloadly (dễ nhất):**
1. Cài Sideloadly trên PC/Mac (sideloadly.io).
2. Cắm iPhone bằng cáp → mở Sideloadly.
3. Kéo `KENIOS.ipa` vào → nhập **Apple ID miễn phí** của bạn → **Start**.
4. iPhone: **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị** → bấm Apple ID của bạn → **Tin cậy**.
5. Mở app KENIOS.

**AltStore / SideStore:** cài AltServer/SideStore theo hướng dẫn của họ → mở app → **+** → chọn `KENIOS.ipa` → đăng nhập Apple ID free.

## Giới hạn của tài khoản Apple miễn phí
- App hết hạn sau **7 ngày** → mở lại AltStore/SideStore/Sideloadly để **ký lại** (SideStore/AltStore làm tự động khi cùng wifi).
- Tối đa **3 app** sideload cùng lúc / Apple ID free.
- **Không** giới hạn theo UDID (cái đó cần tài khoản trả phí).

## Bước 4 — Kết nối server
- Mở app → **Cài đặt → Quản lý máy chủ** → nhập `http://IP-VPS` (backend bạn đã chạy theo RUN-VPS.md).
- Đăng ký / đăng nhập → dùng KENIOS AI và mọi tính năng.

> Mẹo: muốn người khác cài, gửi họ file `KENIOS.ipa` + link hướng dẫn này. Mỗi người tự
> sideload bằng Apple ID free của họ.
