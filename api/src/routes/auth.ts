/**
 * 用户认证路由
 */

import { jsonResponse, generateId, generateInviteCode, hashPassword, verifyPassword } from '../utils';

interface Env {
  duichai_db: D1Database;
}

// 从Authorization头获取用户ID
async function getUserIdFromToken(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

// 自动分配下一个可用UID（从10000开始）
async function generateNextUid(env: Env): Promise<number> {
  const maxRow: any = await env.duichai_db.prepare(
    'SELECT COALESCE(MAX(uid), 9999) + 1 as next_uid FROM users'
  ).first();
  return maxRow?.next_uid || 10000;
}

export async function handleRegister(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password, nickname, phone, invite_code } = body;

    if (!email || !password || !nickname) {
      return jsonResponse({ error: 'email, password, nickname 为必填' }, 400);
    }
    if (password.length < 6) {
      return jsonResponse({ error: '密码至少6位' }, 400);
    }

    const existing = await env.duichai_db.prepare(
      'SELECT id FROM users WHERE email = ?'
    ).bind(email).first();

    if (existing) {
      return jsonResponse({ error: '该邮箱已注册' }, 409);
    }

    const id = generateId();
    const passwordHash = await hashPassword(password);
    const uid = await generateNextUid(env);
    // 邀请码 = UID（数字UID作为邀请码）
    const inviteCode = uid.toString();

    // 检查邀请码（支持UID数字或旧版字母邀请码）
    let inviterId: string | null = null;
    if (invite_code) {
      const code = invite_code.trim();
      let inviter: any = null;
      // 先按UID（纯数字）查找
      const codeAsUid = parseInt(code);
      if (!isNaN(codeAsUid)) {
        inviter = await env.duichai_db.prepare(
          'SELECT id FROM users WHERE uid = ?'
        ).bind(codeAsUid).first();
      }
      // 再按旧版邀请码查找
      if (!inviter) {
        inviter = await env.duichai_db.prepare(
          'SELECT id FROM users WHERE invite_code = ?'
        ).bind(code).first();
      }
      if (inviter) {
        inviterId = inviter.id;
      }
    }

    await env.duichai_db.prepare(`
      INSERT INTO users (id, email, nickname, phone, password_hash, invite_code, invited_by, chaihuo_balance, uid)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
    `).bind(id, email, nickname, phone || null, passwordHash, inviteCode, inviterId, uid).run();

    await env.duichai_db.prepare(`
      INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, description)
      VALUES (?, ?, 'login_bonus', 1, 1, '注册赠送1根柴火')
    `).bind(generateId(), id).run();

    // 邀请奖励：双方各+10柴火
    if (inviterId) {
      // 记录邀请关系
      await env.duichai_db.prepare(`
        INSERT INTO invites (id, inviter_id, invitee_id, reward_chaihuo)
        VALUES (?, ?, ?, 10)
      `).bind(generateId(), inviterId, id).run();

      // 给邀请者+10
      const inviterUser: any = await env.duichai_db.prepare(
        'SELECT chaihuo_balance FROM users WHERE id = ?'
      ).bind(inviterId).first();
      const inviterNewBalance = (inviterUser?.chaihuo_balance || 0) + 10;
      await env.duichai_db.prepare(
        'UPDATE users SET chaihuo_balance = ?, total_chaihuo_earned = total_chaihuo_earned + 10 WHERE id = ?'
      ).bind(inviterNewBalance, inviterId).run();
      await env.duichai_db.prepare(`
        INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, reference_id, reference_type, description)
        VALUES (?, ?, 'invite', 10, ?, ?, 'invite', '邀请好友奖励')
      `).bind(generateId(), inviterId, inviterNewBalance, id).run();

      // 给被邀请者+10
      await env.duichai_db.prepare(
        'UPDATE users SET chaihuo_balance = chaihuo_balance + 10, total_chaihuo_earned = total_chaihuo_earned + 10 WHERE id = ?'
      ).bind(id).run();
      await env.duichai_db.prepare(`
        INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, description)
        VALUES (?, ?, 'invite', 10, 11, '使用邀请码奖励')
      `).bind(generateId(), id).run();
    }

    return jsonResponse({
      success: true,
      message: '注册成功' + (inviterId ? '，获得10根邀请奖励柴火🔥' : ''),
      data: { user_id: id, uid, nickname, invite_code: inviteCode },
    }, 201);
  } catch (_) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

export async function handleLogin(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return jsonResponse({ error: 'email, password 为必填' }, 400);
    }

    // 支持邮箱或UID登录
    let user: any;
    if (email.includes('@')) {
      user = await env.duichai_db.prepare(
        'SELECT id, email, nickname, phone, avatar, password_hash, role, level, chaihuo_balance, invite_code, uid FROM users WHERE email = ?'
      ).bind(email).first();
    } else {
      const uidNum = parseInt(email);
      if (isNaN(uidNum)) {
        return jsonResponse({ error: '邮箱或UID格式不正确' }, 400);
      }
      user = await env.duichai_db.prepare(
        'SELECT id, email, nickname, phone, avatar, password_hash, role, level, chaihuo_balance, invite_code, uid FROM users WHERE uid = ?'
      ).bind(uidNum).first();
    }

    if (!user) {
      return jsonResponse({ error: '邮箱/UID或密码错误' }, 401);
    }

    const valid = await verifyPassword(password, user.password_hash);
    if (!valid) {
      return jsonResponse({ error: '邮箱/UID或密码错误' }, 401);
    }

    const token = generateId() + '-' + generateId().substring(0, 8);
    await env.duichai_db.prepare(
      'INSERT OR REPLACE INTO sessions (token, user_id) VALUES (?, ?)'
    ).bind(token, user.id).run();

    return jsonResponse({
      success: true,
      data: {
        user_id: user.id,
        email: user.email,
        nickname: user.nickname,
        phone: user.phone,
        avatar: user.avatar,
        role: user.role,
        level: user.level,
        chaihuo_balance: user.chaihuo_balance,
        uid: user.uid,
        token,
      },
    });
  } catch (_) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 专用UID+密码登录
