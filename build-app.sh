#!/usr/bin/env bash
# ============================================================
#  build-app.sh — Build KENIOS iOS app thành file .ipa
#  Chạy trên macOS có Xcode 15+ (hoặc Xcode 26 cho Liquid Glass)
# ============================================================
set -eo pipefail

echo "╔══════════════════════════════════════════╗"
echo "║     KENIOS v4.0 — iOS App Builder        ║"
echo "╚══════════════════════════════════════════╝"

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

# 1. Kiểm tra môi trường
echo "▸ Kiểm tra Xcode..."
if ! command -v xcodebuild &>/dev/null; then
    echo "❌ Chưa cài Xcode hoặc Xcode Command Line Tools."
    echo "   Cài bằng: xcode-select --install"
    exit 1
fi
xcodebuild -version
swift --version

# 2. Cài XcodeGen (nếu chưa có)
echo "▸ Kiểm tra XcodeGen..."
if ! command -v xcodegen &>/dev/null; then
    echo "  → Đang cài XcodeGen qua Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "❌ Cần cài Homebrew trước: https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi
echo "  ✓ XcodeGen $(xcodegen version)"

# 3. Sinh file .xcodeproj từ project.yml
echo "▸ Sinh file Xcode project..."
xcodegen generate
echo "  ✓ KENIOS.xcodeproj đã tạo"

# 4. Hiển thị schemes
echo "▸ Danh sách schemes:"
xcodebuild -list -project KENIOS.xcodeproj

# 5. Build Release (unsigned — không cần chứng chỉ / developer account)
echo "▸ Build Release (unsigned)..."
xcodebuild \
    -project KENIOS.xcodeproj \
    -scheme KENIOS \
    -configuration Release \
    -sdk iphoneos \
    -derivedDataPath build \
    -destination "generic/platform=iOS" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    build 2>&1 | tail -20

echo "  ✓ Build thành công"

# 6. Đóng gói thành .ipa
echo "▸ Đóng gói IPA..."
APP_PATH=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name "*.app" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Không tìm thấy file .app sau khi build!"
    find build/Build/Products -maxdepth 3
    exit 1
fi

rm -rf Payload
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r KENIOS.ipa Payload >/dev/null
rm -rf Payload

IPA_SIZE=$(du -h KENIOS.ipa | cut -f1)
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ Build hoàn tất!                                  ║"
echo "║  File: KENIOS.ipa ($IPA_SIZE)                        ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  CÁCH CÀI ĐẶT TRÊN iPHONE:                         ║"
echo "║                                                      ║"
echo "║  Cách 1: Dùng AltStore / Sideloadly / TrollStore     ║"
echo "║    1. Cài AltStore trên máy tính + điện thoại        ║"
echo "║    2. Mở AltStore → + → chọn KENIOS.ipa             ║"
echo "║    3. Chờ cài đặt xong                               ║"
echo "║                                                      ║"
echo "║  Cách 2: Ký bằng Apple Developer Account             ║"
echo "║    1. Dùng ios-app-signer để ký file .ipa            ║"
echo "║    2. Cài qua Xcode (Devices & Simulators)           ║"
echo "║                                                      ║"
echo "║  ⚠️  SAU KHI CÀI:                                    ║"
echo "║  Vào Cài đặt → Cài đặt chung → Quản lý VPN &       ║"
echo "║  thiết bị → Nhấn vào tên nhà phát triển →           ║"
echo "║  Bấm \"Tin cậy\" để cho phép mở app.                  ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
