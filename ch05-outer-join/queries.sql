-- 第 5 章: OUTER JOIN: 欠損を扱う
-- 実行: psql -h localhost -p 5418 -U app -d handbook -f ch05-outer-join/queries.sql
\pset null '(NULL)'

-- ============================================================
-- 節 1. INNER JOIN との対比 (概念用最小データ)
--   本文の t1 / t2 は説明用の概念データのため、
--   サンプル DB では再現しない (節 2-10 の実機データで代替)。
-- ============================================================

-- ============================================================
-- 節 3. アンチジョイン: アクティブ subscription を持たないユーザー (先頭 5 名)
-- ============================================================
SELECT u.user_id, u.full_name, u.country
FROM users u
LEFT JOIN subscriptions s
  ON u.user_id = s.user_id AND s.ended_at IS NULL
WHERE s.subscription_id IS NULL
ORDER BY u.user_id
LIMIT 5;

-- ============================================================
-- 節 4. 国別のアクティブ契約数と未契約者数
-- ============================================================
SELECT
  u.country,
  COUNT(s.subscription_id) AS active_subs,
  COUNT(*) - COUNT(s.subscription_id) AS without_active
FROM users u
LEFT JOIN subscriptions s
  ON u.user_id = s.user_id AND s.ended_at IS NULL
GROUP BY u.country
ORDER BY u.country;

-- ============================================================
-- 節 4. 組織図を CEO まで含めて取り出す (先頭 6 行)
-- ============================================================
SELECT
  e.employee_id,
  e.name AS employee,
  COALESCE(m.name, '(no manager)') AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.employee_id
ORDER BY e.employee_id
LIMIT 6;

-- ============================================================
-- 節 5. generate_series で日付軸を作り欠損日も 0 表示
-- ============================================================
SELECT
  cal.d::date AS d,
  COUNT(o.order_id) AS orders,
  COALESCE(SUM(o.total_jpy), 0) AS revenue
FROM generate_series(
  '2025-12-26'::date,
  '2026-01-02'::date,
  '1 day'::interval
) AS cal(d)
LEFT JOIN orders o
  ON o.ordered_at::date = cal.d::date
 AND o.status = 'paid'
GROUP BY cal.d
ORDER BY cal.d;

-- ============================================================
-- 節 6. LEFT JOIN LATERAL: 各ユーザーの最新 paid 注文 1 件 (先頭 5 行)
-- ============================================================
SELECT
  u.user_id,
  u.full_name,
  lo.order_id,
  lo.ordered_at,
  lo.total_jpy
FROM users u
LEFT JOIN LATERAL (
  SELECT o.order_id, o.ordered_at, o.total_jpy
  FROM orders o
  WHERE o.user_id = u.user_id
    AND o.status = 'paid'
  ORDER BY o.ordered_at DESC
  LIMIT 1
) lo ON TRUE
ORDER BY u.full_name
LIMIT 5;

-- ============================================================
-- 節 7. FULL OUTER JOIN: 2024 vs 2025 の顧客集合突合
-- ============================================================
WITH y2024 AS (
  SELECT DISTINCT user_id FROM orders
  WHERE ordered_at >= DATE '2024-01-01'
    AND ordered_at <  DATE '2025-01-01'
    AND status = 'paid'
),
y2025 AS (
  SELECT DISTINCT user_id FROM orders
  WHERE ordered_at >= DATE '2025-01-01'
    AND ordered_at <  DATE '2026-01-01'
    AND status = 'paid'
)
SELECT
  COUNT(*) FILTER (WHERE a.user_id IS NOT NULL AND b.user_id IS NOT NULL) AS both_years,
  COUNT(*) FILTER (WHERE a.user_id IS NOT NULL AND b.user_id IS NULL)     AS only_2024,
  COUNT(*) FILTER (WHERE a.user_id IS NULL     AND b.user_id IS NOT NULL) AS only_2025
FROM y2024 a
FULL OUTER JOIN y2025 b ON a.user_id = b.user_id;

-- ============================================================
-- 節 9. 3 段 LEFT JOIN: users x orders x order_items (先頭 5 行)
-- ============================================================
SELECT u.user_id, u.full_name, o.order_id, oi.product_id
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
ORDER BY u.user_id, o.order_id, oi.product_id
LIMIT 5;

-- ============================================================
-- 業務クエリ 1: アクティブ契約のないユーザーを国別に集計
-- ============================================================
SELECT
  u.country,
  COUNT(*) AS users_without_active_subscription
FROM users u
LEFT JOIN subscriptions s
  ON u.user_id = s.user_id AND s.ended_at IS NULL
WHERE s.subscription_id IS NULL
GROUP BY u.country
ORDER BY users_without_active_subscription DESC;

-- ============================================================
-- 業務クエリ 2: 日付軸 x 売上 (欠損日も 0 表示)
-- ============================================================
SELECT
  cal.d::date AS d,
  COUNT(o.order_id) AS orders,
  COALESCE(SUM(o.total_jpy), 0) AS revenue
FROM generate_series(
  '2025-12-26'::date,
  '2026-01-02'::date,
  '1 day'::interval
) AS cal(d)
LEFT JOIN orders o
  ON o.ordered_at::date = cal.d::date
 AND o.status = 'paid'
GROUP BY cal.d
ORDER BY cal.d;

-- ============================================================
-- 業務クエリ 3: 組織図 (CEO + title + manager_title) 先頭 6 行
-- ============================================================
SELECT
  e.employee_id,
  e.name AS employee,
  e.title,
  COALESCE(m.name, '(no manager)') AS manager,
  COALESCE(m.title, '-')           AS manager_title
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.employee_id
ORDER BY e.employee_id
LIMIT 6;

-- ============================================================
-- 業務クエリ 4: ユーザーごとの最新 paid 注文 1 件 (country 付き、先頭 5 行)
-- ============================================================
SELECT
  u.user_id,
  u.full_name,
  u.country,
  lo.order_id,
  lo.ordered_at,
  lo.total_jpy
FROM users u
LEFT JOIN LATERAL (
  SELECT o.order_id, o.ordered_at, o.total_jpy
  FROM orders o
  WHERE o.user_id = u.user_id
    AND o.status = 'paid'
  ORDER BY o.ordered_at DESC
  LIMIT 1
) lo ON TRUE
ORDER BY u.full_name
LIMIT 5;

-- ============================================================
-- 業務クエリ 5: FULL OUTER JOIN (both_years / only_2024 / only_2025 / total)
-- ============================================================
WITH y2024 AS (
  SELECT DISTINCT user_id FROM orders
  WHERE ordered_at >= DATE '2024-01-01'
    AND ordered_at <  DATE '2025-01-01'
    AND status = 'paid'
),
y2025 AS (
  SELECT DISTINCT user_id FROM orders
  WHERE ordered_at >= DATE '2025-01-01'
    AND ordered_at <  DATE '2026-01-01'
    AND status = 'paid'
)
SELECT
  COUNT(*) FILTER (WHERE a.user_id IS NOT NULL AND b.user_id IS NOT NULL) AS both_years,
  COUNT(*) FILTER (WHERE a.user_id IS NOT NULL AND b.user_id IS NULL)     AS only_2024,
  COUNT(*) FILTER (WHERE a.user_id IS NULL     AND b.user_id IS NOT NULL) AS only_2025,
  COUNT(*)                                                                 AS total_distinct_users
FROM y2024 a
FULL OUTER JOIN y2025 b ON a.user_id = b.user_id;
