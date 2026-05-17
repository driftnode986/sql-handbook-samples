-- PostgreSQL 18 用 seed
-- 書籍『実践 SQL ハンドブック』(著: 牧野 誠) の companion repo
--
-- 行数:
--   users 1,000 / categories 20 / products 200 / orders 5,000
--   order_items ~12,000 / subscriptions 800 / events 30,000
--   employees 100 / comments 2,000
-- 合計 約 52,000 行

-- 再現性のあるダミーデータを作るため setseed
SELECT setseed(0.42);

-- ============================================================
-- Seed: users (1,000 行)
-- ============================================================
INSERT INTO users (user_id, email, full_name, signup_date, country)
SELECT
    uuidv7(),
    'user' || gs || '@example.com',
    'User ' || gs,
    DATE '2024-01-01' + ((gs * 13) % 730) * INTERVAL '1 day',
    CASE (gs % 10)
        WHEN 0 THEN 'US'
        WHEN 1 THEN 'GB'
        WHEN 2 THEN 'DE'
        ELSE 'JP'
    END
FROM generate_series(1, 1000) AS gs;

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
SELECT
    gs,
    ((gs * 7) % 20) + 1,                       -- 1〜20 のカテゴリを循環
    'Product ' || gs,
    100 + ((gs * 37) % 4901),                  -- 100〜5000 円
    (gs % 20) <> 0                             -- 5% は非アクティブ
FROM generate_series(1, 200) AS gs;

-- ============================================================
-- Seed: orders (5,000 行)
-- ============================================================
-- random 用にユーザー UUID の配列を作成
WITH user_array AS (
    SELECT array_agg(user_id ORDER BY signup_date) AS uids FROM users
)
INSERT INTO orders (order_id, user_id, ordered_at, status, total_jpy)
SELECT
    gs,
    (SELECT uids FROM user_array)[((gs * 17) % 1000) + 1],
    TIMESTAMPTZ '2024-01-01 00:00:00+09' + ((gs * 11) % 730) * INTERVAL '1 day'
                                          + ((gs * 53) % 86400) * INTERVAL '1 second',
    CASE
        WHEN (gs % 10) < 8 THEN 'paid'
        WHEN (gs % 10) = 8 THEN 'cancelled'
        ELSE 'pending'
    END,
    500 + ((gs * 71) % 49500)                  -- 500〜50000 円
FROM generate_series(1, 5000) AS gs;

-- ============================================================
-- Seed: order_items (約 12,000 行・多対多)
-- ============================================================
-- 1 order あたり平均 2.4 アイテム。
-- order_id × product_id を unique にするため、order_id ごとに 1〜4 個の異なる product_id を割り当てる。
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT
    o.order_id,
    p.product_id,
    1 + ((o.order_id * 3 + p.product_id) % 5),                            -- 1〜5 個
    100 + (((o.order_id + p.product_id) * 37) % 4901)                     -- 100〜5000 円
FROM (
    SELECT
        order_id,
        -- order_id ごとに 1〜4 個の product_id を生成
        generate_series(1, 1 + ((order_id * 19) % 4)) AS item_idx
    FROM orders
) AS items
CROSS JOIN LATERAL (
    -- item_idx と order_id から決定的にユニークな product_id を選ぶ
    SELECT (((items.order_id * 31 + items.item_idx * 53) % 200) + 1) AS product_id
) AS p
JOIN orders o ON o.order_id = items.order_id
ON CONFLICT (order_id, product_id) DO NOTHING;

-- ============================================================
-- Seed: subscriptions (800 行)
-- ============================================================
WITH user_array AS (
    SELECT array_agg(user_id ORDER BY signup_date) AS uids FROM users
)
INSERT INTO subscriptions (subscription_id, user_id, plan, started_at, ended_at, monthly_jpy)
SELECT
    gs,
    (SELECT uids FROM user_array)[((gs * 23) % 1000) + 1],
    CASE
        WHEN (gs % 20) < 8  THEN 'free'
        WHEN (gs % 20) < 17 THEN 'pro'
        ELSE 'enterprise'
    END,
    TIMESTAMPTZ '2024-01-01 00:00:00+09' + ((gs * 29) % 600) * INTERVAL '1 day',
    CASE
        WHEN (gs % 10) < 4 THEN
            TIMESTAMPTZ '2024-01-01 00:00:00+09' + ((gs * 29) % 600) * INTERVAL '1 day'
                                                 + (30 + (gs * 7) % 300) * INTERVAL '1 day'
        ELSE NULL                                 -- 60% は継続中
    END,
    CASE
        WHEN (gs % 20) < 8  THEN 0                -- free
        WHEN (gs % 20) < 17 THEN 1980             -- pro
        ELSE 9800                                 -- enterprise
    END
