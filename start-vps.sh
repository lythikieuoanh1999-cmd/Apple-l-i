#!/usr/bin/env bash
# ============================================================
#  start-vps.sh — Cài đặt & chạy KENIOS Backend trên VPS Linux
#  Hỗ trợ: Ubuntu 22.04+, Debian 12+
# ============================================================
set -eo pipefail

echo "╔══════════════════════════════════════════╗"
echo "║   KENIOS v4.0 — VPS Backend Installer    ║"
echo "╚══════════════════════════════════════════╝"

# ===== CẤU HÌNH (SỬA TRƯỚC KHI CHẠY) =====
ADMIN_USER="${ADMIN_USER:-kenios}"
ADMIN_PASS="${ADMIN_PASS:-admin1999@}"
CODEBOX_SECRET="${CODEBOX_SECRET:-$(openssl rand -hex 32)}"
PORT="${PORT:-8000}"
BANK_CODE="${BANK_CODE:-970416}"
BANK_SHORT="${BANK_SHORT:-ACB}"
BANK_ACCOUNT="${BANK_ACCOUNT:-23252921}"
BANK_NAME="${BANK_NAME:-TRAN MINH CHIEN}"
WORK_DIR="${WORK_DIR:-/root/kenios}"
# =============================================

echo ""
echo "▸ Cấu hình:"
echo "  Admin: $ADMIN_USER"
echo "  Port:  $PORT"
echo "  Dir:   $WORK_DIR"
echo ""

# 1. Cài đặt hệ thống
echo "▸ [1/7] Cài đặt packages hệ thống..."
sudo apt update -y
sudo apt install -y python3 python3-venv python3-dev python3-pip \
    nginx certbot python3-certbot-nginx \
    nodejs npm gcc g++ golang-go default-jdk \
    ffmpeg \
    zip unzip curl wget git

# 2. Tạo thư mục làm việc
echo "▸ [2/7] Tạo thư mục làm việc..."
mkdir -p "$WORK_DIR"

# Copy backend file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/backend/kenios.py" ]; then
    cp "$SCRIPT_DIR/backend/kenios.py" "$WORK_DIR/kenios.py"
    echo "  ✓ Đã copy kenios.py"
fi

cd "$WORK_DIR"

# 3. Tạo Python venv
echo "▸ [3/7] Tạo Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# 4. Cài dependencies
echo "▸ [4/7] Cài thư viện Python..."
pip install --upgrade pip
pip install \
    "fastapi>=0.110" \
    "uvicorn[standard]>=0.29" \
    "httpx>=0.27" \
    "cryptography>=42" \
    "stripe>=8.0" \
    "python-multipart>=0.0.9" \
    "pypdf" \
    "python-docx" \
    "openpyxl" \
    "TikTokLive>=6.0" \
    "aiosmtpd>=1.4" \
    "yt-dlp"

# 5. Tạo file .env
echo "▸ [5/7] Tạo file cấu hình..."
cat > "$WORK_DIR/.env" << EOF
CODEBOX_SECRET=$CODEBOX_SECRET
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
PORT=$PORT
BANK_CODE=$BANK_CODE
BANK_SHORT=$BANK_SHORT
BANK_ACCOUNT=$BANK_ACCOUNT
BANK_NAME=$BANK_NAME
REQUEST_TIMEOUT=180
SANDBOX_TIMEOUT=30
EOF
echo "  ✓ File .env đã tạo tại $WORK_DIR/.env"

# 6. Tạo systemd service
echo "▸ [6/7] Tạo systemd service..."
sudo tee /etc/systemd/system/kenios.service > /dev/null << EOF
[Unit]
Description=KENIOS kenios v4.2
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
EnvironmentFile=$WORK_DIR/.env
ExecStart=$WORK_DIR/venv/bin/uvicorn kenios:app --host 0.0.0.0 --port $PORT --workers 2
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable kenios
sudo systemctl restart kenios

echo "  ✓ Service kenios đã khởi động"

# 7. Cấu hình Nginx (reverse proxy + HTTPS sẵn)
echo "▸ [7/7] Cấu hình Nginx..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_IP")

sudo tee /etc/nginx/sites-available/kenios > /dev/null << EOF
server {
    listen 80;
    server_name $PUBLIC_IP _;

    client_max_body_size 4096M;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 1800s;
        proxy_send_timeout 1800s;
        proxy_connect_timeout 60s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/kenios /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t && sudo systemctl reload nginx

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ KENIOS Backend đã sẵn sàng!                     ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  🌐 URL:  http://$PUBLIC_IP                          ║"
echo "║  🔌 Port: $PORT                                      ║"
echo "║  👤 Admin: $ADMIN_USER                               ║"
echo "║                                                      ║"
echo "║  📱 Trong app KENIOS:                                ║"
echo "║    → Nhập URL: http://$PUBLIC_IP                     ║"
echo "║    → Đăng nhập: $ADMIN_USER / (mật khẩu đã đặt)    ║"
echo "║                                                      ║"
echo "║  📋 Lệnh quản lý:                                   ║"
echo "║    sudo systemctl status kenios   # xem trạng thái  ║"
echo "║    sudo systemctl restart kenios  # khởi động lại   ║"
echo "║    sudo journalctl -u kenios -f   # xem log         ║"
echo "║                                                      ║"
echo "║  🔒 Bật HTTPS (cần domain):                         ║"
echo "║    sudo certbot --nginx -d yourdomain.com            ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"

# Kiểm tra health
sleep 2
echo ""
echo "▸ Kiểm tra health..."
HEALTH=$(curl -s http://127.0.0.1:$PORT/health 2>/dev/null || echo "FAIL")
echo "  Health: $HEALTH"
