-- ============================================================
-- 第10章: CASE 式 - 行を分岐させる
-- 実践 SQL ハンドブック サンプルクエリ集
-- 対応 RDBMS: PostgreSQL 18 / MySQL 8.4 LTS (注記済み)
-- ============================================================

\pset null '(NULL)'

-- ============================================================
-- 1. CASE 式の 2 つの形 - searched と simple
-- ============================================================

-- simple CASE: ステータスに日本語ラベル
SELECT
  order_id,
  status,
  CASE status
    WHEN 'paid'      THEN '支払い済み'
    WHEN 'cancelled' THEN 'キャンセル'
    WHEN 'pending'   THEN '保留中'
    ELSE '不明'
  END AS status_label
FROM orders
WHERE order_id IN (7, 8, 9, 10)
ORDER BY order_id;

-- searched CASE: 同じ意味
SELECT
  order_id,
  status,
  CASE
    WHEN status = 'paid'      THEN '支払い済み'
    WHEN status = 'cancelled' THEN 'キャンセル'
    WHEN status = 'pending'   THEN '保留中'
    ELSE '不明'
  END AS status_label
FROM orders
WHERE order_id IN (7, 8, 9, 10)
ORDER BY order_id;

-- ============================================================
-- 2. simple CASE では NULL を比較できない
-- ============================================================

-- NG 例: simple CASE で NULL を拾えない
SELECT
  subscription_id,
  ended_at,
  CASE ended_at
    WHEN NULL THEN '現役'
    ELSE      '終了'
  END AS sub_status
FROM subscriptions
WHERE subscription_id IN (1, 2, 3, 4)
ORDER BY subscription_id;

-- OK 例: searched CASE で IS NULL
SELECT
  subscription_id,
  ended_at,
  CASE
    WHEN ended_at IS NULL THEN '現役'
    ELSE                       '終了'
  END AS sub_status
FROM subscriptions
WHERE subscription_id IN (1, 2, 3, 4)
ORDER BY subscription_id;

-- ============================================================
-- 3. 評価順序と短絡評価 (ゼロ除算回避)
-- ============================================================

SELECT
  u.full_name,
  COUNT(*)         AS order_cnt,
  SUM(o.total_jpy) AS total_revenue,
  CASE
    WHEN COUNT(*) = 0 THEN 0
    ELSE SUM(o.total_jpy) / COUNT(*)
  END AS avg_revenue
FROM orders o
INNER JOIN users u ON u.user_id = o.user_id
WHERE u.full_name IN ('User 1', 'User 2', 'User 3')
GROUP BY u.full_name
ORDER BY u.full_name;

-- ============================================================
-- 4. ELSE 省略 -> NULL -> COUNT で自動除外
-- ============================================================

SELECT
  COUNT(*)                                              AS total_orders,
  COUNT(CASE WHEN status = 'paid' THEN 1 END)           AS paid_orders,
  COUNT(CASE WHEN status = 'cancelled' THEN 1 END)      AS cancelled_orders
FROM orders;

-- ============================================================
-- 5. 型統合の罠
-- ============================================================

-- NG: integer と text の混在は PG ではエラー
-- SELECT
--   CASE WHEN 1 = 1 THEN 100 ELSE 'unknown' END AS mixed_type;

-- OK: 明示 CAST で型を揃える
SELECT
  CASE WHEN 1 = 1 THEN '100'::text ELSE 'unknown' END AS safe_type;

-- ============================================================
-- 6. SUM(CASE WHEN ...) でピボット表
-- ============================================================

-- ピボット: ステータス x 金額帯
SELECT
  CASE
    WHEN total_jpy < 5000  THEN 'small'
    WHEN total_jpy < 30000 THEN 'large'
    ELSE                        'xlarge'
  END                                                          AS amount_bucket,
  COUNT(CASE WHEN status = 'paid' THEN 1 END)                  AS paid_cnt,
  COUNT(CASE WHEN status = 'cancelled' THEN 1 END)             AS cancelled_cnt,
  COUNT(CASE WHEN status = 'pending' THEN 1 END)               AS pending_cnt,
  SUM(CASE WHEN status = 'paid' THEN total_jpy ELSE 0 END)     AS paid_total
