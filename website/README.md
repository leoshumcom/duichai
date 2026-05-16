# 堆柴官网

## 部署方式：Cloudflare Pages

### 自动部署（推荐）

1. 将 `website/` 目录推送到 GitHub 仓库
2. 在 Cloudflare Dashboard → Workers & Pages → 创建 Pages 项目
3. 连接 GitHub 仓库
4. 构建配置：
   - 框架预设：None
   - 构建命令：无（纯静态）
   - 构建输出目录：`website/`
5. 自定义域名：`www.duichai.com`

### 手动部署

```bash
npx wrangler pages deploy website/ --project-name=duichai
```

## 开发

```bash
# 本地预览
npx wrangler pages dev website/
```
