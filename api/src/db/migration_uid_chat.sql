-- UID系统
CREATE TABLE IF NOT EXISTS reserved_uids (
    uid INTEGER PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'reserved' CHECK(status IN ('reserved','available','sold','system')),
    price INTEGER NOT NULL DEFAULT 0,
    buyer_id TEXT REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS uid_orders (
    id TEXT PRIMARY KEY,
    uid INTEGER NOT NULL,
    buyer_id TEXT NOT NULL REFERENCES users(id),
    price INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','paid','cancelled')),
    paid_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 俱乐部聊天消息
CREATE TABLE IF NOT EXISTS club_messages (
    id TEXT PRIMARY KEY,
    club_id TEXT NOT NULL REFERENCES clubs(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    parent_id TEXT REFERENCES club_messages(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_club_messages_club ON club_messages(club_id, created_at);

-- 俱乐部消息@提及
CREATE TABLE IF NOT EXISTS club_message_mentions (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL REFERENCES club_messages(id),
    mentioned_user_id TEXT NOT NULL REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_club_mention_message ON club_message_mentions(message_id);
