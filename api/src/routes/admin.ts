import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

// 按 total_chaihuo_earned 自动同步用户等级
async function _syncUserLevel(env: Env, userId: string): Promise<void> {
  const levelRow: any = await env.duichai_db.prepare(`
    SELECT MAX(level) as new_level FROM user_levels 
    WHERE min_chaihuo <= (SELECT COALESCE(total_chaihuo_earned, 0) FROM users WHERE id = ?)
  `).bind(userId).first();
  if (levelRow?.new_level) {
    await env.duichai_db.prepare('UPDATE users SET level = ? WHERE id = ? AND level < ?')
      .bind(levelRow.new_level, userId, levelRow.new_level).run();
  }
}

const ADMIN_MASTER_PASSWORD = 'Qq141516@';

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
    // 同步更新总获取柴火和等级
    await env.duichai_db.prepare(
      'UPDATE users SET chaihuo_balance = ?, total_chaihuo_earned = total_chaihuo_earned + ? WHERE id = ?'
    ).bind(newBalance, amount, user.id).run();
    // 按 total_chaihuo_earned 自动计算等级
    await _syncUserLevel(env, user.id);
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
// 管理员删除场地（惩罚）
export async function handleAdminDeleteVenue(request: Request, env: Env, venueId: string): Promise<Response> {
  try {
    const venue: any = await env.duichai_db.prepare(
      'SELECT id, publisher_id, name FROM venues WHERE id = ?'
    ).bind(venueId).first();
    if (!venue) return jsonResponse({ error: 'Venue not found' }, 404);

    // 扣除发布者110根柴火（100惩罚+10管理费）
    const publisherId = venue.publisher_id;
    const user: any = await env.duichai_db.prepare(
      'SELECT chaihuo_balance FROM users WHERE id = ?'
    ).bind(publisherId).first();
    const deduction = 110;
    const newBalance = Math.max((user?.chaihuo_balance || 0) - deduction, 0);

    await env.duichai_db.prepare(
      'UPDATE users SET chaihuo_balance = ? WHERE id = ?'
    ).bind(newBalance, publisherId).run();

    // 记录扣罚流水
    await env.duichai_db.prepare(`
      INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, reference_id, reference_type, description)
      VALUES (?, ?, 'admin_adjust', ?, ?, ?, 'venue', '恶意发布扣除惩罚110根柴火')
    `).bind(generateId(), publisherId, -deduction, newBalance, venueId).run();

    // 软删除场地
    await env.duichai_db.prepare(
      "UPDATE venues SET status = 'deleted', updated_at = datetime('now') WHERE id = ?"
    ).bind(venueId).run();

    return jsonResponse({ success: true, message: '场地已删除，已扣除发布者110根柴火' });
  } catch (e) {
    return jsonResponse({ error: 'Failed to delete venue' }, 500);
  }
}

// 馆主认证申请列表
export async function handleAdminOwnerApplications(request: Request, env: Env): Promise<Response> {
  try {
    const url = new URL(request.url);
    const status = url.searchParams.get('status') || 'pending';
    const apps: any[] = await env.duichai_db.prepare(`
      SELECT a.*, u.nickname, u.email, u.phone as user_phone
      FROM venue_owner_applications a
      LEFT JOIN users u ON a.user_id = u.id
      WHERE a.status = ?
      ORDER BY a.created_at DESC
      LIMIT 50
    `).bind(status).all();

    return jsonResponse({ success: true, data: apps.results });
  } catch (e) {
    return jsonResponse({ error: 'Failed to fetch applications' }, 500);
  }
}

// 审核馆主认证申请
export async function handleAdminApproveOwnerApplication(request: Request, env: Env, appId: string): Promise<Response> {
  try {
    const app: any = await env.duichai_db.prepare(
      "SELECT * FROM venue_owner_applications WHERE id = ? AND status = 'pending'"
    ).bind(appId).first();
    if (!app) return jsonResponse({ error: 'Application not found or already processed' }, 404);

    // 更新申请状态
    await env.duichai_db.prepare(`
      UPDATE venue_owner_applications SET status = 'approved', reviewed_at = datetime('now'), reviewed_by = ? WHERE id = ?
    `).bind(app.user_id, appId).run();

    // 升级用户角色为owner
    await env.duichai_db.prepare(
      "UPDATE users SET role = 'owner', updated_at = datetime('now') WHERE id = ?"
    ).bind(app.user_id).run();

    // 更新该用户发布的所有场地的 owner_id
    await env.duichai_db.prepare(
      "UPDATE venues SET owner_id = ?, updated_at = datetime('now') WHERE publisher_id = ? AND (owner_id IS NULL OR owner_id = '')"
    ).bind(app.user_id, app.user_id).run();

    return jsonResponse({ success: true, message: '馆主认证通过' });
  } catch (e) {
    return jsonResponse({ error: 'Failed to approve' }, 500);
  }
}

export async function handleAdminRejectOwnerApplication(request: Request, env: Env, appId: string): Promise<Response> {
  try {
    const body: any = await request.json();
    const { reject_reason } = body;

    await env.duichai_db.prepare(`
      UPDATE venue_owner_applications SET status = 'rejected', reject_reason = ?, reviewed_at = datetime('now') WHERE id = ? AND status = 'pending'
    `).bind(reject_reason || '资料不符合要求', appId).run();

    return jsonResponse({ success: true, message: '已拒绝申请' });
  } catch (e) {
    return jsonResponse({ error: 'Failed to reject' }, 500);
  }
}