FROM generate_series(1, 800) AS gs;

-- ============================================================
-- Seed: events (30,000 行)
-- ============================================================
WITH user_array AS (
    SELECT array_agg(user_id ORDER BY signup_date) AS uids FROM users
)
INSERT INTO events (event_id, user_id, event_type, occurred_at, metadata)
SELECT
    gs,
    (SELECT uids FROM user_array)[((gs * 41) % 1000) + 1],
    CASE
        WHEN (gs % 20) < 8  THEN 'login'
        WHEN (gs % 20) < 15 THEN 'view'
        WHEN (gs % 20) < 18 THEN 'purchase'
        ELSE 'logout'
    END,
    TIMESTAMPTZ '2024-01-01 00:00:00+09' + ((gs * 7) % 730) * INTERVAL '1 day'
                                         + ((gs * 47) % 86400) * INTERVAL '1 second',
    jsonb_build_object(
        'source',     CASE (gs % 3) WHEN 0 THEN 'web' WHEN 1 THEN 'ios' ELSE 'android' END,
        'session_id', (gs * 13) % 10000
    )
FROM generate_series(1, 30000) AS gs;

-- ============================================================
-- Seed: employees (100 行・階層構造)
-- ============================================================
-- 階層: CEO 1 → Director 5 → Manager 20 → Member 74
-- CEO: employee_id = 1
-- Director: employee_id 2〜6 (manager_id = 1)
-- Manager: employee_id 7〜26 (manager_id = 2〜6 をラウンドロビン)
-- Member: employee_id 27〜100 (manager_id = 7〜26 をラウンドロビン)
INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy) VALUES
    (1, NULL, 'CEO Yamada', 'CEO', DATE '2018-04-01', 15000000);

INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy)
SELECT
    gs,
    1,
    'Director ' || gs,
    'Director',
    DATE '2019-04-01' + ((gs * 31) % 365) * INTERVAL '1 day',
    10000000 + (gs * 100000)
FROM generate_series(2, 6) AS gs;

INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy)
SELECT
    gs,
    ((gs - 7) % 5) + 2,                          -- Director 2〜6 をラウンドロビン
    'Manager ' || gs,
    'Manager',
    DATE '2020-04-01' + ((gs * 23) % 365) * INTERVAL '1 day',
    7000000 + ((gs * 11) % 100) * 10000
FROM generate_series(7, 26) AS gs;

INSERT INTO employees (employee_id, manager_id, name, title, hired_at, salary_jpy)
SELECT
    gs,
    ((gs - 27) % 20) + 7,                        -- Manager 7〜26 をラウンドロビン
    'Member ' || gs,
    'Member',
    DATE '2021-04-01' + ((gs * 19) % 1460) * INTERVAL '1 day',
    4000000 + ((gs * 13) % 300) * 10000
FROM generate_series(27, 100) AS gs;

-- ============================================================
-- Seed: comments (2,000 行・階層構造)
-- ============================================================
-- 構成: トップレベル 500 + 返信 1,000 + 返信の返信 500 = 2,000
-- comment_id 1〜500     : parent_id = NULL (トップレベル)
-- comment_id 501〜1500  : parent_id = ((comment_id - 501) % 500) + 1
-- comment_id 1501〜2000 : parent_id = ((comment_id - 1501) % 1000) + 501

WITH user_array AS (
    SELECT array_agg(user_id ORDER BY signup_date) AS uids FROM users
)
INSERT INTO comments (comment_id, parent_id, user_id, body, posted_at)
SELECT
    gs,
    CASE
        WHEN gs <= 500                  THEN NULL
        WHEN gs <= 1500                 THEN ((gs - 501) % 500) + 1
        ELSE                                  ((gs - 1501) % 1000) + 501
    END,
    (SELECT uids FROM user_array)[((gs * 43) % 1000) + 1],
    'Comment body #' || gs || ' lorem ipsum dolor sit amet.',
    TIMESTAMPTZ '2024-01-01 00:00:00+09' + ((gs * 17) % 730) * INTERVAL '1 day'
                                         + ((gs * 29) % 86400) * INTERVAL '1 second'
FROM generate_series(1, 2000) AS gs;
