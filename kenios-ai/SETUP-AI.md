# KENIOS AI — AI riêng của bạn (không dùng API key của ai)

"KENIOS AI" = một **mô hình mã nguồn mở chạy trên máy chủ của bạn** (qua **Ollama**).
App gọi thẳng tới nó, người dùng **không cần nhập API key**. Bạn cũng có thể **cấp API key**
cho người khác gọi AI của bạn.

> ⚠️ Thực tế: không thể tự tạo model thông minh ngang Claude/GPT‑4 (cần hàng chục triệu USD +
> nghìn GPU). Nhưng model mở 8B–70B (Llama 3.1/3.3, Qwen 2.5, DeepSeek...) khá thông minh,
> đủ dùng cho chat/code, và là **của riêng bạn**.

## 1. Cấu hình máy chủ
| Mức | Gợi ý | Model phù hợp |
|---|---|---|
| Rẻ (CPU) | 8GB RAM | `phi3`, `qwen2.5:3b`, `llama3.2:3b` (nhẹ, nhanh) |
| Khá (CPU) | 16GB RAM | `llama3.1` (8B), `qwen2.5:7b` |
| Mạnh (GPU) | GPU ≥ 16GB VRAM | `qwen2.5:32b`, `llama3.3:70b` (thông minh nhất) |

## 2. Cài đặt (chạy trong Termius)
```bash
sudo -i
# nếu chưa có mã nguồn:
cd /opt/kenios-src 2>/dev/null || true
MODEL=llama3.1 bash kenios-ai/install-ai.sh
```
Script sẽ: cài Ollama → tải model → ghi `KENIOS_AI_*` vào `.env` của backend → restart kenios.

Đổi model: `MODEL=qwen2.5:7b bash kenios-ai/install-ai.sh`

## 3. Dùng trong app
- Mở **Chọn AI** → chọn **"KENIOS AI · của bạn (miễn phí, không cần key)"** → chat ngay.
- Đây là AI mặc định/đỉnh của app, không tốn key của bất kỳ nhà cung cấp nào.

## 4. Cấp API key cho người khác dùng ké
- Trong app: **Tiện ích → AI → KENIOS AI — cấp API key** → **Tạo khoá** → copy.
- Người khác gọi:
```bash
curl -X POST http://IP-VPS:8000/v1/kenios/chat \
  -H "Content-Type: application/json" \
  -d '{"token":"<API_KEY>","message":"Xin chào"}'
```
- Trả về: `{"reply": "...", "model": "llama3.1"}`. Bạn xem số lần gọi của từng khoá trong app.

## 5. Biến môi trường (.env của backend)
```
KENIOS_AI_ENABLE=1
KENIOS_AI_BASE=http://127.0.0.1:11434/v1
KENIOS_AI_MODEL=llama3.1
KENIOS_AI_KEY=ollama
```

## 6. Quản lý model
```bash
ollama list            # model đang có
ollama pull qwen2.5:7b # tải thêm
ollama rm llama3.1     # xoá
journalctl -u ollama -f
```

## 7. Mẹo thông minh hơn
- Dùng model lớn hơn nếu máy đủ khoẻ (70B > 8B > 3B).
- Đặt **system prompt** mặc định trong app để định "tính cách"/kỹ năng cho KENIOS AI.
- Có thể bật nhiều model và cho người dùng chọn (sửa `KENIOS_AI_MODEL`).
