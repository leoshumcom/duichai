/**
 * 场地路由
 */

import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

// 发布场地
export async function handleCreateVenue(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { name, type, latitude, longitude, description, address, photos, videos, is_free, price_info, open_hours, publisher_id } = body;

    if (!name || !type || !latitude || !longitude || !publisher_id) {
      return jsonResponse({ error: 'name, type, latitude, longitude, publisher_id 为必填' }, 400);
    }

    // 去重检测：同POI ID或50米范围内同名字段（精确匹配）
    const duplicate = await env.duichai_db.prepare(`
      SELECT id, name FROM venues 
      WHERE status = 'approved' 
      AND ABS(latitude - ?) < 0.0005 
      AND ABS(longitude - ?) < 0.0005 
      AND name = ?
    `).bind(latitude, longitude, name).first();

    if (duplicate) {
      return jsonResponse({
        error: '该场地已被发布过',
        duplicate_venue: duplicate,
      }, 409);
    }

    const id = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO venues (id, name, type, latitude, longitude, description, address, photos, videos, publisher_id, is_free, price_info, open_hours, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'approved')
    `).bind(
      id, name, type, latitude, longitude,
      description || null, address || null,
      JSON.stringify(photos || []), JSON.stringify(videos || []),
      publisher_id, is_free ?? 1, price_info || null, open_hours || null
    ).run();

    // 奖励发布者100根柴火
    const rewardAmount = 100;
    const user: any = await env.duichai_db.prepare('SELECT chaihuo_balance FROM users WHERE id = ?').bind(publisher_id).first();
    const newBalance = (user?.chaihuo_balance || 0) + rewardAmount;

    await env.duichai_db.prepare('UPDATE users SET chaihuo_balance = ?, total_chaihuo_earned = total_chaihuo_earned + ? WHERE id = ?')
      .bind(newBalance, rewardAmount, publisher_id).run();

    await env.duichai_db.prepare(`
      INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, reference_id, reference_type, description)
      VALUES (?, ?, 'publish_venue', ?, ?, ?, 'venue', '发布场地奖励')
    `).bind(generateId(), publisher_id, rewardAmount, newBalance, id).run();

    return jsonResponse({ success: true, venue_id: id }, 201);
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 获取场地详情
export async function handleGetVenue(request: Request, env: Env, venueId: string): Promise<Response> {
  const venue: any = await env.duichai_db.prepare(`
    SELECT v.*, u.nickname as publisher_name, u.avatar as publisher_avatar
    FROM venues v
    LEFT JOIN users u ON v.publisher_id = u.id
    WHERE v.id = ?
  `).bind(venueId).first();

  if (!venue) {
    return jsonResponse({ error: '场地不存在' }, 404);
  }

  venue.photos = JSON.parse(venue.photos || '[]');
  venue.videos = JSON.parse(venue.videos || '[]');

  // 获取添柴TOP3
  const topTippers: any[] = await env.duichai_db.prepare(`
    SELECT u.id, u.nickname, u.avatar, SUM(ct.amount) * -1 as total_chaihuo
    FROM chaihuo_transactions ct
    JOIN users u ON ct.user_id = u.id
    WHERE ct.reference_id = ? AND ct.reference_type = 'venue' AND ct.type = 'tip_given'
    GROUP BY ct.user_id
    ORDER BY total_chaihuo DESC
    LIMIT 3
  `).bind(venueId).all();

  return jsonResponse({
    success: true,
    data: { ...venue, top_tippers: topTippers.results },
  });
}

// 搜索场地（附近）
export async function handleSearchVenues(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const lat = parseFloat(url.searchParams.get('lat') || '0');
  const lng = parseFloat(url.searchParams.get('lng') || '0');
  const radius = parseFloat(url.searchParams.get('radius') || '5'); // 公里
  const type = url.searchParams.get('type');
  const city = url.searchParams.get('city');
  const sort = url.searchParams.get('sort') || 'chaihuo';
  const q = url.searchParams.get('q'); // chaihuo | newest | distance
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const offset = (page - 1) * limit;

  // 粗略经纬度范围（1度≈111km）
  const latDelta = radius / 111;
  const lngDelta = radius / (111 * Math.cos(lat * Math.PI / 180));

  let query = 'SELECT * FROM venues WHERE status = \'approved\'';
  const params: any[] = [];

  if (lat && lng) {
    query += ' AND latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?';
    params.push(lat - latDelta, lat + latDelta, lng - lngDelta, lng + lngDelta);
  }
  if (type && type !== 'all') {
    query += ' AND type LIKE ?';
    params.push(`%${type}%`);
  }
  // 城市模糊搜索——通过场地名称+地址字段匹配
  // 兼容「常州」和「常州市」两种写法
  if (city && city !== '全国' && city !== '') {
    const cityWithShi = city.endsWith('市') ? city : city + '市';
    query += ' AND (name LIKE ? OR name LIKE ? OR address LIKE ? OR address LIKE ?)';
    params.push(`%${city}%`, `%${cityWithShi}%`, `%${city}%`, `%${cityWithShi}%`);
  }

  // 关键词搜索
  if (q && q.trim()) {
    query += ' AND (name LIKE ? OR address LIKE ? OR description LIKE ? OR type LIKE ?)';
    const likeQ = `%${q.trim()}%`;
    params.push(likeQ, likeQ, likeQ, likeQ);
  }

  switch (sort) {
    case 'newest': query += ' ORDER BY created_at DESC'; break;
    case 'distance': query += ' ORDER BY ABS(latitude - ?) + ABS(longitude - ?)'; params.push(lat, lng); break;
    default: query += ' ORDER BY chaihuo_total DESC';
  }

  query += ' LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const venues = await env.duichai_db.prepare(query).bind(...params).all();
  const parsed = venues.results.map((v: any) => ({
    ...v,
    photos: JSON.parse(v.photos || '[]'),
    videos: JSON.parse(v.videos || '[]'),
  }));

  return jsonResponse({ success: true, data: parsed, page, limit });
}

// 添柴
export async function handleTipVenue(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { venue_id, user_id, amount, content, photos } = body;

    if (!venue_id || !user_id || !amount || amount < 1) {
      return jsonResponse({ error: 'venue_id, user_id, amount 为必填，amount >= 1' }, 400);
    }

    // 检查用户柴火余额
    const user: any = await env.duichai_db.prepare('SELECT chaihuo_balance FROM users WHERE id = ?').bind(user_id).first();
    if (!user || user.chaihuo_balance < amount) {
      return jsonResponse({ error: '柴火余额不足' }, 400);
    }

    // 扣柴火
    await env.duichai_db.prepare('UPDATE users SET chaihuo_balance = ?, total_chaihuo_spent = total_chaihuo_spent + ? WHERE id = ?')
      .bind(user.chaihuo_balance - amount, amount, user_id).run();

    // 场地加柴火
    await env.duichai_db.prepare('UPDATE venues SET chaihuo_total = chaihuo_total + ? WHERE id = ?')
      .bind(amount, venue_id).run();

    // 记录流水
    await env.duichai_db.prepare(`
      INSERT INTO chaihuo_transactions (id, user_id, type, amount, balance_after, reference_id, reference_type, description)
      VALUES (?, ?, 'tip_given', ?, ?, ?, 'venue', '给场地添柴')
    `).bind(generateId(), user_id, -amount, user.chaihuo_balance - amount, venue_id).run();

    // 如果带评价内容
    if (content || (photos && photos.length > 0)) {
      await env.duichai_db.prepare(`
        INSERT INTO reviews (id, venue_id, user_id, chaihuo_amount, content, photos)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(generateId(), venue_id, user_id, amount, content || null, JSON.stringify(photos || [])).run();
    }

    // 添柴后自动检查并发放勋章
    await _autoAwardBadges(env, user_id, venue_id);

    return jsonResponse({ success: true, message: '添柴成功' });
  } catch (_) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 自动发放勋章
