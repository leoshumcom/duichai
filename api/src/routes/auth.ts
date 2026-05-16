/**
 * 用户认证路由
 */

import { jsonResponse, generateId, generateInviteCode, hashPassword, verifyPassword } from '../utils';

interface Env {
  duichai_db: D1Database;
}

export async function handleRegister(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { email, password, nickname, phone } = body;

    if (!email || !password || !nickname) {
      return jsonResponse({ error: 'email, password, nickname 为必填' }, 400);
    }
    if (password.length < 6) {
      return jsonResponse({ error: '密码至少6位' }, 400);
    }

    // 检查邮箱是否已注册
    const existing = await env.duichai_db.prepare(
      'SELECT id FROM users WHERE email = ?'
    ).bind(email).first();

    if (existing) {
      return jsonResponse({ error: '该邮箱已注册' }, 409);
    }

    const id = generateId();
    const passwordHash = await hashPassword(password);
    const inviteCode = generateInviteCode();

    await env.duichai_db.prepare(`
      INSERT INTO users (id, email, nickname, phone, password_hash, invite_code, chaihuo_balance)
      VALUES (?, ?, ?, ?, ?, ?, 1)
    `).bind(id, email, nickname, phone || null, passwordHash, inviteCode).run();

    // 记录登录奖励
    await env.duichai_db.prepare(`
      INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, description)
      VALUES (?, ?, 'login_bonus', 1, 1, '注册赠送1根柴火')
    `).bind(generateId(), id).run();

    return jsonResponse({
      success: true,
      message: '注册成功',
      data: { user_id: id, nickname, invite_code: inviteCode },
    }, 201);
  } catch (e) {
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

    const user: any = await env.duichai_db.prepare(
      'SELECT id, email, nickname, phone, avatar, password_hash, role, level, chaihuo_balance, invite_code FROM users WHERE email = ?'
    ).bind(email).first();

    if (!user) {
      return jsonResponse({ error: '邮箱或密码错误' }, 401);
    }

    const valid = await verifyPassword(password, user.password_hash);
    if (!valid) {
      return jsonResponse({ error: '邮箱或密码错误' }, 401);
    }

    // TODO: 生产环境使用 JWT
    const token = generateId() + '-' + generateId();

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
        token,
      },
    });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

export async function handleGetUser(request: Request, env: Env, userId: string): Promise<Response> {
  const user: any = await env.duichai_db.prepare(
    'SELECT id, email, nickname, phone, avatar, role, level, chaihuo_balance, total_chaihuo_earned, invite_code, created_at FROM users WHERE id = ?'
  ).bind(userId).first();

  if (!user) {
    return jsonResponse({ error: '用户不存在' }, 404);
  }

  return jsonResponse({ success: true, data: user });
}
