import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

// 创建俱乐部
export async function handleCreateClub(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { name, description, slogan, sport_types, contact, creator_id } = body;

    if (!name || !creator_id) {
      return jsonResponse({ error: 'name, creator_id 为必填' }, 400);
    }
    if (!sport_types || sport_types.length === 0) {
      return jsonResponse({ error: '请选择至少一个运动项目' }, 400);
    }

    const id = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO clubs (id, name, description, slogan, sport_types, contact_wechat, creator_id, member_count, chaihuo_total)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, 50)
    `).bind(id, name, description || null, slogan || null, JSON.stringify(sport_types), contact || null, creator_id).run();

    // 创建者自动成为成员
    await env.duichai_db.prepare(`
      INSERT INTO club_members (id, club_id, user_id, role)
      VALUES (?, ?, ?, 'creator')
    `).bind(generateId(), id, creator_id).run();

    return jsonResponse({ success: true, club_id: id }, 201);
  } catch (e) {
    return jsonResponse({ error: '创建失败' }, 500);
  }
}

// 获取俱乐部列表
export async function handleListClubs(request: Request, env: Env): Promise<Response> {
  try {
    const clubs = await env.duichai_db.prepare(`
      SELECT c.*, u.nickname as creator_name
      FROM clubs c
      LEFT JOIN users u ON c.creator_id = u.id
      WHERE c.status = 'active'
      ORDER BY c.chaihuo_total DESC
      LIMIT 50
    `).all();

    const parsed = clubs.results.map((c: any) => ({
      ...c,
      sport_types: JSON.parse(c.sport_types || '[]'),
    }));

    return jsonResponse({ success: true, data: parsed });
  } catch (e) {
    return jsonResponse({ error: '查询失败' }, 500);
  }
}

// 获取俱乐部详情
export async function handleGetClub(request: Request, env: Env, clubId: string): Promise<Response> {
  const club: any = await env.duichai_db.prepare(`
    SELECT c.*, u.nickname as creator_name, u.avatar as creator_avatar
    FROM clubs c
    LEFT JOIN users u ON c.creator_id = u.id
    WHERE c.id = ?
  `).bind(clubId).first();

  if (!club) return jsonResponse({ error: '俱乐部不存在' }, 404);

  club.sport_types = JSON.parse(club.sport_types || '[]');

  const members = await env.duichai_db.prepare(`
    SELECT u.id, u.nickname, u.avatar, cm.role
    FROM club_members cm
    JOIN users u ON cm.user_id = u.id
    WHERE cm.club_id = ?
    ORDER BY cm.role
  `).bind(clubId).all();

  return jsonResponse({ success: true, data: { ...club, members: members.results } });
}

// 加入俱乐部
export async function handleJoinClub(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { club_id, user_id } = body;

    if (!club_id || !user_id) {
      return jsonResponse({ error: 'club_id, user_id 为必填' }, 400);
    }

    const existing = await env.duichai_db.prepare(
      'SELECT id FROM club_members WHERE club_id = ? AND user_id = ?'
    ).bind(club_id, user_id).first();

    if (existing) {
      return jsonResponse({ error: '已经是俱乐部成员' }, 409);
    }

    await env.duichai_db.prepare(`
      INSERT INTO club_members (id, club_id, user_id, role)
      VALUES (?, ?, ?, 'member')
    `).bind(generateId(), club_id, user_id).run();

    await env.duichai_db.prepare(
      'UPDATE clubs SET member_count = member_count + 1 WHERE id = ?'
    ).bind(club_id).run();

    return jsonResponse({ success: true, message: '加入成功' });
  } catch (e) {
    return jsonResponse({ error: '加入失败' }, 500);
  }
}
