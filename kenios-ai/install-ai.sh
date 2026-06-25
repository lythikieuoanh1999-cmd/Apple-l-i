#!/usr/bin/env bash
# ============================================================
#  install-ai.sh — Dựng "KENIOS AI" (model tự host của bạn) bằng Ollama
#  → AI riêng, KHÔNG dùng API key của ai, làm AI mặc định cho app KENIOS.
#  Chạy trên VPS Ubuntu/Debian. Có GPU thì nhanh; CPU vẫn chạy (chậm hơn).
# ============================================================
set -eo pipefail

MODEL="${MODEL:-llama3.1}"          # đổi sang qwen2.5, mistral, gemma2, phi3... nếu muốn
WORK_DIR="${WORK_DIR:-/root/kenios}"

echo "╔══════════════════════════════════════════╗"
echo "║   KENIOS AI (Ollama) Installer           ║"
echo "╚══════════════════════════════════════════╝"
echo "  Model: $MODEL"
echo ""

# 1. Cài Ollama
if ! command -v ollama >/dev/null 2>&1; then
    echo "▸ Cài Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi
systemctl enable --now ollama 2>/dev/null || true
sleep 2

# 2. Tải model
echo "▸ Tải model $MODEL (lần đầu mất vài phút)..."
ollama pull "$MODEL"

# 3. Ghi cấu hình cho backend KENIOS (nếu có .env)
if [ -f "$WORK_DIR/.env" ]; then
    echo "▸ Cập nhật .env của KENIOS..."
    sed -i '/^KENIOS_AI_/d' "$WORK_DIR/.env"
    cat >> "$WORK_DIR/.env" <<EOF
KENIOS_AI_ENABLE=1
KENIOS_AI_BASE=http://127.0.0.1:11434/v1
KENIOS_AI_MODEL=$MODEL
KENIOS_AI_KEY=ollama
EOF
    systemctl restart kenios 2>/dev/null || true
    echo "  ✓ Đã cấu hình & restart kenios"
else
    echo "⚠ Không thấy $WORK_DIR/.env — hãy tự thêm các biến sau vào .env của backend:"
    echo "   KENIOS_AI_ENABLE=1"
    echo "   KENIOS_AI_BASE=http://127.0.0.1:11434/v1"
    echo "   KENIOS_AI_MODEL=$MODEL"
fi

# 4. Test nhanh
echo "▸ Test KENIOS AI..."
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Xin chào\"}]}" \
  | head -c 400 || true
echo ""
echo ""
echo "✅ Xong! Mở app → Chọn AI → 'KENIOS AI · của bạn' (miễn phí, không cần key)."
echo "   Quản lý model: ollama list | ollama pull <model> | ollama rm <model>"
