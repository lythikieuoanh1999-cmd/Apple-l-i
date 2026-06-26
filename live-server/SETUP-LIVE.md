# KENIOS LIVE — phát hình thật từ điện thoại

Phần này giúp bạn **live có hình** (như TikTok) bằng cách:
điện thoại đẩy luồng RTMP về VPS → VPS chuyển sang HLS → người xem coi trong app KENIOS.

## 1. Cài máy chủ live trên VPS
```bash
cd /root/kenios-src/live-server   # nơi chứa file
chmod +x install-rtmp.sh
sudo ./install-rtmp.sh
```
Script cài nginx + module RTMP + ffmpeg, mở cổng **1935** (nhận luồng) và **8080** (phát HLS).

## 2. Phát hình từ điện thoại
Tải app phát RTMP miễn phí: **Larix Broadcaster** (hoặc Streamlabs).
- Server URL: `rtmp://IP-VPS:1935/live`
- Stream key: tự đặt, ví dụ `myroom`
- Bấm phát → camera điện thoại lên sóng.

> iOS không cho app chưa ký tự đẩy camera RTMP, nên ta dùng app phát chuyên dụng (Larix). Đây là cách realistic để "live từ điện thoại".

## 3. Mở phòng live trong app KENIOS
- Vào tab **Live → Mở phòng live**.
- Tiêu đề: tuỳ ý.
- **Link phát hình (HLS)**: dán
  ```
  http://IP-VPS:8080/hls/myroom.m3u8
  ```
  (thay `myroom` bằng stream key bạn đặt ở bước 2)
- Bắt đầu live → người xem vào phòng sẽ **thấy hình + bình luận thời gian thực**.

## Ghi chú
- Trễ HLS khoảng 5–15 giây (bình thường với HLS).
- Muốn bảo mật, đổi `allow publish all;` thành chỉ cho IP của bạn trong `/etc/nginx/nginx.conf`.
- Nếu chỉ cần **live bằng chữ** (không hình) thì bỏ qua bước 1–2, mở phòng để trống link HLS.
