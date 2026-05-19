-- 第 12 章: 再帰 CTE - 階層と経路を扱う
-- 業務クエリ集 (5 本)
-- 本書 chapters/12_recursive_cte.md と byte-for-byte 一致

-- ============================================
-- Q1. 全カテゴリの階層パス一覧
-- シナリオ: EC サイトのカテゴリ一覧画面で、ユーザーに
-- 「Electronics > Computers > Laptops > Gaming Laptops」のような
-- 階層パスを表示したい。
-- ============================================

WITH RECURSIVE category_path(category_id, name, depth, path) AS (
  SELECT category_id, name, 0 AS depth, name::text AS path
  FROM categories
  WHERE parent_id IS NULL
  UNION ALL
  SELECT
    c.category_id,
    c.name,
    cp.depth + 1,
    cp.path || ' > ' || c.name
  FROM categories c
  INNER JOIN category_path cp ON c.parent_id = cp.category_id
)
SELECT depth, category_id, path FROM category_path ORDER BY path;

-- ============================================
-- Q2. 特定マネージャーの配下メンバー全展開
-- シナリオ: 人事システムで「Director の Employee 2 配下に
-- 何人いて、それぞれ何階層下か」を確認したい。
-- ============================================

WITH RECURSIVE org(employee_id, name, title, manager_id, depth) AS (
  SELECT employee_id, name, title, manager_id, 0 AS depth
  FROM employees
  WHERE employee_id = 2
  UNION ALL
  SELECT
    e.employee_id, e.name, e.title, e.manager_id, o.depth + 1
  FROM employees e
  INNER JOIN org o ON e.manager_id = o.employee_id
)
SELECT depth, COUNT(*) AS member_cnt, STRING_AGG(name, ', ' ORDER BY employee_id) AS members
FROM org
GROUP BY depth
ORDER BY depth;

-- ============================================
-- Q3. コメントスレッドの全子孫取得
-- シナリオ: Web フォーラムで、特定ルートコメント (root の comment_id) の
-- スレッド全体を取得して画面に表示したい。
-- ============================================

WITH RECURSIVE thread(comment_id, parent_id, body, depth, root_id, sort_path) AS (
  SELECT
    comment_id,
    parent_id,
    body,
    0 AS depth,
    comment_id AS root_id,
    LPAD(comment_id::text, 8, '0') AS sort_path
  FROM comments
  WHERE comment_id = 1
  UNION ALL
  SELECT
    c.comment_id,
    c.parent_id,
    c.body,
    t.depth + 1,
    t.root_id,
    t.sort_path || '/' || LPAD(c.comment_id::text, 8, '0')
  FROM comments c
  INNER JOIN thread t ON c.parent_id = t.comment_id
)
SELECT depth, comment_id, LEFT(body, 40) AS body_excerpt FROM thread ORDER BY sort_path;

-- ============================================
-- Q4. カテゴリ配下の総注文数集計
-- シナリオ: EC サイトの分析で「Electronics 配下 (Computers / Phones / Wearables まで含む) で
-- paid 注文された商品の総数 / 売上を出したい」。
-- ============================================

WITH RECURSIVE category_tree(root_id, descendant_id, root_name) AS (
  SELECT category_id, category_id, name
  FROM categories
  WHERE parent_id IS NULL
  UNION ALL
  SELECT ct.root_id, c.category_id, ct.root_name
  FROM categories c
  INNER JOIN category_tree ct ON c.parent_id = ct.descendant_id
)
SELECT
  ct.root_name                         AS category,
  COUNT(DISTINCT p.product_id)         AS distinct_products,
  COUNT(*)                             AS sold_units,
  SUM(oi.quantity * oi.unit_price)     AS revenue_jpy
FROM category_tree ct
LEFT JOIN products p ON p.category_id = ct.descendant_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
LEFT JOIN orders o ON o.order_id = oi.order_id AND o.status = 'paid'
WHERE o.order_id IS NOT NULL
GROUP BY ct.root_id, ct.root_name
ORDER BY revenue_jpy DESC;

-- ============================================
-- Q5. 日付シリーズ + 売上集計 (欠損埋め)
-- シナリオ: ダッシュボードで「2025-12-01 から 2025-12-15 の各日の売上を表示。
-- 注文ゼロの日も '0' で表示したい」。
-- ============================================

WITH RECURSIVE date_range(d) AS (
  SELECT DATE '2025-12-01'
  UNION ALL
  SELECT (d + INTERVAL '1 day')::date FROM date_range WHERE d < DATE '2025-12-15'
)
SELECT
  dr.d                          AS sale_date,
  COUNT(o.order_id)             AS order_cnt,
  COALESCE(SUM(o.total_jpy), 0) AS revenue_jpy
FROM date_range dr
LEFT JOIN orders o
  ON DATE(o.ordered_at) = dr.d
 AND o.status = 'paid'
GROUP BY dr.d
ORDER BY dr.d;