export async function handleLoginByUid(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { uid, password } = body;

    if (!uid || !password) {
      return jsonResponse({ error: 'uid, password 为必填' }, 400);
    }

    const user: any = await env.duichai_db.prepare(
      'SELECT id, email, nickname, phone, avatar, password_hash, role, level, chaihuo_balance, invite_code, uid FROM users WHERE uid = ?'
    ).bind(uid).first();

    if (!user) {
      return jsonResponse({ error: 'UID或密码错误' }, 401);
    }

    const valid = await verifyPassword(password, user.password_hash);
    if (!valid) {
      return jsonResponse({ error: 'UID或密码错误' }, 401);
    }

    const token = generateId() + '-' + generateId().substring(0, 8);
    await env.duichai_db.prepare(
      'INSERT OR REPLACE INTO sessions (token, user_id) VALUES (?, ?)'
    ).bind(token, user.id).run();

    return jsonResponse({
      success: true,
      data: {
        user_id: user.id,
        email: user.email,
        nickname: user.nickname,
        phone: user.phone,
        avatar: user.avatar,
        role: user.role,
        level: user.level,
        chaihuo_balance: user.chaihuo_balance,
        uid: user.uid,
        token,
      },
    });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 获取当前用户UID信息（含靓号购买状态）
export async function handleGetMyUid(request: Request, env: Env): Promise<Response> {
  const userId = await getUserIdFromToken(request, env);
  if (!userId) {
    return jsonResponse({ error: '未登录' }, 401);
  }

  const user: any = await env.duichai_db.prepare(
    'SELECT id, uid, email, nickname FROM users WHERE id = ?'
  ).bind(userId).first();

  if (!user) {
    return jsonResponse({ error: '用户不存在' }, 404);
  }

  // 检查是否有靓号订单
  const uidOrder: any = await env.duichai_db.prepare(
    "SELECT uid, price, status, paid_at FROM uid_orders WHERE buyer_id = ? AND status = 'paid' ORDER BY created_at DESC LIMIT 1"
  ).bind(userId).first();

  return jsonResponse({
    success: true,
    data: {
      uid: user.uid,
      nickname: user.nickname,
      email: user.email,
      uid_order: uidOrder || null,
    },
  });
}

async function getUserFromToken(request: Request, env: Env): Promise<any | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);

  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();

  if (!session) return null;

  const user: any = await env.duichai_db.prepare(
    'SELECT id, email, nickname, phone, avatar, role, level, chaihuo_balance, total_chaihuo_earned, invite_code, uid, created_at FROM users WHERE id = ?'
  ).bind(session.user_id).first();

  return user;
}

export async function handleGetMe(request: Request, env: Env): Promise<Response> {
  const user = await getUserFromToken(request, env);
  if (!user) {
    return jsonResponse({ error: '未登录或Token已过期' }, 401);
  }
  return jsonResponse({ success: true, data: user });
}

export async function handleGetUser(request: Request, env: Env, userId: string): Promise<Response> {
  const user: any = await env.duichai_db.prepare(
    'SELECT id, email, nickname, phone, avatar, role, level, chaihuo_balance, total_chaihuo_earned, invite_code, uid, created_at FROM users WHERE id = ?'
  ).bind(userId).first();

  if (!user) {
    return jsonResponse({ error: '用户不存在' }, 404);
  }

  return jsonResponse({ success: true, data: user });
}

// 管理: 为指定用户设置UID（仅管理员）
export async function handleSetUserUid(request: Request, env: Env): Promise<Response> {
  const adminId = await getUserIdFromToken(request, env);
  if (!adminId) return jsonResponse({ error: '未登录' }, 401);

  // 验证管理员身份
  const admin: any = await env.duichai_db.prepare(
    "SELECT id FROM admin_users WHERE id = ?"
  ).bind(adminId).first();
  if (!admin) return jsonResponse({ error: '无权操作' }, 403);

  const body: any = await request.json();
  const { target_user_id, uid } = body;

  if (!target_user_id || !uid) {
    return jsonResponse({ error: 'target_user_id, uid 为必填' }, 400);
  }

  // 检查UID是否已被占用
  const existing = await env.duichai_db.prepare(
    'SELECT id FROM users WHERE uid = ? AND id != ?'
  ).bind(uid, target_user_id).first();
  if (existing) {
    return jsonResponse({ error: 'UID已被占用' }, 409);
  }

  await env.duichai_db.prepare(
    "UPDATE users SET uid = ?, updated_at = datetime('now') WHERE id = ?"
  ).bind(uid, target_user_id).run();

  return jsonResponse({ success: true, message: `UID设置为 ${uid}` });
}
