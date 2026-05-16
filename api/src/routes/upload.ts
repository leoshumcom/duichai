import { jsonResponse, generateId } from '../utils';

interface Env {
  duichai_db: D1Database;
  duichai_assets: R2Bucket;
}

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime'];
const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB

// 文件上传
export async function handleUpload(request: Request, env: Env): Promise<Response> {
  try {
    const formData = await request.formData();
    const file = formData.get('file') as File | null;
    const userId = formData.get('user_id') as string | null;

    if (!file || !userId) {
      return jsonResponse({ error: 'file 和 user_id 为必填' }, 400);
    }

    if (!ALLOWED_TYPES.includes(file.type)) {
      return jsonResponse({
        error: '不支持的文件类型，支持: jpg/png/webp/gif/mp4',
        supported_types: ALLOWED_TYPES,
      }, 400);
    }

    if (file.size > MAX_FILE_SIZE) {
      return jsonResponse({ error: '文件大小超过限制（最大50MB）' }, 400);
    }

    const ext = file.name.split('.').pop() || 'jpg';
    const fileId = generateId();
    const key = `uploads/${userId}/${fileId}.${ext}`;

    const buffer = await file.arrayBuffer();
    await env.duichai_assets.put(key, buffer, {
      httpMetadata: { contentType: file.type },
      customMetadata: {
        userId,
        originalName: file.name,
        uploadedAt: new Date().toISOString(),
      },
    });

    const url = `https://cdn.duichai.com/${key}`;

    return jsonResponse({
      success: true,
      data: {
        url,
        key,
        size: file.size,
        type: file.type,
      },
    }, 201);
  } catch (e) {
    return jsonResponse({ error: '上传失败' }, 500);
  }
}

// 批量上传
export async function handleBatchUpload(request: Request, env: Env): Promise<Response> {
  try {
    const formData = await request.formData();
    const userId = formData.get('user_id') as string | null;
    const files = formData.getAll('files') as File[];

    if (!userId || files.length === 0) {
      return jsonResponse({ error: 'user_id 和 files 为必填' }, 400);
    }

    if (files.length > 9) {
      return jsonResponse({ error: '单次最多上传9个文件' }, 400);
    }

    const results = [];
    for (const file of files) {
      if (!ALLOWED_TYPES.includes(file.type)) {
        results.push({ name: file.name, error: '不支持的文件类型' });
        continue;
      }
      if (file.size > MAX_FILE_SIZE) {
        results.push({ name: file.name, error: '文件过大' });
        continue;
      }

      const ext = file.name.split('.').pop() || 'jpg';
      const fileId = generateId();
      const key = `uploads/${userId}/${fileId}.${ext}`;

      const buffer = await file.arrayBuffer();
      await env.duichai_assets.put(key, buffer, {
        httpMetadata: { contentType: file.type },
      });

      results.push({
        name: file.name,
        url: `https://cdn.duichai.com/${key}`,
        key,
        size: file.size,
        success: true,
      });
    }

    return jsonResponse({
      success: true,
      data: results,
      total: results.length,
      uploaded: results.filter(r => r.success).length,
    });
  } catch (e) {
    return jsonResponse({ error: '上传失败' }, 500);
  }
}

// 删除文件
export async function handleDeleteFile(request: Request, env: Env): Promise<Response> {
  try {
    const body: any = await request.json();
    const { key } = body;
    if (!key) return jsonResponse({ error: 'key 为必填' }, 400);

    await env.duichai_assets.delete(key);
    return jsonResponse({ success: true, message: '已删除' });
  } catch (e) {
    return jsonResponse({ error: '删除失败' }, 500);
  }
}
