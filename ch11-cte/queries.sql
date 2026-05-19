-- ============================================================
-- 第11章: WITH (CTE) - 読める SQL を書く
-- 実践 SQL ハンドブック サンプルクエリ集
-- 対応 RDBMS: PostgreSQL 18 / MySQL 8.4 LTS (注記済み)
-- ============================================================

\pset null '(NULL)'

-- ============================================================
-- 1. WITH の基本構文 - paid 注文数 TOP 5
-- ============================================================

-- CTE 版
WITH user_paid_orders AS (
  SELECT
    user_id,
    COUNT(*)         AS paid_cnt,
    SUM(total_jpy)   AS paid_revenue
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
)
SELECT
  u.full_name,
  u.country,
  upo.paid_cnt,
  upo.paid_revenue
FROM user_paid_orders upo
INNER JOIN users u ON u.user_id = upo.user_id
ORDER BY upo.paid_revenue DESC
LIMIT 5;

-- 派生テーブル版 (同じ結果)
SELECT
  u.full_name,
  u.country,
  upo.paid_cnt,
  upo.paid_revenue
FROM (
  SELECT
    user_id,
    COUNT(*)         AS paid_cnt,
    SUM(total_jpy)   AS paid_revenue
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
) AS upo
INNER JOIN users u ON u.user_id = upo.user_id
ORDER BY upo.paid_revenue DESC
LIMIT 5;

-- ============================================================
-- 2. 列名の明示
-- ============================================================

WITH user_summary (uid, paid_cnt, total) AS (
  SELECT
    user_id,
    COUNT(*),
    SUM(total_jpy)
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
)
SELECT u.full_name, us.paid_cnt, us.total
FROM user_summary us
INNER JOIN users u ON u.user_id = us.uid
ORDER BY us.total DESC
LIMIT 3;

-- ============================================================
-- 3. 複数 CTE をカンマで並べる - User 1 のカテゴリ別購入
-- ============================================================

WITH paid_orders_per_user AS (
  SELECT
    o.user_id,
    COUNT(*)         AS paid_cnt,
    SUM(o.total_jpy) AS total_paid_revenue
  FROM orders o
  WHERE o.status = 'paid'
  GROUP BY o.user_id
),
category_spend_per_user AS (
  SELECT
    o.user_id,
    c.name                                AS category_name,
    SUM(oi.quantity * oi.unit_price)      AS category_spend
  FROM orders o
  INNER JOIN order_items oi ON oi.order_id = o.order_id
  INNER JOIN products p     ON p.product_id = oi.product_id
  INNER JOIN categories c   ON c.category_id = p.category_id
  WHERE o.status = 'paid'
  GROUP BY o.user_id, c.name
)
SELECT
  u.full_name,
  p.paid_cnt,
  p.total_paid_revenue,
  cs.category_name,
  cs.category_spend
FROM users u
INNER JOIN paid_orders_per_user    p  ON p.user_id  = u.user_id
INNER JOIN category_spend_per_user cs ON cs.user_id = u.user_id
WHERE u.full_name = 'User 1'
ORDER BY cs.category_spend DESC;

-- ============================================================
-- 4. CTE 間の前方参照
-- ============================================================

WITH cte1 AS (
  SELECT user_id, SUM(total_jpy) AS revenue
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
),
cte2 AS (
  SELECT u.country, AVG(c1.revenue)::int AS avg_revenue
  FROM cte1 c1
  INNER JOIN users u ON u.user_id = c1.user_id
  GROUP BY u.country
)
SELECT * FROM cte2 ORDER BY avg_revenue DESC;

-- ============================================================
-- 5. 同じ CTE を複数回参照 - 月次前月比
-- ============================================================

WITH monthly_revenue AS (
  SELECT
    DATE_TRUNC('month', ordered_at)::date AS month,
    SUM(total_jpy)                        AS revenue
  FROM orders
  WHERE status = 'paid'
  GROUP BY 1
)
SELECT
  m.month,
  m.revenue,
  prev.revenue                            AS prev_revenue,
  m.revenue - prev.revenue                AS diff
FROM monthly_revenue m
LEFT JOIN monthly_revenue prev
  ON prev.month = (m.month - INTERVAL '1 month')::date
ORDER BY m.month
LIMIT 5;

-- ============================================================
-- 6. アンチパターン: 不要な CTE
-- ============================================================

WITH paid_orders AS (
  SELECT * FROM orders WHERE status = 'paid'
)
SELECT COUNT(*) FROM paid_orders;

SELECT COUNT(*) FROM orders WHERE status = 'paid';

-- ============================================================
-- 7. 第 8 章のサブクエリを CTE で書き直す
-- ============================================================

-- サブクエリ版
SELECT u.full_name
FROM users u
WHERE u.user_id IN (
  SELECT s.user_id
  FROM subscriptions s
  WHERE s.ended_at IS NULL
)
ORDER BY u.full_name
LIMIT 3;

-- CTE 版
WITH active_sub_users AS (
  SELECT DISTINCT user_id
  FROM subscriptions
  WHERE ended_at IS NULL
)
SELECT u.full_name
FROM users u
INNER JOIN active_sub_users asu ON asu.user_id = u.user_id
ORDER BY u.full_name
LIMIT 3;

-- ============================================================
-- 8. 第 10 章の CASE 式を CTE で分解
-- ============================================================

