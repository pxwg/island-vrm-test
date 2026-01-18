#!/bin/bash

# --- 默认配置 ---
APP_NAME="BoringNotchMVP"
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

# 默认关闭调试模式
USE_DEBUG_SERVER=false

# --- 解析命令行参数 ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug)
            if [ "$2" == "true" ]; then
                USE_DEBUG_SERVER=true
            else
                USE_DEBUG_SERVER=false
            fi
            shift # 移除 --debug
            shift # 移除 true/false
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# --- 1. 清理旧构建 ---
echo "🧹 Cleaning up..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$RESOURCES_DIR"

# --- 2. 编译 Swift 代码 ---
echo "🚀 Compiling Swift sources..."

# 根据解析出的变量构建编译器参数
SWIFT_FLAGS="-O"
if [ "$USE_DEBUG_SERVER" = true ]; then
    echo "🚧 Building with DEBUG_SERVER mode enabled..."
    SWIFT_FLAGS="$SWIFT_FLAGS -D DEBUG_SERVER"
else
    echo "📦 Building with RELEASE mode (local assets)..."
fi

# 执行编译
swiftc \
    NotchShape.swift \
    NotchConfig.swift \
    NotchViewModel.swift \
    NotchView.swift \
    NotchWindow.swift \
    VRMWebView.swift \
    main.swift \
    -o "$EXECUTABLE" \
    -target arm64-apple-macos14.0 \
    -sdk $(xcrun --show-sdk-path) \
    $SWIFT_FLAGS

# 检查编译是否成功
if [ $? -ne 0 ]; then
    echo "❌ Compilation failed."
    exit 1
fi

# --- 2.5 编译 Web 前端 (新增) ---
echo "📦 Building Web Frontend..."
cd web
npm run build # 这会根据 vite.config.ts 输出到 ../WebResources
cd ..

# --- 3. 复制 Web 资源 (关键步骤) ---
echo "📂 Copying WebResources..."
if [ -d "WebResources" ]; then
    # 将 WebResources 文件夹整体复制到 Resources 目录下
    cp -r "WebResources" "$RESOURCES_DIR/"
else
    echo "⚠️ Warning: 'WebResources' folder not found! WebView will be empty."
fi

# --- 4. 创建 Info.plist ---
echo "📝 Creating Info.plist..."
# LSUIElement=true 隐藏 Dock 图标
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# --- 5. 签名 (本地运行必需) ---
echo "✍️  Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Build successful!"
echo "👉 Run with: open $APP_BUNDLE"
