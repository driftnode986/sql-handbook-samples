-- 第8章: サブクエリと相関サブクエリ
-- PostgreSQL 18 / MySQL 8.4 LTS で動作確認 (MySQL 8.4 では行サブクエリの ANY/ALL は非対応)

-- ============================================================
-- 節 2. スカラサブクエリ
-- ============================================================

-- 2.1 平均だけを単独で取得
SELECT AVG(total_jpy)::NUMERIC(10, 2) AS avg_paid
FROM orders
WHERE status = 'paid';

-- 2.2 スカラサブクエリで「平均より高い paid 注文」の件数
SELECT COUNT(*) AS above_avg_count
FROM orders
WHERE status = 'paid'
  AND total_jpy > (SELECT AVG(total_jpy) FROM orders WHERE status = 'paid');

-- 2.3 0 行を返すスカラサブクエリは NULL に化ける
SELECT (SELECT AVG(total_jpy) FROM orders WHERE status = 'refunded')
  AS refunded_avg;

-- 2.4 SELECT リスト内スカラ相関サブクエリ: 最終 paid 日
SELECT u.full_name,
  (SELECT MAX(o.ordered_at)::DATE
   FROM orders o
   WHERE o.user_id = u.user_id
     AND o.status  = 'paid') AS last_paid_date
FROM users u
ORDER BY u.user_id
LIMIT 3;

-- ============================================================
-- 節 3. 派生テーブル
-- ============================================================

-- 3.1 カテゴリ別 paid 売上 TOP 5 (派生テーブル経由)
SELECT c.name AS category, t.revenue
FROM (
  SELECT p.category_id, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM order_items oi
  JOIN products p ON p.product_id = oi.product_id
  JOIN orders o   ON o.order_id   = oi.order_id
                  AND o.status     = 'paid'
  GROUP BY p.category_id
) AS t
JOIN categories c ON c.category_id = t.category_id
ORDER BY t.revenue DESC
LIMIT 5;

-- 3.2 LATERAL: ユーザーごとに最終 paid 注文 1 行
SELECT u.full_name, t.last_amount, t.last_date
FROM users u,
LATERAL (
  SELECT o.total_jpy AS last_amount, o.ordered_at::DATE AS last_date
  FROM orders o
  WHERE o.user_id = u.user_id
    AND o.status  = 'paid'
  ORDER BY o.ordered_at DESC
  LIMIT 1
) AS t
ORDER BY u.user_id
LIMIT 3;

-- ============================================================
-- 節 4. IN / NOT IN と NULL 罠
-- ============================================================

-- 4.1 IN: subscriptions に登録があるユーザー数
SELECT COUNT(*) AS in_subs
FROM users u
WHERE u.user_id IN (SELECT s.user_id FROM subscriptions s);

-- 4.2 = ANY: IN と等価
SELECT COUNT(*) AS in_subs_any
FROM users u
WHERE u.user_id = ANY (SELECT s.user_id FROM subscriptions s);

-- 4.3 NOT IN の NULL 罠
SELECT 5 NOT IN (1, 2, NULL) AS not_in_result,
       5 IN     (1, 2, NULL) AS in_result;

-- 4.4 NOT IN を安全に書く: subscriptions.user_id は NOT NULL なので NULL 罠なし
SELECT COUNT(*) AS no_active_via_not_in
FROM users u
WHERE u.user_id NOT IN (
  SELECT s.user_id FROM subscriptions s WHERE s.ended_at IS NULL
);

-- 4.5 NOT IN の 3 方法: A (IS NOT NULL 明示)
SELECT COUNT(*) AS method_a
FROM users u
WHERE u.user_id NOT IN (
  SELECT s.user_id FROM subscriptions s
  WHERE s.ended_at IS NULL
    AND s.user_id  IS NOT NULL
);

-- 4.6 NOT IN の 3 方法: B (EXCEPT)
SELECT COUNT(*) AS method_b FROM (
  SELECT user_id FROM users
  EXCEPT
  SELECT user_id FROM subscriptions WHERE ended_at IS NULL
) AS t;

-- 4.7 NOT IN の 3 方法: C (NOT EXISTS)
SELECT COUNT(*) AS method_c
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
);

