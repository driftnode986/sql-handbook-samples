-- ch06-group-by/queries.sql
-- 書籍『実践 SQL ハンドブック』第 6 章 (GROUP BY と集約関数)
--
-- 実行: psql -h localhost -p 5418 -U app -d handbook -f ch06-group-by/queries.sql
-- 期待出力との比較: 本ファイルを `\pset null '(NULL)'` で実行し
--                   ch06-group-by/expected_output.txt と diff

\pset null '(NULL)'
\pset border 1

-- ============================================================
-- 第 6 章 本文クエリ
-- ============================================================

-- 節 1: GROUP BY 最小例 (status 別 件数 + 売上)
SELECT status, COUNT(*), SUM(total_jpy) AS total_revenue
FROM orders
GROUP BY status
ORDER BY status;

-- 節 1.1: 関数従属性 (PRIMARY KEY が GROUP BY にあれば他列 SELECT 可)
SELECT u.user_id, u.full_name, COUNT(o.order_id)
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.user_id
ORDER BY 3 DESC
LIMIT 3;

-- 節 2.1: COUNT の 3 つの顔
SELECT
  COUNT(*)        AS rows_all,
  COUNT(total_jpy) AS rows_with_value,
  COUNT(DISTINCT status) AS distinct_status
FROM orders;

-- 節 2.1: NULL を許す列での COUNT 差
SELECT
  COUNT(*)        AS rows_all,
  COUNT(ended_at) AS rows_ended
FROM subscriptions;

-- 節 2.2: 空集合での SUM/AVG は NULL
SELECT
  SUM(total_jpy)   AS sum_total,
  COUNT(*)         AS row_count,
  AVG(total_jpy)   AS avg_total
FROM orders
WHERE status = 'NOT_EXIST';

-- 節 2.2: COALESCE 防御
SELECT
  COALESCE(SUM(total_jpy), 0) AS sum_total,
  COUNT(*)                    AS row_count
FROM orders
WHERE status = 'NOT_EXIST';

-- 節 2.3: MAX/MIN で日付範囲を確認
SELECT
  MAX(ordered_at)::date AS latest_order,
  MIN(ordered_at)::date AS earliest_order
FROM orders;

-- 節 2.4: AVG vs AVG(DISTINCT)
SELECT
  AVG(total_jpy)          AS avg_all,
  AVG(DISTINCT total_jpy) AS avg_distinct
FROM orders
WHERE status = 'paid';

-- 節 3: WHERE と HAVING の使い分け (2025年で210件以上の月)
SELECT
  TO_CHAR(DATE_TRUNC('month', ordered_at), 'YYYY-MM') AS month,
  COUNT(*) AS order_count
FROM orders
WHERE ordered_at >= DATE '2025-01-01'
  AND ordered_at <  DATE '2026-01-01'
GROUP BY DATE_TRUNC('month', ordered_at)
HAVING COUNT(*) >= 210
ORDER BY month;

-- 節 3.2: GROUP BY なしの HAVING (全行 1 グループ扱い)
SELECT COUNT(*) AS row_count
FROM orders
HAVING COUNT(*) > 100;

-- 節 4: 集約関数の NULL 扱い (空集合での 3 関数比較 + COALESCE)
SELECT
  COALESCE(SUM(total_jpy), 0) AS revenue,
  COALESCE(STRING_AGG(status, ','), '') AS statuses,
  COALESCE(ARRAY_AGG(status), ARRAY[]::text[]) AS status_array
FROM orders
WHERE status = 'NOT_EXIST';

-- 節 5: 多対多 GROUP BY 水増し事故 (User 1)
-- 正しい (orders だけ集計)
SELECT u.full_name, SUM(o.total_jpy) AS total
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.status = 'paid' AND u.full_name = 'User 1'
GROUP BY u.full_name;

-- NG (order_items まで JOIN したまま orders.total_jpy を SUM = 3 倍水増し)
SELECT u.full_name, SUM(o.total_jpy) AS total
FROM users u
JOIN orders o ON u.user_id = o.user_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status = 'paid' AND u.full_name = 'User 1'
GROUP BY u.full_name;

-- 正しい (明細レベルで集計)
SELECT u.full_name, SUM(oi.quantity * oi.unit_price) AS total
FROM users u
JOIN orders o ON u.user_id = o.user_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status = 'paid' AND u.full_name = 'User 1'
GROUP BY u.full_name;

-- 節 6: FILTER (WHERE ...) で条件付き集計
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE status = 'paid')      AS paid_count,
  COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_count,
  SUM(total_jpy) FILTER (WHERE status = 'paid') AS paid_revenue
FROM orders;

-- 節 7.1: STRING_AGG (PG)
SELECT
  c.name AS category,
  STRING_AGG(p.name, ', ' ORDER BY p.price_jpy DESC) AS products_by_price_desc
FROM categories c
JOIN products p ON c.category_id = p.category_id
WHERE c.name IN ('Books', 'Knives')
GROUP BY c.name
ORDER BY c.name;

-- 節 7.2: ARRAY_AGG (PG のみ)
SELECT
  c.name AS category,
  ARRAY_AGG(p.name ORDER BY p.price_jpy DESC) AS products
FROM categories c
JOIN products p ON c.category_id = p.category_id
WHERE c.name IN ('Books', 'Knives')
GROUP BY c.name
ORDER BY c.name;

