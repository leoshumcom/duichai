import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

const ADMIN_MASTER_PASSWORD = 'duichai_admin_2026';

async function getUserByEmailOrUid(env: Env, input: string): Promise<any> {
  // 支持邮箱或UID查找
  const uidNum = parseInt(input);
  if (!isNaN(uidNum) && uidNum.toString() === input) {
    return await env.duichai_db.prepare(
      'SELECT id, email, nickname, chaihuo_balance, role, uid FROM users WHERE uid = ?'
    ).bind(uidNum).first();
  }
  return await env.duichai_db.prepare(
    'SELECT id, email, nickname, chaihuo_balance, role, uid FROM users WHERE email = ?'
  ).bind(input).first();
}

// Admin login
export async function handleAdminLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password } = body;

    if (password !== ADMIN_MASTER_PASSWORD) {
      return jsonResponse({ error: 'Wrong password' }, 401);
    }

    let user: any = await getUserByEmailOrUid(env, email || '');
    if (!user) return jsonResponse({ error: 'User not found' }, 404);

    if (user.role !== 'admin' && user.role !== 'super_admin') {
      await env.duichai_db.prepare(
        "UPDATE users SET role = 'admin' WHERE id = ?"
      ).bind(user.id).run();
      const existingAdmin: any = await env.duichai_db.prepare(
        'SELECT id FROM admin_users WHERE id = ?'
      ).bind(user.id).first();
      if (!existingAdmin) {
        await env.duichai_db.prepare(
          'INSERT INTO admin_users (id, role) VALUES (?, ?)'
        ).bind(user.id, 'super_admin').run();
      }
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

    const user: any = await getUserByEmailOrUid(env, email);
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
      env.duichai_db.prepare("SELECT COUNT(DISTINCT user_id) as count FROM sessions WHERE datetime(created_at) > datetime('now', '-1 day')").first(),
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

// Admin user list
export async function handleAdminUsers(request: Request, env: Env): Promise<Response> {
  try {
    const users: any = await env.duichai_db.prepare(`
      SELECT id, uid, email, nickname, phone, role, level, chaihuo_balance, invite_code, created_at
      FROM users
      ORDER BY created_at DESC
      LIMIT 100
    `).all();
    return jsonResponse({ success: true, data: users.results });
  } catch (e) {
    return jsonResponse({ error: 'Failed to fetch users' }, 500);
  }
}

// Admin venue list (all venues including pending)
export async function handleAdminVenues(request: Request, env: Env): Promise<Response> {
  try {
    const venues: any = await env.duichai_db.prepare(`
      SELECT v.*, u.nickname as publisher_name
      FROM venues v
      LEFT JOIN users u ON v.publisher_id = u.id
      ORDER BY v.created_at DESC
      LIMIT 100
    `).all();
    const parsed = venues.results.map((v: any) => ({
      ...v,
      photos: JSON.parse(v.photos || '[]'),
    }));
    return jsonResponse({ success: true, data: parsed });
  } catch (e) {
    return jsonResponse({ error: 'Failed to fetch venues' }, 500);
  }
}

// Admin approve venue
export async function handleAdminApproveVenue(request: Request, env: Env, venueId: string): Promise<Response> {
  try {
    const venue: any = await env.duichai_db.prepare(
      'SELECT id, status FROM venues WHERE id = ?'
    ).bind(venueId).first();
    if (!venue) return jsonResponse({ error: 'Venue not found' }, 404);

    await env.duichai_db.prepare(
      "UPDATE venues SET status = 'approved', updated_at = datetime('now') WHERE id = ?"
    ).bind(venueId).run();

    return jsonResponse({ success: true, message: 'Venue approved' });
  } catch (e) {
    return jsonResponse({ error: 'Failed to approve venue' }, 500);
  }
}
