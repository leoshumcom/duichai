/**
 * 人脸认证 API - 使用腾讯云 IAI DetectFace
 * 直接 HTTP 调用（TC3-HMAC-SHA256 签名），无需 SDK
 */

import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
  TENCENT_FACE_SECRET_ID?: string;
  TENCENT_FACE_SECRET_KEY?: string;
}

// ===== TC3-HMAC-SHA256 签名工具 =====

async function hmacSha256(key: ArrayBuffer | Uint8Array, message: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  return await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(message));
}

function bytesToHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes)).map(b => b.toString(16).padStart(2, '0')).join('');
}

function bytesToHexLower(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes)).map(b => b.toString(16).padStart(2, '0')).join('');
}

async function sha256Hex(content: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(content));
  return bytesToHex(hash);
}

/**
 * 生成 TC3-HMAC-SHA256 签名头
 */
async function signTC3(
  secretId: string,
  secretKey: string,
  service: string,
  method: string,
  canonicalUri: string,
  canonicalQueryString: string,
  headers: Record<string, string>,
  payload: string,
): Promise<{ authorization: string; timestamp: string }> {
  const algorithm = 'TC3-HMAC-SHA256';
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const date = new Date(parseInt(timestamp) * 1000);
  const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');

  // Step 1: Canonical Request
  const signedHeaders = Object.keys(headers).map(h => h.toLowerCase()).sort().join(';');
  const canonicalHeaders = Object.entries(headers)
    .map(([k, v]) => `${k.toLowerCase()}:${v.trim()}\n`)
    .sort()
    .join('');

  const hashedPayload = await sha256Hex(payload);
  const canonicalRequest = [
    method,
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    hashedPayload,
  ].join('\n');

  // Step 2: String to Sign
  const hashedCanonicalRequest = await sha256Hex(canonicalRequest);
  const stringToSign = [
    algorithm,
    timestamp,
    `${dateStr}/${service}/tc3_request`,
    hashedCanonicalRequest,
  ].join('\n');

  // Step 3: Sign
  const secretDate = await hmacSha256(
    new TextEncoder().encode(`TC3${secretKey}`),
    dateStr
  );
  const secretService = await hmacSha256(secretDate, service);
  const secretSigning = await hmacSha256(secretService, 'tc3_request');
  const signature = await hmacSha256(secretSigning, stringToSign);
  const signatureHex = bytesToHex(signature);

  const authorization = `${algorithm} Credential=${secretId}/${dateStr}/${service}/tc3_request, SignedHeaders=${signedHeaders}, Signature=${signatureHex}`;

  return { authorization, timestamp };
}

// ===== Face Detection =====

/**
 * 检测人脸：上传图片检测性别/年龄
 * POST /api/face/detect
 * Body: { image_url: string } 或 { image_base64: string }
 */
export async function handleDetectFace(request: Request, env: Env): Promise<Response> {
  try {
    const secretId = env.TENCENT_FACE_SECRET_ID;
    const secretKey = env.TENCENT_FACE_SECRET_KEY;

    if (!secretId || !secretKey) {
      return jsonResponse({ error: 'Face auth not configured' }, 500);
    }

    const body: any = await request.json();
    let imageBase64 = body.image_base64;

    // 如果传的是 URL，先下载再转 base64（简单实现，直接转fetch）
    if (!imageBase64 && body.image_url) {
      try {
        const imgResp = await fetch(body.image_url);
        const imgBuffer = await imgResp.arrayBuffer();
        const imgBytes = new Uint8Array(imgBuffer);
        // 转 base64
        let binary = '';
        imgBytes.forEach(byte => { binary += String.fromCharCode(byte); });
        imageBase64 = btoa(binary);
      } catch (e) {
        return jsonResponse({ error: 'Failed to download image' }, 400);
      }
    }

    if (!imageBase64) {
      return jsonResponse({ error: 'image_base64 or image_url required' }, 400);
    }

    const payload = JSON.stringify({
      MaxFaceNum: 1,
      MinFaceSize: 0,
      Image: imageBase64,
      NeedFaceAttributes: 1,  // 返回年龄/性别等属性
    });

    const headers: Record<string, string> = {
      'Content-Type': 'application/json; charset=utf-8',
      'Host': 'iai.tencentcloudapi.com',
      'X-TC-Action': 'DetectFace',
      'X-TC-Version': '2020-03-03',
      'X-TC-Region': 'ap-guangzhou',
    };

    const { authorization, timestamp } = await signTC3(
      secretId, secretKey,
      'iai',
      'POST',
      '/',
      '',
      headers,
      payload,
    );

    headers['Authorization'] = authorization;
    headers['X-TC-Timestamp'] = timestamp;

    const apiResp = await fetch('https://iai.tencentcloudapi.com', {
      method: 'POST',
      headers,
      body: payload,
    });

    const result: any = await apiResp.json();

    if (!apiResp.ok || result.Response?.Error) {
      return jsonResponse({
        error: 'Face detection failed',
        detail: result.Response?.Error?.Message || 'Unknown error',
      }, 400);
    }

    const faceInfo = result.Response?.FaceInfos?.[0];
    if (!faceInfo) {
      return jsonResponse({ error: '未检测到人脸' }, 400);
    }

    // FaceAttributesInfo 包含性别年龄等
    const attr = faceInfo.FaceAttributesInfo || {};
    const genderValue = attr.Gender;  // Tencent: 0=女, 1=男
    const gender = genderValue === 1 ? 'male' : 'female';
    const age = attr.Age || 0;

    return jsonResponse({
      success: true,
      data: {
        gender,
        gender_value: genderValue,
        age,
        face_rect: faceInfo.FaceRect || null,
      },
    });
  } catch (e) {
    return jsonResponse({ error: 'Face detection failed' }, 500);
  }
}