-- ============================================================
-- 節 5. ANY と ALL
-- ============================================================

-- 5.1 カテゴリ別平均価格
SELECT category_id, AVG(price_jpy)::NUMERIC(10, 0) AS avg_p
FROM products
GROUP BY category_id
ORDER BY category_id
LIMIT 5;

-- 5.2 ANY: どれかのカテゴリ平均より高い商品
SELECT COUNT(*) AS gt_any_cat_avg
FROM products
WHERE price_jpy > ANY (
  SELECT AVG(price_jpy) FROM products GROUP BY category_id
);

-- 5.3 ALL: すべてのカテゴリ平均より高い商品
SELECT COUNT(*) AS gt_all_cat_avg
FROM products
WHERE price_jpy > ALL (
  SELECT AVG(price_jpy) FROM products GROUP BY category_id
);

-- 5.4 ALL は空集合に対して TRUE
SELECT 5 > ALL (SELECT 1 WHERE FALSE) AS result;

-- ============================================================
-- 節 6. 行サブクエリ
-- ============================================================

-- 6.1 (user_id, status) = (SELECT ... LIMIT 1 PK 絞り)
SELECT order_id, ordered_at::DATE, total_jpy
FROM orders
WHERE (user_id, status) = (
  SELECT user_id, status FROM orders WHERE order_id = 2
)
ORDER BY ordered_at;

-- 6.2 行 IN: (user_id, status) IN (集合)
SELECT order_id, status
FROM orders
WHERE (user_id, status) IN (
  SELECT user_id, status FROM orders WHERE order_id IN (2, 3)
)
ORDER BY order_id
LIMIT 5;

-- ============================================================
-- 業務クエリ集 (5 本)
-- ============================================================

-- クエリ 1: 平均より高い paid 注文 TOP 5
SELECT order_id, total_jpy
FROM orders
WHERE status = 'paid'
  AND total_jpy > (SELECT AVG(total_jpy) FROM orders WHERE status = 'paid')
ORDER BY total_jpy DESC
LIMIT 5;

-- クエリ 2: 各ユーザーの最終 paid 日 + 額 (スカラ相関 2 本)
SELECT u.full_name, u.country,
  (SELECT MAX(o.ordered_at)::DATE
   FROM orders o
   WHERE o.user_id = u.user_id
     AND o.status  = 'paid') AS last_paid_date,
  (SELECT o.total_jpy
   FROM orders o
   WHERE o.user_id = u.user_id
     AND o.status  = 'paid'
   ORDER BY o.ordered_at DESC
   LIMIT 1) AS last_paid_amount
FROM users u
ORDER BY u.user_id
LIMIT 5;

-- クエリ 3: 全カテゴリ平均より高い商品 (> ALL)
SELECT product_id, name, price_jpy
FROM products
WHERE price_jpy > ALL (
  SELECT AVG(price_jpy) FROM products GROUP BY category_id
)
ORDER BY price_jpy DESC
LIMIT 5;

-- クエリ 4: 現役 subscription なしを 3 通り
SELECT COUNT(*) AS method_a
FROM users u
WHERE u.user_id NOT IN (
  SELECT s.user_id FROM subscriptions s
  WHERE s.ended_at IS NULL
    AND s.user_id  IS NOT NULL
);

SELECT COUNT(*) AS method_b FROM (
  SELECT user_id FROM users
  EXCEPT
  SELECT user_id FROM subscriptions WHERE ended_at IS NULL
) AS t;

SELECT COUNT(*) AS method_c
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM subscriptions s
  WHERE s.user_id = u.user_id
    AND s.ended_at IS NULL
);

-- クエリ 5: 派生テーブルで各カテゴリの最高額商品 TOP 5
SELECT c.name AS category, p.name AS product, p.price_jpy
FROM categories c
JOIN products p ON p.category_id = c.category_id
JOIN (
  SELECT category_id, MAX(price_jpy) AS max_price
  FROM products
  GROUP BY category_id
) AS t ON t.category_id = p.category_id AND t.max_price = p.price_jpy
ORDER BY p.price_jpy DESC
LIMIT 5;
