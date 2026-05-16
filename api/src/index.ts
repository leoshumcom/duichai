/**
 * 堆柴 API 入口
 * Cloudflare Workers + D1 + R2
 */

import { Router } from './router';
import { initDB } from './db/init';

interface Env {
  duichai_db: D1Database;
  duichai_assets: R2Bucket;
  APP_NAME: string;
  ENV: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const router = new Router();

    // CORS 预检
    router.add('OPTIONS', '/*', () => {
      return new Response(null, {
        headers: corsHeaders(request),
      });
    });

    // 健康检查
    router.add('GET', '/api/health', async () => {
      return jsonResponse({
        app: env.APP_NAME,
        status: 'ok',
        env: env.ENV,
        timestamp: new Date().toISOString(),
      });
    });

    // 数据库初始化（仅开发环境）
    router.add('POST', '/api/db/init', async () => {
      if (env.ENV !== 'development') {
        return jsonResponse({ error: 'Not allowed in production' }, 403);
      }
      await initDB(env.duichai_db);
      return jsonResponse({ success: true, message: 'Database initialized' });
    });

    // === 用户路由 ===
    router.add('POST', '/api/auth/register', async (req) => {
      return await handleRegister(req, env);
    });

    router.add('POST', '/api/auth/login', async (req) => {
      return await handleLogin(req, env);
    });

    // 404
    router.add('ALL', '/*', () => {
      return jsonResponse({ error: 'Not Found' }, 404);
    });

    return router.handle(request);
  },
};

// ===== 工具函数 =====

function jsonResponse(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') || '*';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

// ===== 用户认证处理（占位） =====

async function handleRegister(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password, nickname } = body;

    if (!email || !password || !nickname) {
      return jsonResponse({ error: 'email, password, nickname 为必填' }, 400);
    }

    // TODO: 密码加密 + 邮箱验证 + 发送验证邮件
    return jsonResponse({ message: '注册成功' });
  } catch (e) {
    return jsonResponse({ error: '请求格式错误' }, 400);
  }
}

async function handleLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return jsonResponse({ error: 'email, password 为必填' }, 400);
    }

    // TODO: 密码验证 + Token 生成
    return jsonResponse({ message: '登录成功' });
  } catch (e) {
    return jsonResponse({ error: '请求格式错误' }, 400);
  }
}