FROM orders
GROUP BY 1
ORDER BY 1;

-- FILTER 句 (PG のみ) で同じ結果
SELECT
  CASE
    WHEN total_jpy < 5000  THEN 'small'
    WHEN total_jpy < 30000 THEN 'large'
    ELSE                        'xlarge'
  END                                                  AS amount_bucket,
  COUNT(*) FILTER (WHERE status = 'paid')              AS paid_cnt,
  COUNT(*) FILTER (WHERE status = 'cancelled')         AS cancelled_cnt,
  COUNT(*) FILTER (WHERE status = 'pending')           AS pending_cnt,
  SUM(total_jpy) FILTER (WHERE status = 'paid')        AS paid_total
FROM orders
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- 7. ORDER BY 内に CASE - カスタム並び
-- ============================================================

SELECT s.plan, SUM(s.monthly_jpy) AS mrr
FROM subscriptions s
WHERE s.ended_at IS NULL
GROUP BY s.plan
ORDER BY
  CASE s.plan
    WHEN 'enterprise' THEN 0
    WHEN 'pro'        THEN 1
    ELSE                   2
  END;

-- ============================================================
-- 8. GROUP BY 内の CASE - 動的バケット
-- ============================================================

SELECT
  CASE
    WHEN p.price_jpy <  1000 THEN '0-999'
    WHEN p.price_jpy <  3000 THEN '1000-2999'
    ELSE                          '3000+'
  END                                                AS price_bucket,
  COUNT(*)                                           AS item_lines,
  SUM(oi.quantity * oi.unit_price)                   AS bucket_revenue
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- 9. CASE は WHERE にも置ける
-- ============================================================

SELECT order_id, status, total_jpy
FROM orders
WHERE
  CASE status
    WHEN 'paid' THEN total_jpy >= 1500
    ELSE             total_jpy >= 1000
  END
  AND order_id <= 20
ORDER BY order_id;

-- ============================================================
-- 10. COALESCE は CASE の特殊形
-- ============================================================

SELECT
  subscription_id,
  CASE
    WHEN ended_at IS NULL THEN TIMESTAMPTZ '2026-05-19 00:00:00+00'
    ELSE                       ended_at
  END                                                AS effective_end_case,
  COALESCE(ended_at, TIMESTAMPTZ '2026-05-19 00:00:00+00')
                                                     AS effective_end_coalesce
FROM subscriptions
WHERE subscription_id IN (1, 2, 4)
ORDER BY subscription_id;

-- ============================================================
-- 11. NULLIF でゼロ除算回避
-- ============================================================

SELECT
  u.full_name,
  COUNT(*)                                          AS order_cnt,
  SUM(o.total_jpy)                                  AS total_revenue,
  SUM(o.total_jpy) / NULLIF(COUNT(*), 0)            AS avg_revenue
FROM orders o
INNER JOIN users u ON u.user_id = o.user_id
WHERE u.full_name IN ('User 1', 'User 2', 'User 3')
GROUP BY u.full_name
ORDER BY u.full_name;

-- ============================================================
-- 12. PG GREATEST / LEAST の NULL 扱い
-- ============================================================

SELECT
  GREATEST(10, NULL, 20)  AS pg_greatest,
  LEAST(10, NULL, 20)     AS pg_least;

-- 移植性のある書き方
SELECT
  GREATEST(
    COALESCE(10, 0),
    COALESCE(NULL, 0),
    COALESCE(20, 0)
  ) AS safe_greatest;

-- ============================================================
-- 13. アンチパターン: Boolean を CASE で包む
-- ============================================================

-- NG (CASE で TRUE/FALSE を返す)
SELECT
  order_id,
  total_jpy,
  CASE WHEN total_jpy > 30000 THEN TRUE ELSE FALSE END AS is_large_order
FROM orders
WHERE order_id IN (1, 416, 500)
ORDER BY order_id;

