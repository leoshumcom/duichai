# 堆柴项目 — 上线就绪清单

## ✅ 已完成

### 后端基础设施
- [x] Cloudflare Workers API (20+接口)
- [x] D1 数据库 (28张表 + 测试数据)
- [x] R2 文件存储
- [x] 自定义域名: api.duichai.com

### 官网 + 管理后台
- [x] www.duichai.com (Cloudflare Pages)
- [x] admin.duichai.com (数据大盘)
- [x] GitHub Actions CI/CD 自动部署

### Flutter APP
- [x] 用户注册/登录 (邮箱+密码)
- [x] 个人中心 (等级/柴火/勋章)
- [x] 发现页 (场地卡片/分类/搜索)
- [x] 场地发布 (图片/视频/定位/类型)
- [x] 场地详情 (添柴/评价/排行榜)
- [x] 地图找场 (高德地图集成框架)
- [x] 俱乐部 (创建/列表/详情/加入)
- [x] 充值/支付 (第三方支付框架)
- [x] 配置文件完备 (Android/iOS)

---

## ⚠️ 上线前需要你操作的

### 1. 高德地图 API Key
申请地址: https://console.amap.com/dev/key/app
- Android 包名: `com.duichai.duichai`
- iOS Bundle ID: `com.duichai.duichai`
- 获取后替换 `AndroidManifest.xml` 和 `map_page.dart` 中的 `AMAP_API_KEY`

### 2. APP 签名
- Android: 生成 `keystore.jks` 签名文件
- iOS: 需要 Apple Developer 账号 ($99/年)

### 3. 应用商店上架
- iOS: App Store Connect 注册
- Android: Google Play Console 注册 ($25 一次性)

### 4. 配置 GitHub Secrets (你已操作 ✅)

---

## 🚀 一键打包命令

```bash
# Android APK
cd app && flutter build apk --debug
# 输出: app/build/app/outputs/flutter-apk/app-debug.apk
```

## 📦 项目总览

```
堆柴/
├── api/          — Cloudflare Workers 后端
├── app/          — Flutter APP (iOS + Android)
├── website/      — 官网下载页
├── admin/        — 管理后台
├── scripts/      — 构建/发布脚本
├── PRD.md        — 产品需求文档
└── .github/      — CI/CD 自动部署
```
