/**
 * 堆柴 API - Cloudflare Workers
 * 众人拾柴火焰高 🔥
 */

import { Router } from './router';
import { jsonResponse, corsHeaders } from './utils';
import { initDB } from './db/init';
import { handleRegister, handleLogin, handleGetUser } from './routes/auth';
import { handleCreateVenue, handleGetVenue, handleSearchVenues, handleTipVenue, handleSupplementVenue } from './routes/venues';

interface Env {
  duichai_db: D1Database;
  duichai_assets?: R2Bucket;
  APP_NAME: string;
  ENV: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const router = new Router();

    // CORS 预检
    router.add('OPTIONS', '/*', (req) => {
      return new Response(null, { headers: corsHeaders(req) });
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

    // ===== 用户认证 =====
    router.add('POST', '/api/auth/register', async (req) => handleRegister(req, env));
    router.add('POST', '/api/auth/login', async (req) => handleLogin(req, env));
    router.add('GET', '/api/users/:id', async (req, params) => handleGetUser(req, env, params.id));

    // ===== 场地 =====
    router.add('POST', '/api/venues', async (req) => handleCreateVenue(req, env));
    router.add('GET', '/api/venues/:id', async (req, params) => handleGetVenue(req, env, params.id));
    router.add('GET', '/api/venues', async (req) => handleSearchVenues(req, env));
    router.add('POST', '/api/venues/tip', async (req) => handleTipVenue(req, env));
    router.add('POST', '/api/venues/supplement', async (req) => handleSupplementVenue(req, env));

    // 404
    router.add('ALL', '/*', () => {
      return jsonResponse({ error: 'Not Found', code: 404 }, 404);
    });

    return router.handle(request);
  },
};