-- 節 8: ROLLUP 1 列 (国別 + 全体合計)
SELECT
  COALESCE(u.country, 'ALL') AS country,
  SUM(o.total_jpy) AS revenue,
  COUNT(*) AS order_count,
  GROUPING(u.country) AS grp
FROM orders o
JOIN users u ON o.user_id = u.user_id
WHERE o.status = 'paid'
GROUP BY ROLLUP (u.country)
ORDER BY grp, country;

-- 節 8.1: ROLLUP 2 列 (月 × ステータス)
SELECT
  COALESCE(TO_CHAR(DATE_TRUNC('month', ordered_at), 'YYYY-MM'), 'ALL') AS month,
  COALESCE(status, 'ALL') AS status,
  COUNT(*) AS cnt
FROM orders
WHERE ordered_at >= DATE '2025-10-01' AND ordered_at < DATE '2026-01-01'
GROUP BY ROLLUP (DATE_TRUNC('month', ordered_at), status)
ORDER BY
  GROUPING(DATE_TRUNC('month', ordered_at)),
  DATE_TRUNC('month', ordered_at),
  GROUPING(status),
  status;

-- 節 9: CUBE (国 × プラン)
SELECT
  COALESCE(u.country, 'ALL') AS country,
  COALESCE(s.plan, 'ALL') AS plan,
  COUNT(*) AS sub_count,
  GROUPING(u.country) AS gc,
  GROUPING(s.plan) AS gp
FROM subscriptions s
JOIN users u ON s.user_id = u.user_id
GROUP BY CUBE (u.country, s.plan)
ORDER BY gc, gp, country, plan;

-- 節 9: GROUPING SETS (国 / プラン / 全体)
SELECT
  COALESCE(u.country, 'ALL') AS country,
  COALESCE(s.plan, 'ALL') AS plan,
  COUNT(*) AS sub_count
FROM subscriptions s
JOIN users u ON s.user_id = u.user_id
GROUP BY GROUPING SETS ((u.country), (s.plan), ())
ORDER BY GROUPING(u.country), GROUPING(s.plan), country, plan;

-- 節 10: 関数従属性で SELECT に full_name を書ける (MySQL 8.0+ も同仕様)
SELECT u.user_id, u.full_name, COUNT(o.order_id)
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.user_id
LIMIT 3;

-- ============================================================
-- 業務クエリ集 (6 本)
-- ============================================================

-- BQ #1: カテゴリ別売上 TOP 5
SELECT
  c.name AS category,
  SUM(oi.quantity * oi.unit_price) AS revenue_jpy
FROM categories c
JOIN products p ON c.category_id = p.category_id
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status = 'paid'
GROUP BY c.name
ORDER BY revenue_jpy DESC
LIMIT 5;

-- BQ #2: 月次注文サマリ (ステータス別件数 + 売上)
SELECT
  DATE_TRUNC('month', ordered_at)::date AS month,
  COUNT(*) AS total_orders,
  COUNT(*) FILTER (WHERE status = 'paid')      AS paid_orders,
  COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_orders,
  SUM(total_jpy) FILTER (WHERE status = 'paid') AS paid_revenue
FROM orders
WHERE ordered_at >= DATE '2025-10-01'
  AND ordered_at <  DATE '2026-01-01'
GROUP BY DATE_TRUNC('month', ordered_at)
ORDER BY month;

-- BQ #3: プラン別アクティブ契約数 + 平均契約日数
SELECT
  plan,
  COUNT(*) FILTER (WHERE ended_at IS NULL) AS active_count,
  COUNT(*) AS total_count,
  ROUND(AVG(COALESCE(ended_at::date, DATE '2026-05-19') - started_at::date)) AS avg_days
FROM subscriptions
GROUP BY plan
ORDER BY plan;

-- BQ #4: 国別売上 ROLLUP (国 → 全体合計)
SELECT
  COALESCE(u.country, 'ALL') AS country,
  SUM(o.total_jpy) AS revenue,
  COUNT(*) AS order_count,
  GROUPING(u.country) AS grp
FROM orders o
JOIN users u ON o.user_id = u.user_id
WHERE o.status = 'paid'
GROUP BY ROLLUP (u.country)
ORDER BY grp, country;

-- BQ #5: 平均購入額 TOP 10 ユーザー (HAVING で 5 件以上の paid 注文)
SELECT
  u.full_name,
  COUNT(*) AS order_count,
  ROUND(AVG(o.total_jpy)) AS avg_jpy,
  SUM(o.total_jpy) AS total_jpy
FROM users u
JOIN orders o ON u.user_id = o.user_id
WHERE o.status = 'paid'
GROUP BY u.user_id, u.full_name
HAVING COUNT(*) >= 5
ORDER BY avg_jpy DESC
LIMIT 10;

-- BQ #6: 商品別 購入ユーザーリスト (STRING_AGG, product_id 1-5)
SELECT
  p.name AS product,
  COUNT(DISTINCT u.user_id) AS buyer_count,
  STRING_AGG(DISTINCT u.full_name, ', ' ORDER BY u.full_name) AS buyers
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
JOIN users u ON o.user_id = u.user_id
WHERE o.status = 'paid'
  AND p.product_id <= 5
GROUP BY p.product_id, p.name
ORDER BY p.product_id;
