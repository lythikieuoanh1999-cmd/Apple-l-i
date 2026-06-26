#!/usr/bin/env bash
# ============================================================
#  install-rtmp.sh — Dựng máy chủ LIVE (RTMP nhận + HLS phát) cho KENIOS
#  Ubuntu 22.04+ / Debian 12+
#  Sau khi cài:
#    - Phát từ điện thoại (app Larix Broadcaster / Streamlabs) tới:
#        rtmp://IP-VPS:1935/live/STREAMKEY
#    - Người xem coi trong app KENIOS qua link HLS:
#        http://IP-VPS:8080/hls/STREAMKEY.m3u8
# ============================================================
set -eo pipefail

echo "▸ Cài nginx + module RTMP + ffmpeg..."
sudo apt update -y
sudo apt install -y nginx libnginx-mod-rtmp ffmpeg

echo "▸ Tạo thư mục HLS..."
sudo mkdir -p /var/www/hls
sudo chown -R www-data:www-data /var/www/hls

# ----- Khối RTMP (context chính của nginx) -----
if ! grep -q "rtmp {" /etc/nginx/nginx.conf; then
  echo "▸ Thêm khối rtmp vào /etc/nginx/nginx.conf..."
  sudo tee -a /etc/nginx/nginx.conf > /dev/null << 'EOF'

# ===== KENIOS LIVE (RTMP → HLS) =====
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        application live {
            live on;
            hls on;
            hls_path /var/www/hls;
            hls_fragment 2s;
            hls_playlist_length 12s;
            allow publish all;
            allow play all;
        }
    }
}
EOF
else
  echo "  (đã có khối rtmp — bỏ qua)"
fi

# ----- Server HTTP phát HLS (cổng 8080) -----
echo "▸ Cấu hình server HLS cổng 8080..."
sudo tee /etc/nginx/conf.d/kenios-hls.conf > /dev/null << 'EOF'
server {
    listen 8080;
    server_name _;

    location /hls {
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        root /var/www;
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
    }
}
EOF

echo "▸ Mở cổng tường lửa 1935 (RTMP) và 8080 (HLS)..."
sudo ufw allow 1935/tcp 2>/dev/null || true
sudo ufw allow 8080/tcp 2>/dev/null || true

echo "▸ Kiểm tra & khởi động lại nginx..."
sudo nginx -t && sudo systemctl restart nginx

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP-VPS")
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  ✅ Máy chủ LIVE đã sẵn sàng!                          ║"
echo "╠════════════════════════════════════════════════════════╣"
echo "║  Phát từ điện thoại (Larix Broadcaster):               ║"
echo "║    URL:  rtmp://$PUBLIC_IP:1935/live                    ║"
echo "║    Key:  tự đặt (vd: myroom)                            ║"
echo "║                                                        ║"
echo "║  Dán link này vào app KENIOS khi 'Mở phòng live':      ║"
echo "║    http://$PUBLIC_IP:8080/hls/myroom.m3u8              ║"
echo "╚════════════════════════════════════════════════════════╝"
