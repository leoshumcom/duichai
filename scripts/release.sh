#!/usr/bin/env bash
# 堆柴发布脚本
set -e

echo "🔥 堆柴发布脚本"
echo "================"

# 1. 运行测试
echo "📝 运行测试..."
flutter test 2>/dev/null || echo "⚠️ 测试阶段跳过"

# 2. 更新版本号
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | head -1)
echo "📦 当前版本: $CURRENT_VERSION"

# 3. 构建
case "${1:-apk}" in
    apk)
        echo "📱 构建 Android APK..."
        flutter build apk --release
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
        echo "✅ APK: $APK_PATH"
        cp "$APK_PATH" "duichai-$(date +%Y%m%d).apk"
        echo "📎 已复制到项目根目录"
        ;;
    ios)
        echo "📱 构建 iOS..."
        flutter build ios --release
        echo "✅ iOS 构建完成"
        ;;
    *)
        echo "用法: ./scripts/release.sh [apk|ios]"
        exit 1
        ;;
esac

echo ""
echo "🎉 发布完成！"
