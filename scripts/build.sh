#!/usr/bin/env bash
# 堆柴 APP 构建脚本
# 用法: ./scripts/build.sh [android|ios|all]

set -e

echo "🔥 堆柴 APP 构建脚本"
echo "===================="

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装，请先安装 Flutter SDK"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -1)
echo "✅ Flutter: $FLUTTER_VERSION"

# 获取版本号
VERSION=$(grep "^version:" pubspec.yaml | cut -d' ' -f2 | tr -d '\n')
echo "📦 版本: $VERSION"

# 清理旧的构建
flutter clean
echo "🧹 清理完成"

# 获取依赖
flutter pub get
echo "📥 依赖下载完成"

build_android() {
    echo "📱 构建 Android..."
    
    # Debug APK
    flutter build apk --debug
    echo "✅ Debug APK: build/app/outputs/flutter-apk/app-debug.apk"
    
    # Release APK（需要签名配置）
    flutter build apk --release 2>/dev/null || echo "⚠️ Release APK 需要配置签名，跳过"
    
    # App Bundle
    flutter build appbundle --release 2>/dev/null || echo "⚠️ AppBundle 需要配置签名，跳过"
}

build_ios() {
    echo "📱 构建 iOS..."
    
    # iOS Build（需要 Mac + Xcode）
    flutter build ios --release --no-codesign 2>/dev/null || echo "⚠️ iOS 构建需要 macOS + Xcode，跳过"
}

# 根据参数构建
case "${1:-all}" in
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    all)
        build_android
        build_ios
        ;;
    *)
        echo "用法: ./scripts/build.sh [android|ios|all]"
        exit 1
        ;;
esac

echo ""
echo "🎉 构建完成！"
echo "===================="
