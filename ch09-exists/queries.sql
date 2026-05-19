-- 第9章: EXISTS と NOT EXISTS
-- PostgreSQL 18 / MySQL 8.4 LTS で動作確認

-- ============================================================
-- 節 1. EXISTS の基本
-- ============================================================

-- 1.1 EXISTS で active sub を持つユーザー数
SELECT COUNT(*) AS has_active_sub
FROM users u
WHERE EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
);

-- 1.2 EXISTS で active sub を持つユーザー TOP 5
SELECT u.full_name, u.country
FROM users u
WHERE EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
)
ORDER BY u.user_id
LIMIT 5;

-- 1.3 SELECT リスト内 INTERSECT の例 (列構造が意味を持つ)
SELECT u.full_name
FROM users u
WHERE EXISTS (
  SELECT s.plan FROM subscriptions s
  WHERE s.user_id = u.user_id AND s.plan = 'pro'
  INTERSECT
  SELECT s.plan FROM subscriptions s
  WHERE s.user_id = u.user_id AND s.ended_at IS NULL
)
ORDER BY u.user_id
LIMIT 3;

-- ============================================================
-- 節 2. NOT EXISTS
-- ============================================================

-- 2.1 NOT EXISTS で active sub なしのユーザー数
SELECT COUNT(*) AS no_active_sub
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
);

-- 2.2 NOT EXISTS で active sub なし TOP 5
SELECT u.full_name, u.country
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
)
ORDER BY u.user_id
LIMIT 5;

-- 2.3 NOT EXISTS safe count (再確認)
SELECT COUNT(*) AS safe_count
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
);

-- 2.4 LEFT JOIN + IS NULL の等価
SELECT COUNT(*) AS via_anti_join
FROM users u
LEFT JOIN subscriptions s
  ON s.user_id  = u.user_id
  AND s.ended_at IS NULL
WHERE s.subscription_id IS NULL;

-- ============================================================
-- 節 3. EXISTS と INNER JOIN の挙動差
-- ============================================================

-- 3.1 INNER JOIN active sub (1 対 1 seed なので 480)
SELECT COUNT(*) AS via_inner_join
FROM users u
JOIN subscriptions s
  ON s.user_id  = u.user_id
  AND s.ended_at IS NULL;

-- 3.2 INNER JOIN 全 subs (800 行展開)
SELECT COUNT(*) AS join_all_subs
FROM users u
JOIN subscriptions s ON s.user_id = u.user_id;

-- 3.3 DISTINCT JOIN
SELECT COUNT(DISTINCT u.user_id) AS via_distinct_join
FROM users u
JOIN subscriptions s ON s.user_id = u.user_id;

-- 3.4 EXISTS 版
SELECT COUNT(*) AS via_exists
FROM users u
WHERE EXISTS (SELECT 1 FROM subscriptions s WHERE s.user_id = u.user_id);

-- 3.5 IN 版
SELECT COUNT(*) AS via_in
FROM users u
WHERE u.user_id IN (SELECT s.user_id FROM subscriptions s);

-- ============================================================
-- 節 4. 二重 NOT EXISTS (関係除算)
-- ============================================================

-- 4.1 3 特定カテゴリすべてで paid 購入したユーザー (0 名)
SELECT COUNT(*) AS all_3_target
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM categories c
  WHERE c.name IN ('Electronics', 'Audio', 'Books')
    AND NOT EXISTS (
      SELECT 1 FROM orders o
      JOIN order_items oi ON oi.order_id = o.order_id
      JOIN products p    ON p.product_id = oi.product_id
      WHERE o.user_id   = u.user_id
        AND o.status    = 'paid'
        AND p.category_id = c.category_id
    )
);

-- 4.2 HAVING COUNT(DISTINCT) で書き換え (0 名)
SELECT COUNT(*) AS via_having FROM (
  SELECT o.user_id
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  JOIN products p ON p.product_id = oi.product_id
  JOIN categories c ON c.category_id = p.category_id
  WHERE o.status = 'paid'
    AND c.name IN ('Electronics', 'Audio', 'Books')
  GROUP BY o.user_id
  HAVING COUNT(DISTINCT p.category_id) = 3
) AS t;

-- ============================================================
-- 節 5. EXISTS 多段相関
-- ============================================================

-- 5.1 高価格商品 (>4000) を含む paid 注文 TOP 5
SELECT o.order_id, u.full_name, o.total_jpy
FROM orders o
JOIN users u ON u.user_id = o.user_id
WHERE o.status = 'paid'
  AND EXISTS (
    SELECT 1 FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    WHERE oi.order_id = o.order_id
      AND p.price_jpy > 4000
  )
ORDER BY o.total_jpy DESC
LIMIT 5;

-- 5.2 active and paid (両方持つユーザー)
SELECT COUNT(*) AS active_and_paid
FROM users u
WHERE EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id AND s.ended_at IS NULL
)
AND EXISTS (
  SELECT 1 FROM orders o
  WHERE o.user_id = u.user_id AND o.status = 'paid'
);

-- ============================================================
-- 業務クエリ集 (5 本)
-- ============================================================

-- クエリ 1: active sub + paid 注文ユーザー TOP 5
SELECT u.full_name, u.country, s.plan, s.monthly_jpy
FROM users u
JOIN subscriptions s
  ON s.user_id  = u.user_id
  AND s.ended_at IS NULL
WHERE EXISTS (
  SELECT 1 FROM orders o
  WHERE o.user_id = u.user_id AND o.status = 'paid'
)
ORDER BY u.user_id
LIMIT 5;

-- クエリ 2: active sub なしユーザー国別
SELECT u.country, COUNT(*) AS no_active_cnt
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
)
GROUP BY u.country
ORDER BY no_active_cnt DESC;

-- クエリ 3: 高価格商品を含む paid 注文 TOP 5
SELECT o.order_id, u.full_name, o.total_jpy
FROM orders o
JOIN users u ON u.user_id = o.user_id
WHERE o.status = 'paid'
  AND EXISTS (
    SELECT 1 FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    WHERE oi.order_id = o.order_id
      AND p.price_jpy > 4000
  )
ORDER BY o.total_jpy DESC
LIMIT 5;

-- クエリ 4: 複数 paid 注文を持つユーザー (EXISTS 自己相関)
SELECT u.full_name, u.country
FROM users u
WHERE EXISTS (
  SELECT 1 FROM orders o1
  WHERE o1.user_id = u.user_id
    AND o1.status  = 'paid'
    AND EXISTS (
      SELECT 1 FROM orders o2
      WHERE o2.user_id  = u.user_id
        AND o2.status   = 'paid'
        AND o2.order_id <> o1.order_id
    )
)
ORDER BY u.user_id
LIMIT 5;

-- クエリ 5: 関係除算「全 status 経験ユーザー」
SELECT COUNT(*) AS users_with_all_status
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM (VALUES ('paid'), ('cancelled'), ('pending'))
    AS target(status_name)
  WHERE NOT EXISTS (
    SELECT 1 FROM orders o
    WHERE o.user_id = u.user_id
      AND o.status  = target.status_name
  )
);
