-- MySQL 8 用 seed
-- 書籍『実践 SQL ハンドブック』(著: 牧野 誠) の companion repo
--
-- 行数 (PG 版と同一):
--   users 1,000 / categories 20 / products 200 / orders 5,000
--   order_items ~12,500 / subscriptions 800 / events 30,000
--   employees 100 / comments 2,000
-- 合計 約 51,600 行
--
-- 注意:
--   * MySQL 8 の cte_max_recursion_depth デフォルトは 1,000。
--     events 30,000 行を再帰 CTE で生成するため 100,000 に拡張する。
--   * 決定論的な擬似乱数 (gs * N MOD M) で再現性を確保。
--     PG 側 setseed(0.42) は不要 (UUID 以外は決定論的計算で行数・分布が固定)。

SET SESSION cte_max_recursion_depth = 100000;

-- ============================================================
-- Seed: users (1,000 行)
-- ============================================================
INSERT INTO users (user_id, email, full_name, signup_date, country)
WITH RECURSIVE seq (gs) AS (
    SELECT 1
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 1000
)
SELECT
    UUID(),
    CONCAT('user', gs, '@example.com'),
    CONCAT('User ', gs),
    DATE_ADD('2024-01-01', INTERVAL ((gs * 13) MOD 730) DAY),
    CASE (gs MOD 10)
        WHEN 0 THEN 'US'
        WHEN 1 THEN 'GB'
        WHEN 2 THEN 'DE'
        ELSE 'JP'
    END
FROM seq;

-- ============================================================
-- Seed: categories (20 行・階層構造)
-- ============================================================
-- 4 階層:
--   depth 1 (root):     Electronics(1), Books(2), Home(3)
--   depth 2:            Computers(4), Audio(5), Tech(6), Business(7), Cooking(8), Travel(9), Furniture(10), Kitchen(11)
--   depth 3:            Laptops(12), Desktops(13), Headphones(14), Speakers(15), Programming(16), AI(17), Cookware(18), Knives(19)
--   depth 4:            Gaming Laptops(20)
INSERT INTO categories (category_id, parent_id, name, sort_order) VALUES
    (1,  NULL, 'Electronics',    1),
    (2,  NULL, 'Books',          2),
    (3,  NULL, 'Home',           3),
    (4,  1,    'Computers',      1),
    (5,  1,    'Audio',          2),
    (6,  2,    'Tech',           1),
    (7,  2,    'Business',       2),
    (8,  2,    'Cooking',        3),
    (9,  2,    'Travel',         4),
    (10, 3,    'Furniture',      1),
    (11, 3,    'Kitchen',        2),
    (12, 4,    'Laptops',        1),
    (13, 4,    'Desktops',       2),
    (14, 5,    'Headphones',     1),
    (15, 5,    'Speakers',       2),
    (16, 6,    'Programming',    1),
    (17, 6,    'AI',             2),
    (18, 11,   'Cookware',       1),
    (19, 11,   'Knives',         2),
    (20, 12,   'Gaming Laptops', 1);

-- ============================================================
-- Seed: products (200 行)
-- ============================================================
INSERT INTO products (product_id, category_id, name, price_jpy, is_active)
WITH RECURSIVE seq (gs) AS (
    SELECT 1
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 200
)
SELECT
    gs,
    ((gs * 7) MOD 20) + 1,                       -- 1〜20 のカテゴリを循環
    CONCAT('Product ', gs),
    100 + ((gs * 37) MOD 4901),                  -- 100〜5000 円
    CASE WHEN (gs MOD 20) <> 0 THEN 1 ELSE 0 END -- 5% は非アクティブ
FROM seq;

-- ============================================================
-- 補助: users_ordered (signup_date 順の rownum 付き)
-- ============================================================
-- PG 側で `array_agg(user_id ORDER BY signup_date)` の配列インデックス参照を
-- MySQL では一時テーブル + ROW_NUMBER() で代替する。
-- orders / subscriptions / events / comments の seed で使用。
CREATE TEMPORARY TABLE users_ordered (
    rn      INTEGER NOT NULL PRIMARY KEY,
    user_id CHAR(36) NOT NULL
) ENGINE=InnoDB;

