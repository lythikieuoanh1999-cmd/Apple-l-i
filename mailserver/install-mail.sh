#!/usr/bin/env bash
# ============================================================
#  install-mail.sh — Dựng MAIL SERVER THẬT cho kenios.store
#  (tài khoản + mật khẩu, gửi/nhận, webmail) bằng Mailcow.
#  Chạy trên VPS Ubuntu 22.04+/Debian 12+ (khuyến nghị 6GB RAM, 2 vCPU).
# ============================================================
set -eo pipefail

MAIL_HOST="${MAIL_HOST:-mail.kenios.store}"
TZ_VAL="${TZ_VAL:-Asia/Ho_Chi_Minh}"

echo "╔══════════════════════════════════════════════╗"
echo "║   KENIOS Mail Server (Mailcow) Installer     ║"
echo "╚══════════════════════════════════════════════╝"
echo "  Hostname : $MAIL_HOST"
echo "  Timezone : $TZ_VAL"
echo ""

# 0. Kiểm tra quyền root
if [ "$(id -u)" != "0" ]; then echo "❌ Hãy chạy bằng root (sudo -i)."; exit 1; fi

# 1. Gói cơ bản
echo "▸ [1/5] Cài gói cơ bản..."
apt update -y
apt install -y curl git ca-certificates apt-transport-https

# 2. Docker + Docker Compose plugin
echo "▸ [2/5] Cài Docker..."
if ! command -v docker >/dev/null 2>&1; then
    curl -sSL https://get.docker.com | sh
fi
systemctl enable --now docker

# 3. Tải Mailcow
echo "▸ [3/5] Tải Mailcow..."
cd /opt
if [ ! -d mailcow-dockerized ]; then
    git clone https://github.com/mailcow/mailcow-dockerized
fi
cd /opt/mailcow-dockerized

# 4. Sinh cấu hình (không hỏi tương tác — lấy từ biến môi trường)
echo "▸ [4/5] Sinh cấu hình cho $MAIL_HOST..."
if [ ! -f mailcow.conf ]; then
    MAILCOW_HOSTNAME="$MAIL_HOST" MAILCOW_TZ="$TZ_VAL" ./generate_config.sh
fi

# 5. Khởi động
echo "▸ [5/5] Kéo image & khởi động (lần đầu mất vài phút)..."
docker compose pull
docker compose up -d

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP_VPS")
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  ✅ Mail server đã khởi động!                          ║"
echo "╠════════════════════════════════════════════════════════╣"
echo "║  Trang quản trị : https://$MAIL_HOST                    "
echo "║  Đăng nhập admin: admin / moohoo  (ĐỔI NGAY!)          ║"
echo "║  Webmail (SOGo) : https://$MAIL_HOST/SOGo/             "
echo "║                                                        ║"
echo "║  TIẾP THEO:                                            ║"
echo "║  1) Trỏ DNS theo file dns-records.txt (rất quan trọng)║"
echo "║  2) Vào admin → Configuration → Mail Setup:            ║"
echo "║     - Thêm Domain: kenios.store                        ║"
echo "║     - Thêm Mailbox: ten@kenios.store + mật khẩu        ║"
echo "║  3) Lấy bản ghi DKIM trong admin → ARC/DKIM keys       ║"
echo "║     rồi thêm vào DNS.                                  ║"
echo "║  4) Đặt rDNS (PTR) của IP $PUBLIC_IP = $MAIL_HOST       "
echo "║     (ở trang quản lý VPS của nhà cung cấp).            ║"
echo "╚════════════════════════════════════════════════════════╝"
