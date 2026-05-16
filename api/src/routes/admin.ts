import { jsonResponse } from '../utils';

interface Env {
  duichai_db: D1Database;
}

// 获取数据大盘统计
export async function handleDashboardStats(request: Request, env: Env): Promise<Response> {
  try {
    const [totalUsers, dauResult, totalVenues, totalClubs, chaihuoStats, pendingStats] = await Promise.all([
      env.duichai_db.prepare('SELECT COUNT(*) as count FROM users').first(),
      env.duichai_db.prepare("SELECT COUNT(*) as count FROM users WHERE datetime(created_at) > datetime('now', '-1 day')").first(),
      env.duichai_db.prepare("SELECT COUNT(*) as count FROM venues WHERE status = 'approved'").first(),
      env.duichai_db.prepare("SELECT COUNT(*) as count FROM clubs WHERE status = 'active'").first(),
      env.duichai_db.prepare('SELECT COALESCE(SUM(amount), 0) as total FROM chaihuo_transactions WHERE type != ?').bind('tip_given').first(),
      env.duichai_db.prepare("SELECT type, COUNT(*) as count FROM (SELECT 'venue' as type FROM venues WHERE status = 'pending' UNION ALL SELECT 'owner' FROM venue_owner_applications WHERE status = 'pending' UNION ALL SELECT 'club' FROM club_certifications WHERE status = 'pending' UNION ALL SELECT 'report' FROM reports WHERE status = 'pending') GROUP BY type").all(),
    ]);

    const pendingMap: Record<string, number> = {};
    pendingStats.results.forEach((r: any) => { pendingMap[r.type] = r.count; });

    return jsonResponse({
      success: true,
      data: {
        total_users: (totalUsers as any)?.count || 0,
        dau: (dauResult as any)?.count || 0,
        total_venues: (totalVenues as any)?.count || 0,
        total_clubs: (totalClubs as any)?.count || 0,
        total_chaihuo: (chaihuoStats as any)?.total || 0,
        pending: {
          venues: pendingMap['venue'] || 0,
          owners: pendingMap['owner'] || 0,
          clubs: pendingMap['club'] || 0,
          reports: pendingMap['report'] || 0,
        },
      },
    });
  } catch (e) {
    return jsonResponse({ error: '获取数据失败' }, 500);
  }
}

// 获取用户趋势（近7天）
export async function handleUserTrend(request: Request, env: Env): Promise<Response> {
  try {
    const trend = await env.duichai_db.prepare(`
      SELECT date(created_at) as date, COUNT(*) as count
      FROM users
      WHERE created_at > datetime('now', '-7 days')
      GROUP BY date(created_at)
      ORDER BY date
    `).all();

    return jsonResponse({ success: true, data: trend.results });
  } catch (e) {
    return jsonResponse({ error: '获取趋势失败' }, 500);
  }
}

// 获取排名
export async function handleRankings(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const level = url.searchParams.get('level') || 'national';
    const type = url.searchParams.get('type') || '';
    const sort = url.searchParams.get('sort') || 'chaihuo';

    let query = `
      SELECT v.id, v.name, v.type, v.address, v.chaihuo_total, v.photos,
             u.nickname as publisher_name
      FROM venues v
      LEFT JOIN users u ON v.publisher_id = u.id
      WHERE v.status = 'approved'
    `;
    const params: any[] = [];

    if (type) {
      query += ' AND v.type LIKE ?';
      params.push(`%${type}%`);
    }

    query += ' ORDER BY v.chaihuo_total DESC LIMIT 100';

    const venues = await env.duichai_db.prepare(query).bind(...params).all();
    const parsed = venues.results.map((v: any) => ({
      ...v,
      photos: JSON.parse(v.photos || '[]'),
    }));

    return jsonResponse({ success: true, data: parsed, level, type, sort });
  } catch (e) {
    return jsonResponse({ error: '获取排名失败' }, 500);
  }
}