async function _autoAwardBadges(env: Env, userId: string, venueId: string): Promise<void> {
  try {
    // 检查「榜一大哥」：当前场地添柴TOP3
    const existingTop = await env.duichai_db.prepare(
      "SELECT id FROM user_badges WHERE user_id = ? AND badge_id = 'top_tipper'"
    ).bind(userId).first();
    if (!existingTop) {
      const tipRank: any = await env.duichai_db.prepare(`
        SELECT user_id, SUM(ABS(amount)) as total FROM chaihuo_transactions
        WHERE reference_id = ? AND reference_type = 'venue' AND type = 'tip_given'
        GROUP BY user_id ORDER BY total DESC LIMIT 1
      `).bind(venueId).first();
      if (tipRank && tipRank.user_id === userId) {
        await env.duichai_db.prepare(
          "INSERT OR IGNORE INTO user_badges (id, user_id, badge_id) VALUES (?, ?, 'top_tipper')"
        ).bind(generateId(), userId).run();
      }
    }
  } catch (_) {}
}

// 获取场地评价列表
async function getUserIdFromToken(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

export async function handleGetVenueReviews(request: Request, env: Env, venueId: string): Promise<Response> {
  const url = new URL(request.url);
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const offset = (page - 1) * limit;

  const reviews: any[] = await env.duichai_db.prepare(`
    SELECT r.*, u.nickname, u.avatar, u.uid
    FROM reviews r
    LEFT JOIN users u ON r.user_id = u.id
    WHERE r.venue_id = ?
    ORDER BY r.created_at DESC
    LIMIT ? OFFSET ?
  `).bind(venueId, limit, offset).all();

  const totalResult: any = await env.duichai_db.prepare(
    'SELECT COUNT(*) as total FROM reviews WHERE venue_id = ?'
  ).bind(venueId).first();

  // 解析@提及
  const parsed = reviews.results.map((r: any) => {
    let photoList: string[] = [];
    try { photoList = JSON.parse(r.photos || '[]'); } catch (_) {}
    return {
      ...r,
      photos: photoList,
    };
  });

  return jsonResponse({
    success: true,
    data: parsed,
    total: totalResult?.total || 0,
    page,
    limit,
  });
}

// 补充场地信息（任何人可补充）
export async function handleSupplementVenue(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { venue_id, user_id, content, photos } = body;

    if (!venue_id || !user_id || !content) {
      return jsonResponse({ error: 'venue_id, user_id, content 为必填' }, 400);
    }

    await env.duichai_db.prepare(`
      INSERT INTO venue_supplements (id, venue_id, user_id, content, photos, reward_chaihuo)
      VALUES (?, ?, ?, ?, ?, 5)
    `).bind(generateId(), venue_id, user_id, content, JSON.stringify(photos || [])).run();

    return jsonResponse({ success: true, message: '补充提交成功，审核通过后将获得5根柴火' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 更新场地信息（仅发布者或馆主可编辑）
export async function handleUpdateVenue(request: Request, env: Env, venueId: string): Promise<Response> {
  try {
    // 从Authorization头获取用户ID
    const auth = request.headers.get('Authorization');
    if (!auth || !auth.startsWith('Bearer ')) return jsonResponse({ error: '未登录' }, 401);
    const token = auth.slice(7);
    const session: any = await env.duichai_db.prepare(
      'SELECT user_id FROM sessions WHERE token = ?'
    ).bind(token).first();
    if (!session) return jsonResponse({ error: '未登录' }, 401);
    const userId = session.user_id;

    // 获取场地
    const venue: any = await env.duichai_db.prepare(
      'SELECT * FROM venues WHERE id = ?'
    ).bind(venueId).first();
    if (!venue) return jsonResponse({ error: '场地不存在' }, 404);

    // 检查权限：发布者或馆主
    if (venue.publisher_id !== userId && venue.owner_id !== userId) {
      return jsonResponse({ error: '仅场地发布者或馆主可编辑' }, 403);
    }

    const body: any = await request.json();
    const { name, description, photos, videos, is_free, price_info, open_hours, address } = body;

    const updates: string[] = [];
    const params: any[] = [];

    if (name !== undefined) { updates.push('name = ?'); params.push(name); }
    if (description !== undefined) { updates.push('description = ?'); params.push(description); }
    if (photos !== undefined) { updates.push('photos = ?'); params.push(JSON.stringify(photos)); }
    if (videos !== undefined) { updates.push('videos = ?'); params.push(JSON.stringify(videos)); }
    if (is_free !== undefined) { updates.push('is_free = ?'); params.push(is_free ? 1 : 0); }
    if (price_info !== undefined) { updates.push('price_info = ?'); params.push(price_info); }
    if (open_hours !== undefined) { updates.push('open_hours = ?'); params.push(open_hours); }
    if (address !== undefined) { updates.push('address = ?'); params.push(address); }

    if (updates.length === 0) {
      return jsonResponse({ error: '没有需要更新的字段' }, 400);
    }

    updates.push("updated_at = datetime('now')");
    params.push(venueId);

    await env.duichai_db.prepare(
      `UPDATE venues SET ${updates.join(', ')} WHERE id = ?`
    ).bind(...params).run();

    return jsonResponse({ success: true, message: '场地信息已更新' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 约球匹配——创建约球
async function getMatchUserId(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

export async function handleCreateMatch(request: Request, env: Env, venueId: string): Promise<Response> {
  try {
    const userId = await getMatchUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    const body: any = await request.json();
    const { match_time, max_players, notes } = body;

    if (!match_time || !max_players) {
      return jsonResponse({ error: 'match_time, max_players 为必填' }, 400);
    }

    // current_players 不在数据库表中（由 joiners 计数），先加 column 保证兼容
    await env.duichai_db.prepare("ALTER TABLE match_sessions ADD COLUMN current_players INTEGER NOT NULL DEFAULT 1")
      .run().catch(() => {});

    const id = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO match_sessions (id, venue_id, creator_id, match_time, max_players, current_players, notes)
      VALUES (?, ?, ?, ?, ?, 1, ?)
    `).bind(id, venueId, userId, match_time, max_players, notes || null).run();

    // 创建者自动加入
    await env.duichai_db.prepare(`
      INSERT INTO match_joiners (id, match_id, user_id)
      VALUES (?, ?, ?)
    `).bind(generateId(), id, userId).run();

    return jsonResponse({ success: true, match_id: id, message: '约球创建成功' }, 201);
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 获取场地约球列表
export async function handleGetVenueMatches(request: Request, env: Env, venueId: string): Promise<Response> {
  try {
    const url = new URL(request.url);
    const status = url.searchParams.get('status') || 'open'; // open | full | closed

    let query = `
      SELECT ms.*, u.nickname as creator_name, u.avatar as creator_avatar
      FROM match_sessions ms
      LEFT JOIN users u ON ms.creator_id = u.id
      WHERE ms.venue_id = ?
    `;
    const params: any[] = [venueId];

    if (status === 'open') {
      query += ' AND ms.status = \'open\'';
    }

    query += ' ORDER BY ms.match_time ASC LIMIT 20';

    const sessions: any[] = await env.duichai_db.prepare(query).bind(...params).all();

    // 获取每个约球的参与者数量
    const parsed = await Promise.all(sessions.results.map(async (s: any) => {
      const joinerCount: any = await env.duichai_db.prepare(
        'SELECT COUNT(*) as count FROM match_joiners WHERE match_id = ?'
      ).bind(s.id).first();
      return {
        ...s,
        current_players: joinerCount?.count || 0,
      };
    }));

    return jsonResponse({ success: true, data: parsed });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 馆主认证申请
async function getOwnerApplyUserId(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

export async function handleOwnerApply(request: Request, env: Env): Promise<Response> {
  try {
    const userId = await getOwnerApplyUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    const body: any = await request.json();
    const { business_license, id_card_front, id_card_back, contact_phone, contact_wechat } = body;

    if (!business_license || !id_card_front || !id_card_back || !contact_phone) {
      return jsonResponse({ error: 'business_license, id_card_front, id_card_back, contact_phone 为必填' }, 400);
    }

    // 检查是否有待审核的申请
    const existing = await env.duichai_db.prepare(
      "SELECT id FROM venue_owner_applications WHERE user_id = ? AND status = 'pending'"
    ).bind(userId).first();
    if (existing) {
      return jsonResponse({ error: '已有待审核的申请，请耐心等待' }, 409);
    }

    const id = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO venue_owner_applications (id, user_id, business_license, id_card_front, id_card_back, contact_phone, contact_wechat, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'pending')
    `).bind(id, userId, business_license, id_card_front, id_card_back, contact_phone, contact_wechat || null).run();

    return jsonResponse({ success: true, message: '馆主认证申请已提交，等待审核' }, 201);
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}

// 加入约球
export async function handleJoinMatch(request: Request, env: Env, matchId: string): Promise<Response> {
  try {
    const userId = await getMatchUserId(request, env);
    if (!userId) return jsonResponse({ error: '未登录' }, 401);

    // 检查约球是否存在且开放
    const match: any = await env.duichai_db.prepare(
      'SELECT * FROM match_sessions WHERE id = ?'
    ).bind(matchId).first();

    if (!match) return jsonResponse({ error: '约球不存在' }, 404);
    if (match.status !== 'open') return jsonResponse({ error: '该约球已结束' }, 400);

    // 检查是否已加入
    const existing = await env.duichai_db.prepare(
      'SELECT id FROM match_joiners WHERE match_id = ? AND user_id = ?'
    ).bind(matchId, userId).first();

    if (existing) return jsonResponse({ error: '已加入该约球' }, 409);

    // 检查人数上限
    const countResult: any = await env.duichai_db.prepare(
      'SELECT COUNT(*) as count FROM match_joiners WHERE match_id = ?'
    ).bind(matchId).first();

    if (countResult.count >= match.max_players) {
      return jsonResponse({ error: '约球人数已满' }, 400);
    }

    await env.duichai_db.prepare(`
      INSERT INTO match_joiners (id, match_id, user_id)
      VALUES (?, ?, ?)
    `).bind(generateId(), matchId, userId).run();

    // 如果满了，更新状态
    if (countResult.count + 1 >= match.max_players) {
      await env.duichai_db.prepare(
        "UPDATE match_sessions SET status = 'full' WHERE id = ?"
      ).bind(matchId).run();
    }

    return jsonResponse({ success: true, message: '已加入约球' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
}
