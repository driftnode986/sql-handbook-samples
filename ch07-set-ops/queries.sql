-- ch07-set-ops/queries.sql
-- 書籍『実践 SQL ハンドブック』第 7 章 (UNION・INTERSECT・EXCEPT)
--
-- 実行: psql -h localhost -p 5418 -U app -d handbook -f ch07-set-ops/queries.sql

\pset null '(NULL)'
\pset border 1

-- ============================================================
-- 第 7 章 本文クエリ
-- ============================================================

-- 節 1: UNION (DISTINCT) で重複除去
SELECT status FROM orders WHERE order_id <= 5
UNION
SELECT status FROM orders WHERE order_id BETWEEN 6 AND 10
ORDER BY status;

-- 節 1: UNION ALL で重複保持
SELECT status FROM orders WHERE order_id <= 5
UNION ALL
SELECT status FROM orders WHERE order_id BETWEEN 6 AND 10
ORDER BY status;

-- 節 2: INTERSECT (2024 ∩ 2025 paid)
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2024-01-01'
  AND ordered_at <  DATE '2025-01-01'
INTERSECT
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2025-01-01'
  AND ordered_at <  DATE '2026-01-01';

-- 節 3: EXCEPT (2024 - 2025 = 離脱)
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2024-01-01'
  AND ordered_at <  DATE '2025-01-01'
EXCEPT
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2025-01-01'
  AND ordered_at <  DATE '2026-01-01';

-- 節 3: EXCEPT を逆方向 (2025 新規)
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2025-01-01'
  AND ordered_at <  DATE '2026-01-01'
EXCEPT
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2024-01-01'
  AND ordered_at <  DATE '2025-01-01';

-- 節 5.1: 集合演算全体に ORDER BY/LIMIT
SELECT user_id, full_name FROM users WHERE country = 'JP'
UNION
SELECT user_id, full_name FROM users WHERE country = 'US'
ORDER BY full_name
LIMIT 10;

-- 節 5.2: 内側 SELECT に ORDER BY/LIMIT (括弧必須)
(
  SELECT p.name, p.price_jpy, 'Books' AS category
  FROM products p
  JOIN categories c ON p.category_id = c.category_id
  WHERE c.name = 'Books'
  ORDER BY p.price_jpy DESC
  LIMIT 3
)
UNION ALL
(
  SELECT p.name, p.price_jpy, 'Knives' AS category
  FROM products p
  JOIN categories c ON p.category_id = c.category_id
  WHERE c.name = 'Knives'
  ORDER BY p.price_jpy DESC
  LIMIT 3
)
ORDER BY category, price_jpy DESC;

-- ============================================================
-- 業務クエリ集 (5 本)
-- ============================================================

-- BQ #1: 各テーブルの行数を縦に並べる (UNION ALL)
SELECT 'event'        AS source, COUNT(*) AS row_count FROM events
UNION ALL
SELECT 'order'        AS source, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'subscription' AS source, COUNT(*) AS row_count FROM subscriptions
ORDER BY source;

-- BQ #2: 2024 ∩ 2025 paid ユーザー (定着顧客)
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2024-01-01'
  AND ordered_at <  DATE '2025-01-01'
INTERSECT
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2025-01-01'
  AND ordered_at <  DATE '2026-01-01';

-- BQ #3: 2024 - 2025 paid (離脱ユーザー)
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2024-01-01'
  AND ordered_at <  DATE '2025-01-01'
EXCEPT
SELECT user_id
FROM orders
WHERE status = 'paid'
  AND ordered_at >= DATE '2025-01-01'
  AND ordered_at <  DATE '2026-01-01';

-- BQ #4: 未契約者 (全ユーザー - 契約者)
SELECT user_id FROM users
EXCEPT
SELECT user_id FROM subscriptions;

-- BQ #5: Books トップ 3 + Knives トップ 3 を縦結合
(
  SELECT p.name, p.price_jpy, 'Books' AS category
  FROM products p
  JOIN categories c ON p.category_id = c.category_id
  WHERE c.name = 'Books'
  ORDER BY p.price_jpy DESC
  LIMIT 3
)
UNION ALL
(
  SELECT p.name, p.price_jpy, 'Knives' AS category
  FROM products p
  JOIN categories c ON p.category_id = c.category_id
  WHERE c.name = 'Knives'
  ORDER BY p.price_jpy DESC
  LIMIT 3
)
ORDER BY category, price_jpy DESC;