-- OK (Boolean 式自体が値)
SELECT
  order_id,
  total_jpy,
  (total_jpy > 30000) AS is_large_order
FROM orders
WHERE order_id IN (1, 416, 500)
ORDER BY order_id;

-- ============================================================
-- 14. 複雑な分岐: 重要度ラベル (フラット WHEN)
-- ============================================================

SELECT
  order_id,
  status,
  total_jpy,
  CASE
    WHEN status = 'paid'      AND total_jpy >= 30000 THEN 'A1: 高額成立'
    WHEN status = 'paid'      AND total_jpy >= 10000 THEN 'A2: 標準成立'
    WHEN status = 'paid'                             THEN 'A3: 少額成立'
    WHEN status = 'cancelled' AND total_jpy >= 30000 THEN 'B1: 高額逃した'
    WHEN status = 'pending'   AND total_jpy >= 30000 THEN 'C1: 高額保留'
    ELSE                                                  'D: その他'
  END AS importance
FROM orders
WHERE order_id IN (1, 8, 134, 416, 418, 419)
ORDER BY order_id;

-- ============================================================
-- 業務クエリ集
-- ============================================================

-- Q1: 金額帯バケット集計 (4 段階)
SELECT
  CASE
    WHEN total_jpy <  5000 THEN 'small (<5000)'
    WHEN total_jpy < 10000 THEN 'medium (5000-9999)'
    WHEN total_jpy < 30000 THEN 'large (10000-29999)'
    ELSE                        'xlarge (>=30000)'
  END                                                          AS amount_bucket,
  COUNT(*)                                                     AS order_cnt,
  SUM(total_jpy)                                               AS total_revenue
FROM orders
GROUP BY 1
ORDER BY MIN(total_jpy);

-- Q2: ステータス x 金額帯ピボット (FILTER 句、PG のみ)
SELECT
  CASE
    WHEN total_jpy < 5000  THEN 'small'
    WHEN total_jpy < 30000 THEN 'large'
    ELSE                        'xlarge'
  END                                                          AS amount_bucket,
  COUNT(*) FILTER (WHERE status = 'paid')                      AS paid_cnt,
  COUNT(*) FILTER (WHERE status = 'cancelled')                 AS cancelled_cnt,
  COUNT(*) FILTER (WHERE status = 'pending')                   AS pending_cnt,
  SUM(total_jpy) FILTER (WHERE status = 'paid')                AS paid_revenue
FROM orders
GROUP BY 1
ORDER BY 1;

-- Q3: プラン別 MRR をビジネス序列で並べる
SELECT
  s.plan,
  SUM(s.monthly_jpy)                                           AS mrr,
  COUNT(*)                                                     AS active_subs
FROM subscriptions s
WHERE s.ended_at IS NULL
GROUP BY s.plan
ORDER BY
  CASE s.plan
    WHEN 'enterprise' THEN 0
    WHEN 'pro'        THEN 1
    ELSE                   2
  END;

-- Q4: 単価バケット別の売上構成比
SELECT
  CASE
    WHEN p.price_jpy <  1000 THEN '0-999'
    WHEN p.price_jpy <  3000 THEN '1000-2999'
    ELSE                          '3000+'
  END                                                AS price_bucket,
  COUNT(*)                                           AS item_lines,
  SUM(oi.quantity * oi.unit_price)                   AS bucket_revenue,
  ROUND(
    100.0 * SUM(oi.quantity * oi.unit_price)
    / NULLIF(SUM(SUM(oi.quantity * oi.unit_price)) OVER (), 0),
    1
  )                                                  AS pct
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY 1
ORDER BY 1;

-- Q5: カテゴリ階層判定
SELECT
  CASE
    WHEN c.parent_id IS NULL THEN 'level 1 (root)'
    ELSE                          'level 2+ (child)'
  END                                                          AS depth,
  COUNT(*)                                                     AS category_cnt,
  STRING_AGG(c.name, ', ' ORDER BY c.sort_order)               AS sample_names
FROM categories c
GROUP BY 1
ORDER BY 1;
