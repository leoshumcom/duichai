import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

const ADMIN_MASTER_PASSWORD = 'duichai_admin_2026';

async function getUserByEmail(env: Env, email: string): Promise<any> {
  return await env.duichai_db.prepare(
    'SELECT id, email, nickname, chaihuo_balance, role FROM users WHERE email = ?'
  ).bind(email).first();
}

// Admin login
export async function handleAdminLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password } = body;

    if (password !== ADMIN_MASTER_PASSWORD) {
      return jsonResponse({ error: 'Wrong password' }, 401);
    }

    let user: any = await getUserByEmail(env, email || '');
    if (!user) return jsonResponse({ error: 'User not found' }, 404);

    if (user.role !== 'admin') {
      await env.duichai_db.prepare(
        "UPDATE users SET role = 'admin' WHERE id = ?"
      ).bind(user.id).run();
      await env.duichai_db.prepare(
        'INSERT OR IGNORE INTO admin_users (id, role) VALUES (?, ?)'
      ).bind(user.id, 'super_admin').run();
      user.role = 'admin';
    }

    const token = generateId() + '-' + generateId().substring(0, 8);
    await env.duichai_db.prepare(
      'INSERT OR REPLACE INTO sessions (token, user_id) VALUES (?, ?)'
    ).bind(token, user.id).run();

    return jsonResponse({
      success: true,
      data: { user_id: user.id, email: user.email, nickname: user.nickname, role: 'admin', token },
    });
  } catch (e) {
    return jsonResponse({ error: 'Login failed' }, 500);
  }
}

// Admin grant chaihuo
export async function handleGrantChaihuo(request: Request, env: Env): Promise<Response> {
  try {
    const auth = request.headers.get('Authorization');
    if (!auth || !auth.startsWith('Bearer ')) return jsonResponse({ error: 'Unauthorized' }, 401);
    const token = auth.slice(7);
    const session: any = await env.duichai_db.prepare(
      'SELECT user_id FROM sessions WHERE token = ?'
    ).bind(token).first();
    if (!session) return jsonResponse({ error: 'Invalid token' }, 401);

    const admin: any = await env.duichai_db.prepare(
      'SELECT role FROM users WHERE id = ?'
    ).bind(session.user_id).first();
    if (!admin || (admin.role !== 'admin' && admin.role !== 'super_admin')) {
      return jsonResponse({ error: 'Not admin' }, 403);
    }

    const body: any = await request.json();
    const { email, amount, reason } = body;
    if (!email || !amount || amount < 1) return jsonResponse({ error: 'email and amount required' }, 400);

    const user: any = await getUserByEmail(env, email);
    if (!user) return jsonResponse({ error: 'User not found' }, 404);

    const newBalance = (user.chaihuo_balance || 0) + amount;
    await env.duichai_db.prepare(
      'UPDATE users SET chaihuo_balance = ? WHERE id = ?'
    ).bind(newBalance, user.id).run();
    await env.duichai_db.prepare(
      "INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, description) VALUES (?, ?, 'admin_adjust', ?, ?, ?)"
    ).bind(generateId(), user.id, amount, newBalance, reason || 'Admin grant').run();

    return jsonResponse({
      success: true,
      data: { user_id: user.id, email, previous_balance: user.chaihuo_balance, new_balance: newBalance, amount },
    });
  } catch (e) {
    return jsonResponse({ error: 'Grant failed' }, 500);
  }
}

// Dashboard stats
export async function handleDashboardStats(request: Request, env: Env): Promise<Response> {
  try {
    const [totalUsers, dauResult, totalVenues, totalClubs, chaihuoStats, pendingStats] = await Promise.all([
      env.duichai_db.prepare('SELECT COUNT(*) as count FROM users').first(),
      env.duichai_db.prepare("SELECT COUNT(*) as count FROM users WHERE datetime(created_at) > datetime('now', '-1 day')").first(),
      env.duichai_db.prepare("SELECT COUNT(*) as count FROM venues WHERE status = 'approved'").first(),
      env.duichai_db.prepare("SELECT COUNT(*) as count FROM clubs WHERE status = 'active'").first(),
      env.duichai_db.prepare("SELECT COALESCE(SUM(amount), 0) as total FROM chaihuo_transactions WHERE type != 'tip_given'").first(),
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
    return jsonResponse({ error: 'Stats failed' }, 500);
  }
}

// User trend
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
    return jsonResponse({ error: 'Trend failed' }, 500);
  }
}

// Rankings
export async function handleRankings(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const type = url.searchParams.get('type') || '';
    let query = `
      SELECT v.id, v.name, v.type, v.address, v.chaihuo_total, v.photos,
             u.nickname as publisher_name
      FROM venues v
      LEFT JOIN users u ON v.publisher_id = u.id
      WHERE v.status = 'approved'
    `;
    const params: any[] = [];
    if (type) { query += ' AND v.type LIKE ?'; params.push(`%${type}%`); }
    query += ' ORDER BY v.chaihuo_total DESC LIMIT 100';

    const venues = await env.duichai_db.prepare(query).bind(...params).all();
    const parsed = venues.results.map((v: any) => ({ ...v, photos: JSON.parse(v.photos || '[]') }));
    return jsonResponse({ success: true, data: parsed, type });
  } catch (e) {
    return jsonResponse({ error: 'Rankings failed' }, 500);
  }
}
