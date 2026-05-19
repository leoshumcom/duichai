-- Migration: 更新等级体系（柴火值改为经验值，新增LV6-LV8）
-- 柴火值 = total_chaihuo_earned（只增不减），而非余额

-- 先清除旧等级
DELETE FROM user_levels;

-- 插入新等级
INSERT OR IGNORE INTO user_levels (level, name, min_chaihuo, perks) VALUES
(1, '柴薪', 0, '["基础功能"]'),
(2, '柴火堆', 100, '["发布场地次数+1"]'),
(3, '篝火', 500, '["可置顶场地1次/月"]'),
(4, '火炬手', 2000, '["认证标志"]'),
(5, '柴神', 5000, '["专属标签","审核优先"]'),
(6, '柴王', 10000, '["专属边框","优先客服"]'),
(7, '柴圣', 20000, '["独立标识","线下活动资格"]'),
(8, '柴祖', 50000, '["创始会员荣誉","永久身份标识"]');

-- 将现有用户的等级按 total_chaihuo_earned 重新计算
-- 找到每个用户对应的新等级
UPDATE users SET level = (
  SELECT MAX(level) FROM user_levels WHERE min_chaihuo <= COALESCE(total_chaihuo_earned, 0)
);
