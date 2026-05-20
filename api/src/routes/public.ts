/**
 * 公开统计接口 - 首页数据
 */
import { jsonResponse } from '../utils';

interface Env {
  duichai_db: D1Database;
  duichai_assets?: R2Bucket;
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

/**
 * APK 下载
 * GET /api/download/android
 * 从 R2 提供最新 APK 文件
 */
export async function handleDownloadApk(request: Request, env: Env): Promise<Response> {
  try {
    const object = await env.duichai_assets?.get('downloads/duichai-latest.apk');
    if (!object) {
      return new Response('APK not found', { status: 404 });
    }

    const headers = new Headers({
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Disposition': 'attachment; filename="duichai-latest.apk"',
      'Cache-Control': 'public, max-age=3600',
    });

    return new Response(object.body, { headers });
  } catch (e) {
    return new Response('Download failed', { status: 500 });
  }
}