/**
 * 人脸认证注册
 * POST /api/face/auth
 * Body: { image_base64: string } 或 { image_url: string }
 */
export async function handleFaceAuth(request: Request, env: Env): Promise<Response> {
  try {
    const secretId = env.TENCENT_FACE_SECRET_ID;
    const secretKey = env.TENCENT_FACE_SECRET_KEY;

    if (!secretId || !secretKey) {
      return jsonResponse({ error: 'Face auth not configured' }, 500);
    }

    // 获取用户
    const auth = request.headers.get('Authorization');
    if (!auth || !auth.startsWith('Bearer ')) return jsonResponse({ error: '未登录' }, 401);
    const token = auth.slice(7);
    const session: any = await env.duichai_db.prepare(
      'SELECT user_id FROM sessions WHERE token = ?'
    ).bind(token).first();
    if (!session) return jsonResponse({ error: '未登录' }, 401);
    const userId = session.user_id;

    const body: any = await request.json();
    let imageBase64 = body.image_base64;

    if (!imageBase64 && body.image_url) {
      try {
        const imgResp = await fetch(body.image_url);
        const imgBuffer = await imgResp.arrayBuffer();
        const imgBytes = new Uint8Array(imgBuffer);
        let binary = '';
        imgBytes.forEach(byte => { binary += String.fromCharCode(byte); });
        imageBase64 = btoa(binary);
      } catch (e) {
        return jsonResponse({ error: 'Failed to download image' }, 400);
      }
    }

    if (!imageBase64) {
      return jsonResponse({ error: 'image_base64 or image_url required' }, 400);
    }

    const payload = JSON.stringify({
      MaxFaceNum: 1,
      MinFaceSize: 0,
      Image: imageBase64,
      NeedFaceAttributes: 1,
    });

    const headers: Record<string, string> = {
      'Content-Type': 'application/json; charset=utf-8',
      'Host': 'iai.tencentcloudapi.com',
      'X-TC-Action': 'DetectFace',
      'X-TC-Version': '2020-03-03',
      'X-TC-Region': 'ap-guangzhou',
    };

    const { authorization, timestamp } = await signTC3(
      secretId, secretKey,
      'iai',
      'POST',
      '/',
      '',
      headers,
      payload,
    );

    headers['Authorization'] = authorization;
    headers['X-TC-Timestamp'] = timestamp;

    const apiResp = await fetch('https://iai.tencentcloudapi.com', {
      method: 'POST',
      headers,
      body: payload,
    });

    const result: any = await apiResp.json();

    if (!apiResp.ok || result.Response?.Error) {
      return jsonResponse({
        error: 'Face detection failed',
        detail: result.Response?.Error?.Message || 'Unknown error',
      }, 400);
    }

    const faceInfo = result.Response?.FaceInfos?.[0];
    if (!faceInfo) {
      return jsonResponse({ error: '未检测到人脸' }, 400);
    }

    const attr = faceInfo.FaceAttributesInfo || {};
    const genderValue = attr.Gender;  // Tencent: 0=女, 1=男
    const gender = genderValue === 1 ? 'male' : 'female';

    // 根据性别分配头像框
    const avatarFrameId = gender === 'female' ? 'frame_ribbon' : 'frame_default';

    // 确保 users 表有 face 相关字段（按需创建，兼容旧表）
    await addFaceAuthColumns(env);

    // 保存认证结果
    await env.duichai_db.prepare(`
      UPDATE users SET
        face_authed = 1,
        face_gender = ?,
        avatar_frame_id = ?,
        updated_at = datetime('now')
      WHERE id = ?
    `).bind(gender, avatarFrameId, userId).run();

    return jsonResponse({
      success: true,
      data: {
        face_authed: true,
        face_gender: gender,
        avatar_frame_id: avatarFrameId,
        gender_display: gender === 'female' ? '女' : '男',
        frame_display: gender === 'female' ? '🎀 头像框' : '⭐ 头像框',
      },
      message: '扫脸认证成功',
    });
  } catch (e) {
    return jsonResponse({ error: 'Face auth failed' }, 500);
  }
}

// 按需添加 face 相关字段
async function addFaceAuthColumns(env: Env): Promise<void> {
  const columns = [
    'face_authed INTEGER DEFAULT 0',
    'face_gender TEXT DEFAULT NULL',
    'avatar_frame_id TEXT DEFAULT NULL',
  ];
  for (const colDef of columns) {
    const colName = colDef.split(' ')[0];
    try {
      await env.duichai_db.prepare(
        `ALTER TABLE users ADD COLUMN ${colDef}`
      ).run();
    } catch (_) {
      // 列已存在则忽略
    }
  }
}
