#!/bin/bash

APP_NAME="IslandVRM"
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

USE_DEBUG_SERVER=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug)
            if [ "$2" == "true" ]; then USE_DEBUG_SERVER=true; else USE_DEBUG_SERVER=false;fi
            shift; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

echo "🧹 Cleaning up..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$RESOURCES_DIR"

echo "🚀 Building with Swift Package Manager..."

# 构造编译参数
SWIFT_BUILD_FLAGS="-c release --product IslandApp --arch arm64"

if [ "$USE_DEBUG_SERVER" = true ]; then
    echo "🚧 Building with DEBUG_SERVER mode enabled..."
    # 通过 -Xswiftc 传递宏定义
    SWIFT_BUILD_FLAGS="$SWIFT_BUILD_FLAGS -Xswiftc -DDEBUG_SERVER"
fi

# [核心修改] 使用 swift build 代替 swiftc
# 这会自动处理 IslandApp -> IslandCore 的依赖关系
swift build $SWIFT_BUILD_FLAGS

if [ $? -ne 0 ]; then
    echo "❌ SPM Build failed."
    exit 1
fi

# 获取 SPM 编译出来的二进制文件路径
BIN_PATH=$(swift build -c release --product IslandApp --show-bin-path --arch arm64)
SRC_EXECUTABLE="$BIN_PATH/IslandApp"

echo "📦 Copying executable from $SRC_EXECUTABLE..."
cp "$SRC_EXECUTABLE" "$EXECUTABLE"

echo "📦 Building Web Frontend..."
if [ -d "web" ]; then
    cd web
    npm run build
    cd ..
else
    echo "⚠️ 'web' directory not found, skipping frontend build."
fi

echo "📂 Copying WebResources..."
if [ -d "WebResources" ]; then
    cp -r "WebResources" "$RESOURCES_DIR/"
else
    echo "⚠️ Warning: 'WebResources' folder not found! WebView will be empty."
fi

# 处理 SPM 可能会生成的 Bundle 资源 (如果 Core 里用了 .process)
# 如果发现 Core 生成了 Bundle，也需要拷贝进去
if [ -d "$BIN_PATH/IslandCore_IslandCore.bundle" ]; then
    echo "📂 Copying IslandCore Bundle..."
    cp -r "$BIN_PATH/IslandCore_IslandCore.bundle" "$RESOURCES_DIR/"
fi

echo "📝 Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.pxwg.$APP_NAME</string>
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

echo "✍️  Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Build successful!"
echo "👉 Run with: open $APP_BUNDLE"
