/**
 * 俱乐部聊天消息路由
 */

import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
}

async function getUserIdFromToken(request: Request, env: Env): Promise<string | null> {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;
  const token = auth.slice(7);
  const session: any = await env.duichai_db.prepare(
    'SELECT user_id FROM sessions WHERE token = ?'
  ).bind(token).first();
  return session?.user_id || null;
}

// 解析@username提及，返回被提及的用户ID列表
async function parseMentions(content: string, env: Env): Promise<string[]> {
  const mentionRegex = /@(\S+)/g;
  const matches = content.matchAll(mentionRegex);
  const usernames: string[] = [];
  for (const match of matches) {
    usernames.push(match[1]);
  }
  if (usernames.length === 0) return [];

  // 查找匹配的用户（通过nickname或uid）
  const mentionedIds: string[] = [];
  for (const name of usernames) {
    // 先尝试按UID查找
    const uidNum = parseInt(name);
    if (!isNaN(uidNum)) {
      const user: any = await env.duichai_db.prepare(
        'SELECT id, nickname FROM users WHERE uid = ?'
      ).bind(uidNum).first();
      if (user) {
        mentionedIds.push(user.id);
        continue;
      }
    }
    // 按昵称查找
    const user: any = await env.duichai_db.prepare(
      'SELECT id, nickname FROM users WHERE nickname = ?'
    ).bind(name).first();
    if (user) {
      mentionedIds.push(user.id);
    }
  }
  return mentionedIds;
}

// 发送消息
export async function handleSendClubMessage(request: Request, env: Env, clubId: string): Promise<Response> {
  const userId = await getUserIdFromToken(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  // 验证俱乐部成员身份
  const member: any = await env.duichai_db.prepare(
    'SELECT id, role FROM club_members WHERE club_id = ? AND user_id = ?'
  ).bind(clubId, userId).first();
  if (!member) return jsonResponse({ error: '你不是该俱乐部成员' }, 403);

  const body: any = await request.json();
  const { content, parent_id } = body;

  if (!content || content.trim().length === 0) {
    return jsonResponse({ error: '消息内容不能为空' }, 400);
  }

  const messageId = generateId();
  await env.duichai_db.prepare(`
    INSERT INTO club_messages (id, club_id, user_id, content, parent_id)
    VALUES (?, ?, ?, ?, ?)
  `).bind(messageId, clubId, userId, content.trim(), parent_id || null).run();

  // 解析@提及
  const mentionedIds = await parseMentions(content, env);
  for (const mentionedUserId of mentionedIds) {
    if (mentionedUserId === userId) continue; // 不提醒自己
    const mentionId = generateId();
    await env.duichai_db.prepare(`
      INSERT INTO club_message_mentions (id, message_id, mentioned_user_id)
      VALUES (?, ?, ?)
    `).bind(mentionId, messageId, mentionedUserId).run();

    // 创建通知
    const user: any = await env.duichai_db.prepare(
      'SELECT nickname FROM users WHERE id = ?'
    ).bind(userId).first();
    await env.duichai_db.prepare(`
      INSERT INTO notifications (id, user_id, type, title, body, reference_id)
      VALUES (?, ?, 'club_mention', '有用户在一场聊天中提到了你', ?, ?)
    `).bind(generateId(), mentionedUserId, `@${user?.nickname || '用户'} 在俱乐部聊天中提到了你`, messageId).run();
  }

  return jsonResponse({ success: true, message_id: messageId }, 201);
}

// 获取消息列表
export async function handleGetClubMessages(request: Request, env: Env, clubId: string): Promise<Response> {
  const userId = await getUserIdFromToken(request, env);
  if (!userId) return jsonResponse({ error: '未登录' }, 401);

  const url = new URL(request.url);
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const offset = (page - 1) * limit;

  const messages: any[] = await env.duichai_db.prepare(`
    SELECT cm.*, u.nickname, u.avatar, u.uid
    FROM club_messages cm
    LEFT JOIN users u ON cm.user_id = u.id
    WHERE cm.club_id = ?
    ORDER BY cm.created_at DESC
    LIMIT ? OFFSET ?
  `).bind(clubId, limit, offset).all();

  const totalResult: any = await env.duichai_db.prepare(
    'SELECT COUNT(*) as total FROM club_messages WHERE club_id = ?'
  ).bind(clubId).first();

  return jsonResponse({
    success: true,
    data: messages.results.reverse(), // 翻转成正序显示
    total: totalResult?.total || 0,
    page,
    limit,
  });
}
