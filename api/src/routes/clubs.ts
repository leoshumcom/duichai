import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

// Create club
export async function handleCreateClub(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { name, description, slogan, sport_types, contact, creator_id } = body;

    if (!name || !creator_id) {
      return jsonResponse({ error: 'name, creator_id are required' }, 400);
    }
    if (!sport_types || sport_types.length === 0) {
      return jsonResponse({ error: 'Select at least one sport' }, 400);
    }

    const id = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO clubs (id, name, description, slogan, sport_types, contact_wechat, creator_id, member_count, chaihuo_total)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, 50)
    `).bind(id, name, description || null, slogan || null, JSON.stringify(sport_types), contact || null, creator_id).run();

    // Creator auto-joins as member
    await env.duichai_db.prepare(`
      INSERT INTO club_members (id, club_id, user_id, role)
      VALUES (?, ?, ?, 'creator')
    `).bind(generateId(), id, creator_id).run();

    return jsonResponse({ success: true, club_id: id }, 201);
  } catch (e) {
    return jsonResponse({ error: 'Create failed' }, 500);
  }
}

// Club list
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
    return jsonResponse({ error: 'Query failed' }, 500);
  }
}

// Club detail
export async function handleGetClub(request: Request, env: Env, clubId: string): Promise<Response> {
  const club: any = await env.duichai_db.prepare(`
    SELECT c.*, u.nickname as creator_name, u.avatar as creator_avatar
    FROM clubs c
    LEFT JOIN users u ON c.creator_id = u.id
    WHERE c.id = ?
  `).bind(clubId).first();

  if (!club) return jsonResponse({ error: 'Club not found' }, 404);

  club.sport_types = JSON.parse(club.sport_types || '[]');

  // Get member count
  const countResult: any = await env.duichai_db.prepare(
    'SELECT COUNT(*) as total FROM club_members WHERE club_id = ?'
  ).bind(clubId).first();
  const totalMembers = countResult?.total || 0;

  // Paginated members
  const url = new URL(request.url);
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const offset = (page - 1) * limit;

  const members = await env.duichai_db.prepare(`
    SELECT u.id, u.nickname, u.avatar, cm.role
    FROM club_members cm
    JOIN users u ON cm.user_id = u.id
    WHERE cm.club_id = ?
    ORDER BY cm.role, cm.joined_at ASC
    LIMIT ? OFFSET ?
  `).bind(clubId, limit, offset).all();

  return jsonResponse({
    success: true,
    data: {
      ...club,
      members: members.results,
      member_count: totalMembers,
      member_page: page,
      member_limit: limit,
    },
  });
}

// Join club
export async function handleJoinClub(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { club_id, user_id } = body;

    if (!club_id || !user_id) {
      return jsonResponse({ error: 'club_id, user_id required' }, 400);
    }

    const existing = await env.duichai_db.prepare(
      'SELECT id FROM club_members WHERE club_id = ? AND user_id = ?'
    ).bind(club_id, user_id).first();

    if (existing) {
      return jsonResponse({ error: 'Already a member' }, 409);
    }

    await env.duichai_db.prepare(`
      INSERT INTO club_members (id, club_id, user_id, role)
      VALUES (?, ?, ?, 'member')
    `).bind(generateId(), club_id, user_id).run();

    await env.duichai_db.prepare(
      'UPDATE clubs SET member_count = member_count + 1 WHERE id = ?'
    ).bind(club_id).run();

    return jsonResponse({ success: true, message: 'Joined' });
  } catch (e) {
    return jsonResponse({ error: 'Join failed' }, 500);
  }
}

// ===== Club Join Requests =====

// 获取用户ID
async function getUserId(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

// 申请加入俱乐部
export async function handleJoinRequest(request: Request, env: Env, clubId: string): Promise<Response> {
  try {
    const userId = await getUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    // 检查俱乐部是否存在
    const club: any = await env.duichai_db.prepare('SELECT id, status FROM clubs WHERE id = ?').bind(clubId).first();
    if (!club) return jsonResponse({ error: '俱乐部不存在' }, 404);
    if (club.status !== 'active') return jsonResponse({ error: '俱乐部已解散或冻结' }, 400);

    // 检查是否已经是成员
    const existingMember = await env.duichai_db.prepare(
      'SELECT id FROM club_members WHERE club_id = ? AND user_id = ?'
    ).bind(clubId, userId).first();
    if (existingMember) return jsonResponse({ error: '您已是俱乐部成员' }, 409);

    // 检查是否已有待审核的申请
    const pendingRequest = await env.duichai_db.prepare(
      "SELECT id FROM club_join_requests WHERE club_id = ? AND user_id = ? AND status = 'pending'"
    ).bind(clubId, userId).first();
    if (pendingRequest) return jsonResponse({ error: '已有待审核的申请' }, 409);

    await env.duichai_db.prepare(`
      INSERT INTO club_join_requests (id, club_id, user_id, status)
      VALUES (?, ?, ?, 'pending')
    `).bind(generateId(), clubId, userId).run();

    return jsonResponse({ success: true, message: '申请已提交，等待俱乐部管理员审核' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 获取俱乐部加入申请列表（仅创建者/管理员）
export async function handleListJoinRequests(request: Request, env: Env, clubId: string): Promise<Response> {
  try {
    const userId = await getUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    // 验证是否为俱乐部创建者或管理员
    const member = await env.duichai_db.prepare(
      "SELECT role FROM club_members WHERE club_id = ? AND user_id = ? AND role IN ('creator', 'admin')"
    ).bind(clubId, userId).first();
    if (!member) return jsonResponse({ error: '无权查看' }, 403);

    const requests: any[] = await env.duichai_db.prepare(`
      SELECT r.*, u.nickname, u.avatar, u.email
      FROM club_join_requests r
      LEFT JOIN users u ON r.user_id = u.id
      WHERE r.club_id = ?
      ORDER BY r.created_at DESC
      LIMIT 50
    `).bind(clubId).all();

    return jsonResponse({ success: true, data: requests.results });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 批准加入申请
export async function handleApproveJoinRequest(request: Request, env: Env, clubId: string, requestId: string): Promise<Response> {
  try {
    const userId = await getUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    // 验证是否为俱乐部创建者或管理员
    const member = await env.duichai_db.prepare(
      "SELECT role FROM club_members WHERE club_id = ? AND user_id = ? AND role IN ('creator', 'admin')"
    ).bind(clubId, userId).first();
    if (!member) return jsonResponse({ error: '无权操作' }, 403);

    const joinRequest: any = await env.duichai_db.prepare(
      "SELECT * FROM club_join_requests WHERE id = ? AND club_id = ? AND status = 'pending'"
    ).bind(requestId, clubId).first();

    if (!joinRequest) return jsonResponse({ error: '申请不存在或已处理' }, 404);

    // 更新申请状态
    await env.duichai_db.prepare(
      "UPDATE club_join_requests SET status = 'approved' WHERE id = ?"
    ).bind(requestId).run();

    // 添加成员
    await env.duichai_db.prepare(`
      INSERT INTO club_members (id, club_id, user_id, role)
      VALUES (?, ?, ?, 'member')
    `).bind(generateId(), clubId, joinRequest.user_id).run();

    await env.duichai_db.prepare(
      'UPDATE clubs SET member_count = member_count + 1 WHERE id = ?'
    ).bind(clubId).run();

    return jsonResponse({ success: true, message: '已批准加入' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 拒绝加入申请
export async function handleRejectJoinRequest(request: Request, env: Env, clubId: string, requestId: string): Promise<Response> {
  try {
    const userId = await getUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    const member = await env.duichai_db.prepare(
      "SELECT role FROM club_members WHERE club_id = ? AND user_id = ? AND role IN ('creator', 'admin')"
    ).bind(clubId, userId).first();
    if (!member) return jsonResponse({ error: '无权操作' }, 403);

    await env.duichai_db.prepare(
      "UPDATE club_join_requests SET status = 'rejected' WHERE id = ? AND club_id = ?"
    ).bind(requestId, clubId).run();

    return jsonResponse({ success: true, message: '已拒绝申请' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}
