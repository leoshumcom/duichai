-- 堆柴数据库初始化脚本
-- Cloudflare D1 (SQLite)

-- 1. 用户表
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

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_invite_code ON users(invite_code);

-- 2. 馆主认证申请表
CREATE TABLE IF NOT EXISTS venue_owner_applications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    business_license TEXT NOT NULL,
    id_card_front TEXT NOT NULL,
    id_card_back TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    contact_wechat TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
    reject_reason TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    reviewed_at TEXT,
    reviewed_by TEXT REFERENCES users(id)
);

-- 3. 馆主-场地关联表
CREATE TABLE IF NOT EXISTS venue_owner_venues (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    venue_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 4. 场地表
CREATE TABLE IF NOT EXISTS venues (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    description TEXT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    poi_id TEXT,
    address TEXT,
    photos TEXT DEFAULT '[]',
    videos TEXT DEFAULT '[]',
    publisher_id TEXT NOT NULL REFERENCES users(id),
    is_free INTEGER NOT NULL DEFAULT 1,
    price_info TEXT,
    open_hours TEXT,
    chaihuo_total INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','hidden','deleted')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_venues_location ON venues(latitude, longitude);
CREATE INDEX idx_venues_chaihuo ON venues(chaihuo_total DESC);
CREATE INDEX idx_venues_status ON venues(status);

-- 5. 场地补充记录
CREATE TABLE IF NOT EXISTS venue_supplements (
    id TEXT PRIMARY KEY,
    venue_id TEXT NOT NULL REFERENCES venues(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    photos TEXT DEFAULT '[]',
    reward_chaihuo INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 6. 场地合并记录
CREATE TABLE IF NOT EXISTS venue_merges (
    id TEXT PRIMARY KEY,
    source_venue_id TEXT NOT NULL REFERENCES venues(id),
    target_venue_id TEXT NOT NULL REFERENCES venues(id),
    merged_by TEXT NOT NULL REFERENCES users(id),
    chaihuo_transferred INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 7. 柴火流水表
CREATE TABLE IF NOT EXISTS chaihuo_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    type TEXT NOT NULL CHECK(type IN ('login_bonus','publish_venue','invite','recharge','tip_given','tip_received','club_donate','ad_purchase','refund','admin_adjust')),
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    reference_id TEXT,
    reference_type TEXT,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_chaihuo_user ON chaihuo_transactions(user_id);
CREATE INDEX idx_chaihuo_created ON chaihuo_transactions(created_at);

-- 8. 评价表
CREATE TABLE IF NOT EXISTS reviews (
    id TEXT PRIMARY KEY,
    venue_id TEXT NOT NULL REFERENCES venues(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    chaihuo_amount INTEGER NOT NULL,
    content TEXT,
    photos TEXT DEFAULT '[]',
    parent_id TEXT REFERENCES reviews(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_reviews_venue ON reviews(venue_id);

-- 9. 举报表
CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    reporter_id TEXT NOT NULL REFERENCES users(id),
    target_type TEXT NOT NULL CHECK(target_type IN ('venue','review','user')),
    target_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
    handled_by TEXT REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    handled_at TEXT
);

-- 10. 通知表
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    is_read INTEGER NOT NULL DEFAULT 0,
    reference_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- 11. 用户等级
CREATE TABLE IF NOT EXISTS user_levels (
    level INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    min_chaihuo INTEGER NOT NULL,
    perks TEXT DEFAULT '[]'
);

-- 12. 勋章
CREATE TABLE IF NOT EXISTS badges (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT,
    description TEXT,
    criteria TEXT
);

-- 13. 用户-勋章关系
CREATE TABLE IF NOT EXISTS user_badges (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    badge_id TEXT NOT NULL REFERENCES badges(id),
    earned_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(user_id, badge_id)
);

-- 14. 邀请记录
CREATE TABLE IF NOT EXISTS invites (
    id TEXT PRIMARY KEY,
    inviter_id TEXT NOT NULL REFERENCES users(id),
    invitee_id TEXT NOT NULL REFERENCES users(id),
    reward_chaihuo INTEGER NOT NULL DEFAULT 10,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 15. 充值订单
CREATE TABLE IF NOT EXISTS recharge_orders (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    amount INTEGER NOT NULL,
    chaihuo_amount INTEGER NOT NULL,
    payment_method TEXT NOT NULL,
    payment_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','paid','failed','refunded')),
    paid_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 16. 支付回调记录
CREATE TABLE IF NOT EXISTS payment_callbacks (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES recharge_orders(id),
    raw_data TEXT NOT NULL,
    processed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 17. 俱乐部
CREATE TABLE IF NOT EXISTS clubs (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    avatar TEXT,
    banner TEXT,
    description TEXT,
    slogan TEXT,
    contact_phone TEXT,
    contact_wechat TEXT,
    contact_email TEXT,
    sport_types TEXT NOT NULL DEFAULT '[]',
    region_province TEXT,
    region_city TEXT,
    region_district TEXT,
    creator_id TEXT NOT NULL REFERENCES users(id),
    member_count INTEGER NOT NULL DEFAULT 1,
    chaihuo_total INTEGER NOT NULL DEFAULT 0,
    is_certified INTEGER NOT NULL DEFAULT 0,
    join_type TEXT NOT NULL DEFAULT 'public' CHECK(join_type IN ('public','review','invite')),
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','frozen','dissolved')),
    share_page TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 18. 俱乐部成员
CREATE TABLE IF NOT EXISTS club_members (
    id TEXT PRIMARY KEY,
    club_id TEXT NOT NULL REFERENCES clubs(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'member' CHECK(role IN ('creator','admin','member')),
    joined_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(club_id, user_id)
);

-- 19. 俱乐部认证申请
CREATE TABLE IF NOT EXISTS club_certifications (
    id TEXT PRIMARY KEY,
    club_id TEXT NOT NULL REFERENCES clubs(id),
    applicant_id TEXT NOT NULL REFERENCES users(id),
    id_card_front TEXT NOT NULL,
    id_card_back TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
    reject_reason TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    reviewed_at TEXT
);

-- 20. 俱乐部公告
CREATE TABLE IF NOT EXISTS club_announcements (
    id TEXT PRIMARY KEY,
    club_id TEXT NOT NULL REFERENCES clubs(id),
    author_id TEXT NOT NULL REFERENCES users(id),
    type TEXT NOT NULL DEFAULT 'notice' CHECK(type IN ('notice','activity','training')),
    title TEXT NOT NULL,
    content TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 21. 俱乐部相册
CREATE TABLE IF NOT EXISTS club_albums (
    id TEXT PRIMARY KEY,
    club_id TEXT NOT NULL REFERENCES clubs(id),
    uploader_id TEXT NOT NULL REFERENCES users(id),
    image_url TEXT NOT NULL,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 22. 俱乐部-场地关联
CREATE TABLE IF NOT EXISTS club_venues (
    id TEXT PRIMARY KEY,
    club_id TEXT NOT NULL REFERENCES clubs(id),
    venue_id TEXT NOT NULL REFERENCES venues(id),
    is_home_ground INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 23. 置顶广告投放
CREATE TABLE IF NOT EXISTS ad_placements (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users(id),
    venue_id TEXT NOT NULL REFERENCES venues(id),
    region_level TEXT NOT NULL CHECK(region_level IN ('national','province','city','district','street')),
    sport_type TEXT NOT NULL,
    queue_position INTEGER NOT NULL DEFAULT 0,
    start_time TEXT,
    end_time TEXT,
    status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','active','completed','cancelled')),
    price INTEGER NOT NULL,
    payment_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 24. 置顶排队队列
CREATE TABLE IF NOT EXISTS ad_queue (
    id TEXT PRIMARY KEY,
    placement_id TEXT NOT NULL REFERENCES ad_placements(id),
    position INTEGER NOT NULL,
    estimated_start_time TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 25. 广告位管理 (后台)
CREATE TABLE IF NOT EXISTS ad_slots (
    id TEXT PRIMARY KEY,
    slot_key TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 0,
    image_url TEXT,
    link_url TEXT,
    duration INTEGER,
    start_time TEXT,
    end_time TEXT,
    platforms TEXT DEFAULT '["ios","android"]',
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 26. 管理员账户
CREATE TABLE IF NOT EXISTS admin_users (
    id TEXT PRIMARY KEY REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'admin' CHECK(role IN ('super_admin','admin','auditor')),
    last_login_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 27. 每日数据统计
CREATE TABLE IF NOT EXISTS daily_stats (
    date TEXT PRIMARY KEY,
    total_users INTEGER NOT NULL DEFAULT 0,
    new_users INTEGER NOT NULL DEFAULT 0,
    dau INTEGER NOT NULL DEFAULT 0,
    total_venues INTEGER NOT NULL DEFAULT 0,
    new_venues INTEGER NOT NULL DEFAULT 0,
    total_clubs INTEGER NOT NULL DEFAULT 0,
    new_clubs INTEGER NOT NULL DEFAULT 0,
    chaihuo_issued INTEGER NOT NULL DEFAULT 0,
    chaihuo_consumed INTEGER NOT NULL DEFAULT 0,
    recharge_amount REAL NOT NULL DEFAULT 0,
    ad_revenue REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 28. @ 提及关系
CREATE TABLE IF NOT EXISTS mentions (
    id TEXT PRIMARY KEY,
    review_id TEXT NOT NULL REFERENCES reviews(id),
    mentioned_user_id TEXT NOT NULL REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 29. 会话表（Token持久化）
CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL DEFAULT (datetime('now', '+30 days'))
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);

-- 插入默认等级
INSERT OR IGNORE INTO user_levels (level, name, min_chaihuo, perks) VALUES
    (1, '柴薪', 0, '["基础功能"]'),
    (2, '柴火堆', 100, '["发布场地次数+1"]'),
    (3, '篝火', 500, '["可置顶场地1次/月"]'),
    (4, '火炬手', 2000, '["认证标志"]'),
    (5, '柴神', 10000, '["专属标签","审核优先"]');

-- 插入默认勋章
INSERT OR IGNORE INTO badges (id, name, description, criteria) VALUES
    ('pioneer', '拓荒者', '发布第一个场地', '发布1个场地'),
    ('venue_100', '百场之王', '发布100个场地', '发布100个场地'),
    ('chaihuo_10000', '柴火富翁', '柴火余额达到10000', '余额达10000'),
    ('top_tipper', '榜一大哥', '成为任意场地的添柴TOP1', '场地添柴榜第一'),
    ('social', '社交达人', '邀请50位好友', '邀请50人'),
    ('auditor', '金牌审核', '审核通过100条举报', '审核100条'),
    ('supplement', '全能补充', '补充完善50个场地信息', '补充50条');
