-- 堆柴测试数据种子
-- 填充示例数据用于开发测试

-- 测试用户
INSERT OR IGNORE INTO users (id, email, nickname, password_hash, chaihuo_balance, total_chaihuo_earned, role)
VALUES
  ('test-user-1', 'test1@duichai.com', '篮球小王', 'test_hash', 500, 1500, 'user'),
  ('test-user-2', 'test2@duichai.com', '足球老张', 'test_hash', 1200, 3000, 'owner'),
  ('test-user-3', 'test3@duichai.com', '羽球小李', 'test_hash', 300, 800, 'user'),
  ('test-admin', 'admin@duichai.com', '堆柴管理员', 'test_hash', 9999, 99999, 'admin');

-- 测试场地
INSERT OR IGNORE INTO venues (id, name, type, latitude, longitude, address, publisher_id, chaihuo_total, status)
VALUES
  ('venue-1', '朝阳公园篮球场', '篮球', 39.9342, 116.4736, '北京市朝阳区朝阳公园南路1号', 'test-user-1', 1560, 'approved'),
  ('venue-2', '奥体中心足球场', '足球', 39.9929, 116.3957, '北京市朝阳区安定路甲3号', 'test-user-2', 3200, 'approved'),
  ('venue-3', '首体羽毛球馆', '羽毛球', 39.9389, 116.3257, '北京市海淀区中关村南大街56号', 'test-user-3', 890, 'approved'),
  ('venue-4', '东单体育中心', '篮球', 39.9087, 116.4121, '北京市东城区崇文门内大街108号', 'test-user-1', 2100, 'approved'),
  ('venue-5', '五棵松篮球公园', '篮球', 39.9076, 116.2770, '北京市海淀区复兴路69号', 'test-user-2', 4500, 'approved');

-- 测试俱乐部
INSERT OR IGNORE INTO clubs (id, name, description, slogan, sport_types, creator_id, member_count, chaihuo_total, is_certified)
VALUES
  ('club-1', '朝阳篮球联盟', '朝阳区最大的篮球爱好者组织', '无兄弟不篮球', '["篮球"]', 'test-user-1', 45, 8900, 1),
  ('club-2', '北京足球狂热', '每周六奥体约球', '足球是圆的', '["足球"]', 'test-user-2', 32, 5600, 0),
  ('club-3', '羽你同行', '羽毛球爱好者俱乐部', '一起打球一起流汗', '["羽毛球"]', 'test-user-3', 18, 2300, 0);

-- 测试俱乐部成员
INSERT OR IGNORE INTO club_members (id, club_id, user_id, role)
VALUES
  ('cm-1', 'club-1', 'test-user-1', 'creator'),
  ('cm-2', 'club-1', 'test-user-2', 'admin'),
  ('cm-3', 'club-1', 'test-user-3', 'member'),
  ('cm-4', 'club-2', 'test-user-2', 'creator'),
  ('cm-5', 'club-2', 'test-user-1', 'member'),
  ('cm-6', 'club-3', 'test-user-3', 'creator');

-- 测试柴火流水
INSERT OR IGNORE INTO chaihuo_transactions (id, user_id, type, amount, balance_after, reference_id, reference_type, description)
VALUES
  ('tx-1', 'test-user-1', 'publish_venue', 100, 500, 'venue-1', 'venue', '发布场地奖励'),
  ('tx-2', 'test-user-2', 'publish_venue', 100, 1200, 'venue-2', 'venue', '发布场地奖励'),
  ('tx-3', 'test-user-1', 'tip_given', -50, 450, 'venue-2', 'venue', '给奥体中心添柴'),
  ('tx-4', 'test-user-3', 'tip_given', -30, 270, 'venue-1', 'venue', '给朝阳公园添柴');

-- 插入每日统计（测试数据用）
INSERT OR IGNORE INTO daily_stats (date, total_users, new_users, dau, total_venues, new_venues, chaihuo_issued)
VALUES
  ('2026-05-10', 1, 1, 1, 0, 0, 0),
  ('2026-05-11', 2, 1, 2, 1, 1, 100),
  ('2026-05-12', 2, 0, 2, 2, 1, 100),
  ('2026-05-13', 3, 1, 3, 3, 1, 100),
  ('2026-05-14', 3, 0, 2, 4, 1, 100),
  ('2026-05-15', 4, 1, 3, 5, 1, 100),
  ('2026-05-16', 4, 0, 4, 5, 0, 0);