WITH labeled_orders AS (
  SELECT
    order_id,
    status,
    total_jpy,
    CASE
      WHEN status='paid'      AND total_jpy >= 30000 THEN 'A1: 高額成立'
      WHEN status='paid'      AND total_jpy >= 10000 THEN 'A2: 標準成立'
      WHEN status='paid'                             THEN 'A3: 少額成立'
      WHEN status='cancelled' AND total_jpy >= 30000 THEN 'B1: 高額逃した'
      WHEN status='pending'   AND total_jpy >= 30000 THEN 'C1: 高額保留'
      ELSE                                                'D: その他'
    END                                                    AS importance
  FROM orders
)
SELECT importance, COUNT(*), SUM(total_jpy) AS revenue
FROM labeled_orders
GROUP BY importance
ORDER BY importance;

-- ============================================================
-- 業務クエリ集
-- ============================================================

-- Q1: ユーザー別 paid 注文数 + カテゴリ別購入金額 (User 1)
WITH paid_orders_per_user AS (
  SELECT
    o.user_id,
    COUNT(*)         AS paid_cnt,
    SUM(o.total_jpy) AS total_paid_revenue
  FROM orders o
  WHERE o.status = 'paid'
  GROUP BY o.user_id
),
category_spend_per_user AS (
  SELECT
    o.user_id,
    c.name                                AS category_name,
    SUM(oi.quantity * oi.unit_price)      AS category_spend
  FROM orders o
  INNER JOIN order_items oi ON oi.order_id = o.order_id
  INNER JOIN products p     ON p.product_id = oi.product_id
  INNER JOIN categories c   ON c.category_id = p.category_id
  WHERE o.status = 'paid'
  GROUP BY o.user_id, c.name
)
SELECT
  u.full_name,
  p.paid_cnt,
  p.total_paid_revenue,
  cs.category_name,
  cs.category_spend
FROM users u
INNER JOIN paid_orders_per_user    p  ON p.user_id  = u.user_id
INNER JOIN category_spend_per_user cs ON cs.user_id = u.user_id
WHERE u.full_name = 'User 1'
ORDER BY cs.category_spend DESC;

-- Q2: 月次売上 + 前月比
WITH monthly_revenue AS (
  SELECT
    DATE_TRUNC('month', ordered_at)::date AS month,
    SUM(total_jpy)                        AS revenue
  FROM orders
  WHERE status = 'paid'
  GROUP BY 1
)
SELECT
  m.month,
  m.revenue,
  prev.revenue                            AS prev_revenue,
  m.revenue - prev.revenue                AS diff
FROM monthly_revenue m
LEFT JOIN monthly_revenue prev
  ON prev.month = (m.month - INTERVAL '1 month')::date
ORDER BY m.month
LIMIT 5;

-- Q3: 国別 top spender
WITH user_revenue AS (
  SELECT
    o.user_id,
    SUM(o.total_jpy) AS total_revenue
  FROM orders o
  WHERE o.status = 'paid'
  GROUP BY o.user_id
),
country_ranked AS (
  SELECT
    u.country,
    u.full_name,
    ur.total_revenue,
    ROW_NUMBER() OVER (
      PARTITION BY u.country
      ORDER BY ur.total_revenue DESC
    ) AS rk
  FROM users u
  INNER JOIN user_revenue ur ON ur.user_id = u.user_id
)
SELECT country, full_name, total_revenue
FROM country_ranked
WHERE rk = 1
ORDER BY total_revenue DESC;

-- Q4 (a): サブクエリ版 (第 8 章スタイル)
SELECT u.full_name
FROM users u
WHERE u.country = 'JP'
  AND u.user_id IN (
    SELECT s.user_id
    FROM subscriptions s
    WHERE s.ended_at IS NULL
  )
  AND EXISTS (
    SELECT 1 FROM orders o
    WHERE o.user_id = u.user_id AND o.status = 'paid'
  )
ORDER BY u.full_name
LIMIT 3;

-- Q4 (b): CTE 版 (第 11 章スタイル)
WITH active_sub_users AS (
  SELECT DISTINCT user_id FROM subscriptions WHERE ended_at IS NULL
),
paid_users AS (
  SELECT DISTINCT user_id FROM orders WHERE status = 'paid'
)
SELECT u.full_name
FROM users u
INNER JOIN active_sub_users asu ON asu.user_id = u.user_id
INNER JOIN paid_users        pu  ON pu.user_id  = u.user_id
WHERE u.country = 'JP'
ORDER BY u.full_name
LIMIT 3;

-- Q5: 商品別の購入回数とリピーター率
WITH product_user_orders AS (
  SELECT
    oi.product_id,
    o.user_id,
    COUNT(*) AS user_order_cnt
  FROM order_items oi
  INNER JOIN orders o ON o.order_id = oi.order_id
  WHERE o.status = 'paid'
  GROUP BY oi.product_id, o.user_id
),
product_summary AS (
  SELECT
    product_id,
    COUNT(*)                                              AS unique_buyers,
    COUNT(*) FILTER (WHERE user_order_cnt >= 2)           AS repeat_buyers
  FROM product_user_orders
  GROUP BY product_id
)
SELECT
  p.product_id,
  p.name,
  ps.unique_buyers,
  ps.repeat_buyers,
  ROUND(100.0 * ps.repeat_buyers / NULLIF(ps.unique_buyers, 0), 1)
                                                          AS repeat_pct
FROM product_summary ps
INNER JOIN products p ON p.product_id = ps.product_id
ORDER BY ps.unique_buyers DESC
LIMIT 5;