INSERT INTO users_ordered (rn, user_id)
SELECT ROW_NUMBER() OVER (ORDER BY signup_date, user_id), user_id
FROM users;

-- ============================================================
-- Seed: orders (5,000 行)
-- ============================================================
INSERT INTO orders (order_id, user_id, ordered_at, status, total_jpy)
WITH RECURSIVE seq (gs) AS (
    SELECT 1
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 5000
)
SELECT
    s.gs,
    uo.user_id,
    DATE_ADD(
        DATE_ADD('2023-12-31 15:00:00', INTERVAL ((s.gs * 11) MOD 730) DAY),
        INTERVAL ((s.gs * 53) MOD 86400) SECOND
    ),
    CASE
        WHEN (s.gs MOD 10) < 8 THEN 'paid'
        WHEN (s.gs MOD 10) = 8 THEN 'cancelled'
        ELSE 'pending'
    END,
    500 + ((s.gs * 71) MOD 49500)
FROM seq s
JOIN users_ordered uo ON uo.rn = ((s.gs * 17) MOD 1000) + 1;

-- ============================================================
-- Seed: order_items (約 12,500 行・多対多)
-- ============================================================
-- PG 側のロジックを再現:
--   1 order あたり 1 + ((order_id * 19) MOD 4) 個 (= 1〜4 個) の product_id を生成
--   product_id = ((order_id * 31 + item_idx * 53) MOD 200) + 1
--   PRIMARY KEY (order_id, product_id) の重複は INSERT IGNORE で吸収
-- 想定 1 order = 1〜4 item の決定論的計算 → 平均 2.5 item / 5,000 orders = 12,500 行
-- 重複が出るケースは INSERT IGNORE でスキップ (PG 側 ON CONFLICT DO NOTHING と同等)
INSERT IGNORE INTO order_items (order_id, product_id, quantity, unit_price)
WITH RECURSIVE
seq4 (n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq4 WHERE n < 4
),
items AS (
    SELECT
        o.order_id,
        s.n AS item_idx
    FROM orders o
    JOIN seq4 s ON s.n <= 1 + ((o.order_id * 19) MOD 4)
)
SELECT
    items.order_id,
    (((items.order_id * 31 + items.item_idx * 53) MOD 200) + 1) AS product_id,
    1 + ((items.order_id * 3 + (((items.order_id * 31 + items.item_idx * 53) MOD 200) + 1)) MOD 5) AS quantity,
    100 + (((items.order_id + (((items.order_id * 31 + items.item_idx * 53) MOD 200) + 1)) * 37) MOD 4901) AS unit_price
FROM items;

-- ============================================================
-- Seed: subscriptions (800 行)
-- ============================================================
INSERT INTO subscriptions (subscription_id, user_id, plan, started_at, ended_at, monthly_jpy)
WITH RECURSIVE seq (gs) AS (
    SELECT 1
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 800
)
SELECT
    s.gs,
    uo.user_id,
    CASE
        WHEN (s.gs MOD 20) < 8  THEN 'free'
        WHEN (s.gs MOD 20) < 17 THEN 'pro'
        ELSE 'enterprise'
    END,
    DATE_ADD('2023-12-31 15:00:00', INTERVAL ((s.gs * 29) MOD 600) DAY),
    CASE
        WHEN (s.gs MOD 10) < 4 THEN
            DATE_ADD(
                DATE_ADD('2023-12-31 15:00:00', INTERVAL ((s.gs * 29) MOD 600) DAY),
                INTERVAL (30 + (s.gs * 7) MOD 300) DAY
            )
        ELSE NULL
    END,
    CASE
        WHEN (s.gs MOD 20) < 8  THEN 0
        WHEN (s.gs MOD 20) < 17 THEN 1980
        ELSE 9800
    END
FROM seq s
JOIN users_ordered uo ON uo.rn = ((s.gs * 23) MOD 1000) + 1;

