/**
 * 数据库初始化
 */

export async function initDB(db: D1Database): Promise<void> {
  const schema = `
    -- 用户表
    CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        nickname TEXT NOT NULL,
        phone TEXT,
        password_hash TEXT NOT NULL,
        avatar TEXT,
        role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('user','owner','admin')),
        level INTEGER NOT NULL DEFAULT 1,
        chaihuo_balance INTEGER NOT NULL DEFAULT 1,
        total_chaihuo_earned INTEGER NOT NULL DEFAULT 0,
        total_chaihuo_spent INTEGER NOT NULL DEFAULT 0,
        invite_code TEXT UNIQUE,
        invited_by TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

  CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      expires_at TEXT NOT NULL DEFAULT (datetime('now', '+30 days'))
  );

  CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
  `;

  const statements = schema.split(';').filter(s => s.trim());
  
  for (const stmt of statements) {
    await db.exec(stmt);
  }
}
