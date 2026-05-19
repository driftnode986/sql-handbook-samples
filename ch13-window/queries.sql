-- 第 13 章: ウィンドウ関数 - 集計の革命
-- 業務クエリ集 (6 本)
-- 本書 chapters/13_window.md と byte-for-byte 一致

-- ============================================
-- Q1. カテゴリ別売上 Top 3 商品
-- ============================================

SELECT category_id, product_id, sold_units, revenue_jpy
FROM (
  SELECT
    p.category_id,
    p.product_id,
    SUM(oi.quantity)                     AS sold_units,
    SUM(oi.quantity * oi.unit_price)     AS revenue_jpy,
    ROW_NUMBER() OVER (
      PARTITION BY p.category_id
      ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    )                                    AS rn
  FROM products p
  INNER JOIN order_items oi ON oi.product_id = p.product_id
  INNER JOIN orders o ON o.order_id = oi.order_id AND o.status = 'paid'
  GROUP BY p.category_id, p.product_id
) sub
WHERE rn <= 3
ORDER BY category_id, rn;

-- ============================================
-- Q2. ユーザーの月次売上と前月差分・前月比
-- ============================================

WITH monthly AS (
  SELECT
    u.full_name,
    DATE_TRUNC('month', o.ordered_at)::date AS month,
    SUM(o.total_jpy)                        AS revenue
  FROM orders o
  INNER JOIN users u ON u.user_id = o.user_id
  WHERE o.status = 'paid' AND u.full_name = 'User 1'
  GROUP BY u.full_name, DATE_TRUNC('month', o.ordered_at)
)
SELECT
  full_name,
  month,
  revenue,
  LAG(revenue) OVER w                          AS prev_revenue,
  revenue - LAG(revenue) OVER w                AS diff,
  ROUND(100.0 * (revenue - LAG(revenue) OVER w)
        / NULLIF(LAG(revenue) OVER w, 0), 1)   AS pct_change
FROM monthly
WINDOW w AS (PARTITION BY full_name ORDER BY month)
ORDER BY month;

-- ============================================
-- Q3. 7 日移動平均の売上推移
-- ============================================

SELECT
  ordered_at::date          AS day,
  SUM(total_jpy)            AS daily_total,
  ROUND(AVG(SUM(total_jpy)) OVER (
    ORDER BY ordered_at::date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ))                        AS ma_7d
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2025-12-01'
  AND ordered_at <  DATE '2025-12-16'
GROUP BY ordered_at::date
ORDER BY day;

-- ============================================
-- Q4. ユーザーごとの累計購入額と累計購入回数
-- ============================================

SELECT
  u.full_name,
  o.ordered_at::date AS day,
  o.total_jpy,
  COUNT(*)        OVER w AS running_cnt,
  SUM(o.total_jpy)  OVER w AS running_total,
  ROUND(AVG(o.total_jpy) OVER w) AS running_avg
FROM orders o
INNER JOIN users u ON u.user_id = o.user_id
WHERE o.status = 'paid' AND u.full_name IN ('User 1', 'User 337')
WINDOW w AS (PARTITION BY u.full_name ORDER BY o.ordered_at)
ORDER BY u.full_name, o.ordered_at;

-- ============================================
-- Q5. 国別・プラン別ユーザーランキング (RANK と DENSE_RANK)
-- ============================================

SELECT country, plan, full_name, started, rk, drk
FROM (
  SELECT
    u.country,
    s.plan,
    u.full_name,
    s.started_at::date AS started,
    RANK()       OVER w AS rk,
    DENSE_RANK() OVER w AS drk
  FROM subscriptions s
  INNER JOIN users u ON u.user_id = s.user_id
  WHERE s.ended_at IS NULL AND u.country IN ('JP', 'US')
  WINDOW w AS (PARTITION BY u.country, s.plan ORDER BY s.started_at)
) sub
WHERE rk <= 3
ORDER BY country, plan, rk;

-- ============================================
-- Q6. 商品ごとの最初の注文日と最終注文日 (LAST_VALUE 罠回避)
-- ============================================

SELECT DISTINCT
  product_id,
  FIRST_VALUE(ordered_at::date) OVER w AS first_order,
  LAST_VALUE(ordered_at::date)  OVER w AS last_order,
  FIRST_VALUE(unit_price)       OVER w AS first_price,
  LAST_VALUE(unit_price)        OVER w AS last_price
FROM order_items oi
INNER JOIN orders o ON o.order_id = oi.order_id AND o.status = 'paid'
WHERE product_id IN (1, 50, 100)
WINDOW w AS (
  PARTITION BY product_id ORDER BY ordered_at
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
ORDER BY product_id;
