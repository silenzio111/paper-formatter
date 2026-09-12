#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Word Formatter.app"
APP_DIR="$ROOT_DIR/$APP_NAME"
ICONSET_DIR="$ROOT_DIR/NativeApp/WordFormatter.iconset"
ICON_FILE="$ROOT_DIR/NativeApp/WordFormatter.icns"
SWIFTPM_LOG="/tmp/word_formatter_swiftpm.log"
PYTHON_PACKAGES_DIR="$ROOT_DIR/.build/python-packages"
PYTHON_PACKAGE_MARKER="$PYTHON_PACKAGES_DIR/.requirements-installed"

cd "$ROOT_DIR"

PYTHON_EXECUTABLE=""
for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
    if [ -x "$candidate" ]; then
        PYTHON_EXECUTABLE="$candidate"
        break
    fi
done
if [ -z "$PYTHON_EXECUTABLE" ]; then
    printf '找不到 Python 3，无法准备 python-docx 排版引擎。\n' >&2
    exit 1
fi

if [ ! -f "$PYTHON_PACKAGE_MARKER" ] || [ "$ROOT_DIR/requirements.txt" -nt "$PYTHON_PACKAGE_MARKER" ]; then
    printf '准备 python-docx 依赖...\n'
    rm -rf "$PYTHON_PACKAGES_DIR"
    mkdir -p "$PYTHON_PACKAGES_DIR"
    "$PYTHON_EXECUTABLE" -m pip install \
        --disable-pip-version-check \
        --no-input \
        --target "$PYTHON_PACKAGES_DIR" \
        -r "$ROOT_DIR/requirements.txt"
    printf '%s\n' "$($PYTHON_EXECUTABLE --version)" >"$PYTHON_PACKAGE_MARKER"
fi

# Python bytecode is not needed in the signed bundle and would make the
# Resources directory mutable during development runs.
find "$PYTHON_PACKAGES_DIR" -type d -name '__pycache__' -prune -exec rm -rf {} +
find "$PYTHON_PACKAGES_DIR" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

printf '构建 Swift App...\n'
APP_BINARY=""
if swift build -c release >"$SWIFTPM_LOG" 2>&1; then
    BIN_DIR="$(swift build -c release --show-bin-path)"
    APP_BINARY="$BIN_DIR/WordFormatter"
else
    printf 'SwiftPM 构建不可用，改用 swiftc 直接构建。\n'
    APP_BINARY="$ROOT_DIR/.build/release/WordFormatter"
    mkdir -p "$(dirname "$APP_BINARY")"
    swiftc \
        -O \
        -parse-as-library \
        -target "$(uname -m)-apple-macosx13.0" \
        "$ROOT_DIR"/Sources/WordFormatterApp/*.swift \
        -o "$APP_BINARY" \
        -framework SwiftUI \
        -framework AppKit
fi

if [ ! -x "$APP_BINARY" ]; then
    printf '没有找到 Swift 可执行文件: %s\n' "$APP_BINARY" >&2
    printf 'SwiftPM 日志: %s\n' "$SWIFTPM_LOG" >&2
    exit 1
fi

printf '生成 App 图标...\n'
swift "$ROOT_DIR/Scripts/generate_app_icon.swift" "$ICONSET_DIR" >/dev/null
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

printf '组装 App Bundle...\n'
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/NativeApp/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$APP_BINARY" "$APP_DIR/Contents/MacOS/WordFormatter"
cp "$ROOT_DIR/Sources/WordFormatterApp/Resources/formatter_engine.py" \
    "$APP_DIR/Contents/Resources/formatter_engine.py"
cp "$ROOT_DIR/Sources/WordFormatterApp/Resources/three_line_table_style.xml" \
    "$APP_DIR/Contents/Resources/three_line_table_style.xml"
cp -R "$PYTHON_PACKAGES_DIR" "$APP_DIR/Contents/Resources/python_packages"
cp "$ROOT_DIR/paper-format-config.example.json" \
    "$APP_DIR/Contents/Resources/paper-format-config.example.json"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/WordFormatter.icns"

chmod +x "$APP_DIR/Contents/MacOS/WordFormatter"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

printf '\n已生成: %s\n' "$APP_DIR"
printf '可以双击打开，也可以运行: open %q\n' "$APP_DIR"
