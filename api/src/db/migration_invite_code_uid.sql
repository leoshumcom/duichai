-- 迁移：将已有用户的 invite_code 更新为 UID
-- 邀请码 = UID数字字符串
UPDATE users SET invite_code = CAST(uid AS TEXT) WHERE invite_code IS NULL OR invite_code = '';
UPDATE users SET invite_code = CAST(uid AS TEXT) WHERE CAST(uid AS TEXT) != invite_code;
