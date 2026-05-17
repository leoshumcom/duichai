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
