/**
 * 用户个人中心相关路由
 * 我的添柴、勋章、俱乐部、场地、邀请
 */
import { jsonResponse } from '../utils';

interface Env {
  duichai_db: D1Database;
}

/// 获取用户ID（从Authorization头）
async function getUserId(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

/// 我的添柴记录
export async function handleMyTips(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  const tips: any[] = await env.duichai_db.prepare(`
    SELECT ct.*, v.name as venue_name, v.photos as venue_photos
    FROM chaihuo_transactions ct
    LEFT JOIN venues v ON ct.reference_id = v.id
    WHERE ct.user_id = ? AND ct.type = 'tip_given'
    ORDER BY ct.created_at DESC
    LIMIT 50
  `).bind(userId).all();

  const parsed = tips.results.map((t: any) => ({
    ...t,
    venue_photos: t.venue_photos ? JSON.parse(t.venue_photos) : [],
  }));

  return jsonResponse({ success: true, data: parsed });
}

/// 我的勋章
export async function handleMyBadges(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  const badges: any[] = await env.duichai_db.prepare(`
    SELECT b.id, b.name, b.icon, b.description, b.criteria, ub.earned_at
    FROM user_badges ub
    JOIN badges b ON ub.badge_id = b.id
    WHERE ub.user_id = ?
    ORDER BY ub.earned_at DESC
  `).bind(userId).all();

  // 所有可获得的勋章
  const allBadges: any[] = await env.duichai_db.prepare(`
    SELECT b.*, ub.earned_at FROM badges b
    LEFT JOIN user_badges ub ON ub.badge_id = b.id AND ub.user_id = ?
    ORDER BY b.id
  `).bind(userId).all();

  const earned = badges.results.map((b: any) => b.id);

  return jsonResponse({
    success: true,
    data: {
      earned: badges.results,
      all: allBadges.results.map((b: any) => ({
        ...b,
        earned: earned.includes(b.id),
      })),
    },
  });
}

/// 我的俱乐部
export async function handleMyClubs(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  const clubs: any[] = await env.duichai_db.prepare(`
    SELECT c.*, cm.role
    FROM club_members cm
    JOIN clubs c ON cm.club_id = c.id
    WHERE cm.user_id = ?
    ORDER BY cm.role, c.created_at DESC
  `).bind(userId).all();

  return jsonResponse({ success: true, data: clubs.results });
}

/// 我发布的场地
export async function handleMyVenues(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  const venues: any[] = await env.duichai_db.prepare(`
    SELECT v.*, u.nickname as publisher_name
    FROM venues v
    LEFT JOIN users u ON v.publisher_id = u.id
    WHERE v.publisher_id = ?
    ORDER BY v.created_at DESC
    LIMIT 50
  `).bind(userId).all();

  const parsed = venues.results.map((v: any) => ({
    ...v,
    photos: JSON.parse(v.photos || '[]'),
    videos: JSON.parse(v.videos || '[]'),
  }));

  return jsonResponse({ success: true, data: parsed });
}

/// 邀请记录
export async function handleMyInvites(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  // 获取该用户信息（含邀请码）
  const user: any = await env.duichai_db.prepare(
    'SELECT id, nickname, invite_code FROM users WHERE id = ?'
  ).bind(userId).first();

  // 邀请记录
  const invites: any[] = await env.duichai_db.prepare(`
    SELECT i.*, u.nickname as invitee_name
    FROM invites i
    LEFT JOIN users u ON i.invitee_id = u.id
    WHERE i.inviter_id = ?
    ORDER BY i.created_at DESC
  `).bind(userId).all();

  return jsonResponse({
    success: true,
    data: {
      invite_code: user?.invite_code || '',
      invite_link: `https://duichai.com/invite/${user?.invite_code || ''}`,
      count: invites.results.length,
      invites: invites.results,
    },
  });
}

/// 通知列表
export async function handleNotifications(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: "未登录" }, 401);

  const url = new URL(request.url);
  const page = parseInt(url.searchParams.get("page") || "1");
  const limit = parseInt(url.searchParams.get("limit") || "20");
  const offset = (page - 1) * limit;

  const notifications: any[] = await env.duichai_db.prepare(
    "SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?"
  ).bind(userId, limit, offset).all();

  const unreadCount: any = await env.duichai_db.prepare(
    "SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0"
  ).bind(userId).first();

  return jsonResponse({
    success: true,
    data: notifications.results,
    unread_count: unreadCount?.count || 0,
    page, limit,
  });
}

/// 标记通知已读
export async function handleMarkRead(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: "未登录" }, 401);

  const body: any = await request.json();
  const { notification_id } = body;

  if (notification_id) {
    await env.duichai_db.prepare(
      "UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?"
    ).bind(notification_id, userId).run();
  } else {
    await env.duichai_db.prepare(
      "UPDATE notifications SET is_read = 1 WHERE user_id = ?"
    ).bind(userId).run();
  }

  return jsonResponse({ success: true });
}

/// 更新头像
export async function handleUpdateAvatar(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: "未登录" }, 401);

  const body: any = await request.json();
  const { avatar_url } = body;

  if (!avatar_url) return jsonResponse({ error: "avatar_url 为必填" }, 400);

  await env.duichai_db.prepare(
    "UPDATE users SET avatar = ?, updated_at = datetime('now') WHERE id = ?"
  ).bind(avatar_url, userId).run();

  return jsonResponse({ success: true, avatar_url });
}

/// 更新用户资料
export async function handleUpdateProfile(request: Request, env: Env): Promise<Response> {
  const userId = await getUserId(request, env);
  if (!userId) return jsonResponse({ error: "未登录" }, 401);

  const body: any = await request.json();
  const { nickname, phone } = body;

  if (nickname) {
    await env.duichai_db.prepare(
      "UPDATE users SET nickname = ?, updated_at = datetime('now') WHERE id = ?"
    ).bind(nickname, userId).run();
  }
  if (phone !== undefined) {
    await env.duichai_db.prepare(
      "UPDATE users SET phone = ?, updated_at = datetime('now') WHERE id = ?"
    ).bind(phone, userId).run();
  }

  return jsonResponse({ success: true });
}
