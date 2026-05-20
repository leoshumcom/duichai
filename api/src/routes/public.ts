/**
 * 公开统计接口 - 首页数据
 */
import { jsonResponse } from '../utils';

interface Env {
  duichai_db: D1Database;
}

export async function handlePublicStats(request: Request, env: Env): Promise<Response> {
  const results: any = await env.duichai_db.prepare(`
    SELECT 
      (SELECT COUNT(*) FROM venues WHERE status = 'approved') as total_venues,
      (SELECT COUNT(*) FROM users) as total_users,
      (SELECT COUNT(*) FROM clubs WHERE status = 'active') as total_clubs,
      (SELECT COALESCE(SUM(chaihuo_total), 0) FROM venues) as total_chaihuo
  `).first();

  const data = {
    success: true,
    data: {
      venues: results?.total_venues || 0,
      users: results?.total_users || 0,
      clubs: results?.total_clubs || 0,
      chaihuo: results?.total_chaihuo || 0,
    },
  };

  const response = jsonResponse(data);
  // Add CORS headers for website access
  response.headers.set('Access-Control-Allow-Origin', '*');
  return response;
}