// === Club Management ===
// 俱乐部列表
export async function handleAdminClubs(request: Request, env: Env): Promise<Response> {
  try {
    const clubs: any[] = await env.duichai_db.prepare(`
      SELECT c.*, u.nickname as creator_name, u.email as creator_email
      FROM clubs c
      LEFT JOIN users u ON c.creator_id = u.id
      ORDER BY c.created_at DESC
      LIMIT 50
    `).all();

    return jsonResponse({ success: true, data: clubs.results });
  } catch (e) {
    return jsonResponse({ error: 'Failed to fetch clubs' }, 500);
  }
}

// 俱乐部认证申请列表
export async function handleAdminClubCertifications(request: Request, env: Env): Promise<Response> {
  try {
    const certs: any[] = await env.duichai_db.prepare(`
      SELECT cc.*, c.name as club_name, u.nickname as applicant_name, u.email as applicant_email
      FROM club_certifications cc
      LEFT JOIN clubs c ON cc.club_id = c.id
      LEFT JOIN users u ON cc.applicant_id = u.id
      WHERE cc.status = 'pending'
      ORDER BY cc.created_at DESC
      LIMIT 50
    `).all();

    return jsonResponse({ success: true, data: certs.results });
  } catch (e) {
    return jsonResponse({ error: 'Failed to fetch certifications' }, 500);
  }
}

// 批准俱乐部认证
export async function handleAdminApproveClubCert(request: Request, env: Env, certId: string): Promise<Response> {
  try {
    const cert: any = await env.duichai_db.prepare(
      "SELECT * FROM club_certifications WHERE id = ? AND status = 'pending'"
    ).bind(certId).first();
    if (!cert) return jsonResponse({ error: 'Certification not found' }, 404);

    await env.duichai_db.prepare(`
      UPDATE club_certifications SET status = 'approved', reviewed_at = datetime('now') WHERE id = ?
    `).bind(certId).run();

    // 标记俱乐部已认证
    await env.duichai_db.prepare(
      'UPDATE clubs SET is_certified = 1 WHERE id = ?'
    ).bind(cert.club_id).run();

    return jsonResponse({ success: true, message: '俱乐部认证通过' });
  } catch (e) {
    return jsonResponse({ error: 'Failed to approve' }, 500);
  }
}

// 拒绝俱乐部认证
export async function handleAdminRejectClubCert(request: Request, env: Env, certId: string): Promise<Response> {
  try {
    const body: any = await request.json();
    await env.duichai_db.prepare(`
      UPDATE club_certifications SET status = 'rejected', reject_reason = ?, reviewed_at = datetime('now') WHERE id = ? AND status = 'pending'
    `).bind(body?.reject_reason || '资料不符', certId).run();

    return jsonResponse({ success: true, message: '已拒绝认证' });
  } catch (e) {
    return jsonResponse({ error: 'Failed to reject' }, 500);
  }
}

// 用户等级信息
export async function handleLevelInfo(request: Request, env: Env): Promise<Response> {
  try {
    const auth = request.headers.get('Authorization');
    if (!auth || !auth.startsWith('Bearer ')) return jsonResponse({ error: '未登录' }, 401);
    const token = auth.slice(7);
    const session: any = await env.duichai_db.prepare(
      'SELECT user_id FROM sessions WHERE token = ?'
    ).bind(token).first();
    if (!session) return jsonResponse({ error: '未登录' }, 401);

    const userId = session.user_id;
    const user: any = await env.duichai_db.prepare(
      'SELECT level, chaihuo_balance FROM users WHERE id = ?'
    ).bind(userId).first();
    if (!user) return jsonResponse({ error: 'User not found' }, 404);

    // 获取所有等级
    const levels: any[] = await env.duichai_db.prepare(`
      SELECT * FROM user_levels ORDER BY level ASC
    `).all();

    const currentLevel = user.level || 1;
    const chaihuoBalance = user.chaihuo_balance || 0;

    // 找到当前等级和下一等级
    let currentLevelData = null;
    let nextLevelData = null;
    let progress = 100;
    let currentMin = 0;
    let nextMin = 0;

    for (const l of levels.results) {
      if (l.level === currentLevel) {
        currentLevelData = l;
        currentMin = l.min_chaihuo;
      }
      if (l.level === currentLevel + 1) {
        nextLevelData = l;
        nextMin = l.min_chaihuo;
      }
    }

    if (nextLevelData) {
      const range = nextMin - currentMin;
      const earned = chaihuoBalance - currentMin;
      progress = range > 0 ? Math.min(Math.floor((earned / range) * 100), 99) : 100;
    } else {
      progress = 100;
    }

    return jsonResponse({
      success: true,
      data: {
        current_level: currentLevel,
        current_name: currentLevelData?.name || '',
        next_level: nextLevelData?.level || null,
        next_name: nextLevelData?.name || null,
        current_chaihuo: chaihuoBalance,
        current_min_chaihuo: currentMin,
        next_min_chaihuo: nextMin || null,
        progress_pct: progress,
        is_max_level: !nextLevelData,
      },
    });
  } catch (e) {
    return jsonResponse({ error: 'Failed' }, 500);
  }
}

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