-- ============================================================
-- Seed: events (30,000 行)
-- ============================================================
INSERT INTO events (event_id, user_id, event_type, occurred_at, metadata)
WITH RECURSIVE seq (gs) AS (
    SELECT 1
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 30000
)
SELECT
    s.gs,
    uo.user_id,
    CASE
        WHEN (s.gs MOD 20) < 8  THEN 'login'
        WHEN (s.gs MOD 20) < 15 THEN 'view'
        WHEN (s.gs MOD 20) < 18 THEN 'purchase'
        ELSE 'logout'
    END,
    DATE_ADD(
        DATE_ADD('2023-12-31 15:00:00', INTERVAL ((s.gs * 7) MOD 730) DAY),
        INTERVAL ((s.gs * 47) MOD 86400) SECOND
    ),
    JSON_OBJECT(
        'source',     CASE (s.gs MOD 3) WHEN 0 THEN 'web' WHEN 1 THEN 'ios' ELSE 'android' END,
        'session_id', (s.gs * 13) MOD 10000
    )
FROM seq s
JOIN users_ordered uo ON uo.rn = ((s.gs * 41) MOD 1000) + 1;

-- ============================================================
-- Seed: employees (100 行・階層構造)
-- ============================================================
-- 階層: CEO 1 → Director 5 → Manager 20 → Member 74
INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy) VALUES
    (1, NULL, 'CEO Yamada', 'CEO', '2018-04-01', 15000000);

INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy)
WITH RECURSIVE seq (gs) AS (
    SELECT 2
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 6
)
SELECT
    gs,
    1,
    CONCAT('Director ', gs),
    'Director',
    DATE_ADD('2019-04-01', INTERVAL ((gs * 31) MOD 365) DAY),
    10000000 + (gs * 100000)
FROM seq;

INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy)
WITH RECURSIVE seq (gs) AS (
    SELECT 7
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 26
)
SELECT
    gs,
    ((gs - 7) MOD 5) + 2,                          -- Director 2〜6 をラウンドロビン
    CONCAT('Manager ', gs),
    'Manager',
    DATE_ADD('2020-04-01', INTERVAL ((gs * 23) MOD 365) DAY),
    7000000 + ((gs * 11) MOD 100) * 10000
FROM seq;

INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy)
WITH RECURSIVE seq (gs) AS (
    SELECT 27
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 100
)
SELECT
    gs,
    ((gs - 27) MOD 20) + 7,                        -- Manager 7〜26 をラウンドロビン
    CONCAT('Member ', gs),
    'Member',
    DATE_ADD('2021-04-01', INTERVAL ((gs * 19) MOD 1460) DAY),
    4000000 + ((gs * 13) MOD 300) * 10000
FROM seq;

-- ============================================================
-- Seed: comments (2,000 行・階層構造)
-- ============================================================
-- 構成: トップレベル 500 + 返信 1,000 + 返信の返信 500 = 2,000
-- comment_id 1〜500     : parent_id = NULL (トップレベル)
-- comment_id 501〜1500  : parent_id = ((comment_id - 501) MOD 500) + 1
-- comment_id 1501〜2000 : parent_id = ((comment_id - 1501) MOD 1000) + 501
INSERT INTO comments (comment_id, parent_id, user_id, body, posted_at)
WITH RECURSIVE seq (gs) AS (
    SELECT 1
    UNION ALL
    SELECT gs + 1 FROM seq WHERE gs < 2000
)
SELECT
    s.gs,
    CASE
        WHEN s.gs <= 500   THEN NULL
        WHEN s.gs <= 1500  THEN ((s.gs - 501) MOD 500) + 1
        ELSE                    ((s.gs - 1501) MOD 1000) + 501
    END,
    uo.user_id,
    CONCAT('Comment body #', s.gs, ' lorem ipsum dolor sit amet.'),
    DATE_ADD(
        DATE_ADD('2023-12-31 15:00:00', INTERVAL ((s.gs * 17) MOD 730) DAY),
        INTERVAL ((s.gs * 29) MOD 86400) SECOND
    )
FROM seq s
JOIN users_ordered uo ON uo.rn = ((s.gs * 43) MOD 1000) + 1;

-- ============================================================
-- 補助テーブル後始末
-- ============================================================
DROP TEMPORARY TABLE users_ordered;
