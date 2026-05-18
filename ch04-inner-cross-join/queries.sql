-- 第4章 INNER JOIN・CROSS JOIN
-- サンプルリポジトリ: driftnode986/sql-handbook-samples
-- 実行: psql -h localhost -p 5418 -U app -d handbook -f ch04-inner-cross-join/queries.sql
\pset null '(NULL)'

-- ============================================================
-- 章本文の SQL 例
-- ============================================================

-- 1. INNER JOIN ON の基本
-- ユーザーと注文を結合し、注文順に並べる
SELECT
  u.full_name,
  o.order_id,
  o.ordered_at::date AS ordered_date,
  o.total_jpy
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id
ORDER BY o.ordered_at, o.order_id
LIMIT 5;

-- 2. INNER JOIN を WHERE で書いた場合 (歴史的記法)
-- 同じ結果を「カンマ + WHERE で結合条件」で書く例
SELECT
  u.full_name,
  o.order_id,
  o.ordered_at::date AS ordered_date,
  o.total_jpy
FROM users u, orders o
WHERE u.user_id = o.user_id
ORDER BY o.ordered_at, o.order_id
LIMIT 5;

-- 3. INNER JOIN は両側にマッチがある行だけが残ることを示す
-- users 1,000 行、orders 5,000 行に対して、注文 1 件以上のユーザー数を確認
SELECT COUNT(DISTINCT u.user_id) AS users_with_orders
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id;

-- 4. 多対多結合の重複問題 (Ch04 最重要トピック)
-- ユーザー数を直接 COUNT すると、order_items の件数だけ膨らむ
SELECT COUNT(*) AS row_count_naive
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- 5. 多対多結合の正解パターン
-- 「ユーザーごとの購入金額合計」は order_items の重複を意識して書く
SELECT
  u.full_name,
  SUM(oi.quantity * oi.unit_price) AS total_amount
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status = 'paid'
GROUP BY u.user_id, u.full_name
ORDER BY total_amount DESC
LIMIT 5;

-- 6. USING 句 — 同名列をマージする
-- order_items と products は product_id が同名なので USING で書ける
SELECT
  oi.order_id,
  product_id,
  p.name AS product_name,
  oi.quantity,
  oi.unit_price
FROM order_items oi
INNER JOIN products p USING (product_id)
WHERE oi.order_id = 1
ORDER BY product_id;

-- 7. CROSS JOIN — products と users の組み合わせ件数を確認
-- 200 商品 x 1,000 ユーザー = 200,000 行
SELECT COUNT(*) AS combo_count
FROM products
CROSS JOIN users;

-- 8. CROSS JOIN の実用例 — 日付軸 x 商品マスタ
-- 1 週間分の日付 x 200 商品 = 1,400 行を生成
SELECT
  d.day::date AS day,
  p.product_id,
  p.name
FROM generate_series(DATE '2025-12-01', DATE '2025-12-07', INTERVAL '1 day') AS d(day)
CROSS JOIN products p
WHERE p.product_id <= 3
ORDER BY day, p.product_id
LIMIT 10;

-- 9. 自己結合 — 従業員と上司を並べる
-- employees を 2 回 INNER JOIN し、左を社員、右を上司として扱う
SELECT
  e.employee_id,
  e.name AS employee_name,
  e.title AS employee_title,
  m.name AS manager_name
FROM employees e
INNER JOIN employees m ON e.manager_id = m.employee_id
ORDER BY e.employee_id
LIMIT 5;

-- 10. 自己結合 — categories の親カテゴリ名を取り出す
SELECT
  c.category_id,
  c.name AS category_name,
  p.name AS parent_name
FROM categories c
INNER JOIN categories p ON c.parent_id = p.category_id
ORDER BY c.category_id
LIMIT 5;

-- 11. LATERAL — ユーザーごとに最新 1 件の注文を取り出す (Ch13 Top N per group の前振り)
SELECT
  u.full_name,
  latest.order_id,
  latest.ordered_at::date AS ordered_date
FROM users u
INNER JOIN LATERAL (
  SELECT order_id, ordered_at
  FROM orders o
  WHERE o.user_id = u.user_id
  ORDER BY ordered_at DESC
  LIMIT 1
) latest ON TRUE
ORDER BY u.full_name
LIMIT 3;

-- 12. ON 句に複合条件を書く例
-- ユーザーと注文を結合するが、paid 注文のみマッチさせる
-- (WHERE で絞っても結果は同じだが、ON 句に書くと「結合条件」と「フィルタ条件」の意図が分かれる)
SELECT
  u.full_name,
  o.order_id,
  o.status,
  o.total_jpy
FROM users u
INNER JOIN orders o
  ON u.user_id = o.user_id
  AND o.status = 'paid'
ORDER BY o.order_id
LIMIT 5;

-- ============================================================
-- この章の業務クエリ集
-- ============================================================

-- クエリ1: ユーザー x キャンセル注文一覧
-- 「キャンセルされた注文を顧客名つきで一覧したい」
SELECT
  u.full_name,
  o.order_id,
  o.ordered_at::date AS ordered_date,
  o.total_jpy
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id
WHERE o.status = 'cancelled'
ORDER BY o.ordered_at, o.order_id
LIMIT 5;

-- クエリ2: 注文 x 注文明細 x 商品 (3 テーブル連続結合)
-- 「特定注文の商品名・数量・小計を見たい」
SELECT
  o.order_id,
  o.ordered_at::date AS ordered_date,
  p.name AS product_name,
  oi.quantity,
  oi.unit_price,
  oi.quantity * oi.unit_price AS subtotal
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE o.order_id = 100
ORDER BY oi.product_id;

-- クエリ3: 日付軸 x 売上集計 (CROSS JOIN + 後段で集計)
-- 「7 日分の日付ごとに売上を出したい。売上ゼロの日も日付が出るのが理想」
-- ここでは INNER JOIN で書き、ゼロ売上日は結果に出ない (Ch05 で OUTER に切り替える伏線)
SELECT
  d.day::date AS day,
  COUNT(o.order_id) AS order_count,
  COALESCE(SUM(o.total_jpy), 0) AS revenue
FROM generate_series(DATE '2025-12-01', DATE '2025-12-07', INTERVAL '1 day') AS d(day)
INNER JOIN orders o ON o.ordered_at::date = d.day
WHERE o.status = 'paid'
GROUP BY d.day
ORDER BY d.day;

-- クエリ4: 自己結合で「上司の上司」を取る
-- 「社員 - 直属上司 - 部門長 (上司の上司) を 1 行で出したい」
SELECT
  e.name AS employee_name,
  m.name AS manager_name,
  mm.name AS manager_of_manager
FROM employees e
INNER JOIN employees m ON e.manager_id = m.employee_id
INNER JOIN employees mm ON m.manager_id = mm.employee_id
ORDER BY e.employee_id
LIMIT 5;

-- クエリ5: 商品 x カテゴリ x 親カテゴリ
-- 「商品名・サブカテゴリ名・大カテゴリ名を 1 行で並べたい」
SELECT
  p.name AS product_name,
  c.name AS category_name,
  pc.name AS parent_category_name
FROM products p
INNER JOIN categories c ON p.category_id = c.category_id
INNER JOIN categories pc ON c.parent_id = pc.category_id
ORDER BY p.product_id
LIMIT 5;
