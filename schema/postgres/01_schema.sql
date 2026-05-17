-- PostgreSQL 18 用 schema
-- 書籍『実践 SQL ハンドブック』(著: 牧野 誠) の companion repo
--
-- 9 テーブル:
--   users / categories / products / orders / order_items
--   subscriptions / events / employees / comments
--
-- 階層構造あり: categories / employees / comments (再帰 CTE 章で使用)
-- 多対多: order_items (orders × products)
-- JSONB: events.metadata (最小言及のみ)

-- ============================================================
-- users (顧客マスタ / 1,000 行)
-- ============================================================
-- PG 18 で標準化された uuidv7() を採用。
-- 時刻順 UUID なのでインデックス効率が gen_random_uuid() より高い。
CREATE TABLE users (
    user_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    email       TEXT NOT NULL UNIQUE,
    full_name   TEXT NOT NULL,
    signup_date DATE NOT NULL,
    country     TEXT NOT NULL DEFAULT 'JP'
);

-- ============================================================
-- categories (商品カテゴリ / 20 行・階層構造)
-- ============================================================
CREATE TABLE categories (
    category_id  INTEGER PRIMARY KEY,
    parent_id    INTEGER REFERENCES categories(category_id),
    name         TEXT NOT NULL,
    sort_order   INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- products (商品マスタ / 200 行)
-- ============================================================
CREATE TABLE products (
    product_id   BIGINT PRIMARY KEY,
    category_id  INTEGER NOT NULL REFERENCES categories(category_id),
    name         TEXT NOT NULL,
    price_jpy    INTEGER NOT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- orders (注文ヘッダ / 5,000 行)
-- ============================================================
CREATE TABLE orders (
    order_id     BIGINT PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users(user_id),
    ordered_at   TIMESTAMPTZ NOT NULL,
    status       TEXT NOT NULL,   -- 'paid' / 'cancelled' / 'pending'
    total_jpy    INTEGER NOT NULL
);

-- ============================================================
-- order_items (注文明細 / 12,000 行・多対多)
-- ============================================================
CREATE TABLE order_items (
    order_id     BIGINT NOT NULL REFERENCES orders(order_id),
    product_id   BIGINT NOT NULL REFERENCES products(product_id),
    quantity     INTEGER NOT NULL,
    unit_price   INTEGER NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

-- ============================================================
-- subscriptions (SaaS 月次課金 / 800 行)
-- ============================================================
CREATE TABLE subscriptions (
    subscription_id  BIGINT PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(user_id),
    plan             TEXT NOT NULL,    -- 'free' / 'pro' / 'enterprise'
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ,      -- NULL = 継続中
    monthly_jpy      INTEGER NOT NULL
);

-- ============================================================
-- events (ユーザーアクションログ / 30,000 行)
-- ============================================================
CREATE TABLE events (
    event_id     BIGINT PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES users(user_id),
    event_type   TEXT NOT NULL,        -- 'login' / 'view' / 'purchase' / 'logout'
    occurred_at  TIMESTAMPTZ NOT NULL,
    metadata     JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- ============================================================
-- employees (従業員 / 100 行・階層構造・自己結合)
-- ============================================================
CREATE TABLE employees (
    employee_id  INTEGER PRIMARY KEY,
    manager_id   INTEGER REFERENCES employees(employee_id),
    name         TEXT NOT NULL,
    title        TEXT NOT NULL,        -- 'CEO' / 'Director' / 'Manager' / 'Member'
    hired_at     DATE NOT NULL,
    salary_jpy   INTEGER NOT NULL
);

-- ============================================================
-- comments (コメント / 2,000 行・階層構造・コメントツリー)
-- ============================================================
CREATE TABLE comments (
    comment_id   BIGINT PRIMARY KEY,
    parent_id    BIGINT REFERENCES comments(comment_id),
    user_id      UUID NOT NULL REFERENCES users(user_id),
    body         TEXT NOT NULL,
    posted_at    TIMESTAMPTZ NOT NULL
);
