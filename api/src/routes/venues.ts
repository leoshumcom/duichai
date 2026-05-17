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

    // 去重检测：同POI ID或50米范围内同名字段
    const duplicate = await env.duichai_db.prepare(`
      SELECT id, name FROM venues 
      WHERE status = 'approved' 
      AND ABS(latitude - ?) < 0.0005 
      AND ABS(longitude - ?) < 0.0005 
      AND name LIKE ?
    `).bind(latitude, longitude, `%${name}%`).first();

    if (duplicate) {
      return jsonResponse({
        error: '该场地已被发布过',
        duplicate_venue: duplicate,
      }, 409);
    }

    const id = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO venues (id, name, type, latitude, longitude, description, address, photos, videos, publisher_id, is_free, price_info, open_hours, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
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
    SELECT u.id, u.nickname, u.avatar, SUM(ct.amount) as total_chaihuo
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
  const sort = url.searchParams.get('sort') || 'chaihuo'; // chaihuo | newest | distance
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

    return jsonResponse({ success: true, message: '添柴成功' });
  } catch (e) {
    return jsonResponse({ error: '服务器错误' }, 500);
  }
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

// 补充场地信息
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
