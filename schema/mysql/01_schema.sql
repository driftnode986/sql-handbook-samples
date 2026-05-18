-- MySQL 8 用 schema
-- 書籍『実践 SQL ハンドブック』(著: 牧野 誠) の companion repo
--
-- 9 テーブル (PostgreSQL 18 版と列名・テーブル名を完全一致):
--   users / categories / products / orders / order_items
--   subscriptions / events / employees / comments
--
-- 階層構造あり: categories / employees / comments (再帰 CTE 章で使用)
-- 多対多: order_items (orders × products)
-- JSON: events.metadata (最小言及のみ)
--
-- PG 18 ↔ MySQL 8 主な型翻訳:
--   UUID            → CHAR(36)
--   TEXT            → VARCHAR(N) / TEXT
--   TIMESTAMPTZ     → TIMESTAMP (UTC 換算)
--   BOOLEAN         → TINYINT(1)
--   JSONB           → JSON

-- ============================================================
-- users (顧客マスタ / 1,000 行)
-- ============================================================
-- MySQL 8 には UUID 型がないため CHAR(36) で代用。
-- 値は seed 側で UUID() を使って生成する (PG 側 uuidv7() と完全一致させる必要なし)。
CREATE TABLE users (
    user_id     CHAR(36) NOT NULL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(255) NOT NULL,
    signup_date DATE NOT NULL,
    country     VARCHAR(8) NOT NULL DEFAULT 'JP'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- categories (商品カテゴリ / 20 行・階層構造)
-- ============================================================
CREATE TABLE categories (
    category_id  INTEGER NOT NULL PRIMARY KEY,
    parent_id    INTEGER NULL,
    name         VARCHAR(255) NOT NULL,
    sort_order   INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT categories_parent_id_fkey
        FOREIGN KEY (parent_id) REFERENCES categories(category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- products (商品マスタ / 200 行)
-- ============================================================
CREATE TABLE products (
    product_id   BIGINT NOT NULL PRIMARY KEY,
    category_id  INTEGER NOT NULL,
    name         VARCHAR(255) NOT NULL,
    price_jpy    INTEGER NOT NULL,
    is_active    TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT products_category_id_fkey
        FOREIGN KEY (category_id) REFERENCES categories(category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- orders (注文ヘッダ / 5,000 行)
-- ============================================================
-- MySQL 8 の TIMESTAMP は UTC 内部保存・暗黙 TZ 変換あり。
-- PG 側 TIMESTAMPTZ と意味的に同等 (両 DB とも UTC 基準で書き込む)。
CREATE TABLE orders (
    order_id     BIGINT NOT NULL PRIMARY KEY,
    user_id      CHAR(36) NOT NULL,
    ordered_at   TIMESTAMP NOT NULL,
    status       VARCHAR(20) NOT NULL,   -- 'paid' / 'cancelled' / 'pending'
    total_jpy    INTEGER NOT NULL,
    CONSTRAINT orders_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- order_items (注文明細 / 約 12,500 行・多対多)
-- ============================================================
CREATE TABLE order_items (
    order_id     BIGINT NOT NULL,
    product_id   BIGINT NOT NULL,
    quantity     INTEGER NOT NULL,
    unit_price   INTEGER NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT order_items_order_id_fkey
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT order_items_product_id_fkey
        FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- subscriptions (SaaS 月次課金 / 800 行)
-- ============================================================
CREATE TABLE subscriptions (
    subscription_id  BIGINT NOT NULL PRIMARY KEY,
    user_id          CHAR(36) NOT NULL,
    plan             VARCHAR(20) NOT NULL,    -- 'free' / 'pro' / 'enterprise'
    started_at       TIMESTAMP NOT NULL,
    ended_at         TIMESTAMP NULL,          -- NULL = 継続中
    monthly_jpy      INTEGER NOT NULL,
    CONSTRAINT subscriptions_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- events (ユーザーアクションログ / 30,000 行)
-- ============================================================
CREATE TABLE events (
    event_id     BIGINT NOT NULL PRIMARY KEY,
    user_id      CHAR(36) NOT NULL,
    event_type   VARCHAR(20) NOT NULL,        -- 'login' / 'view' / 'purchase' / 'logout'
    occurred_at  TIMESTAMP NOT NULL,
    metadata     JSON NOT NULL,
    CONSTRAINT events_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- employees (従業員 / 100 行・階層構造・自己結合)
-- ============================================================
CREATE TABLE employees (
    employee_id  INTEGER NOT NULL PRIMARY KEY,
    manager_id   INTEGER NULL,
    name         VARCHAR(255) NOT NULL,
    title        VARCHAR(40) NOT NULL,        -- 'CEO' / 'Director' / 'Manager' / 'Member'
    hired_at     DATE NOT NULL,
    salary_jpy   INTEGER NOT NULL,
    CONSTRAINT employees_manager_id_fkey
        FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- comments (コメント / 2,000 行・階層構造・コメントツリー)
-- ============================================================
CREATE TABLE comments (
    comment_id   BIGINT NOT NULL PRIMARY KEY,
    parent_id    BIGINT NULL,
    user_id      CHAR(36) NOT NULL,
    body         TEXT NOT NULL,
    posted_at    TIMESTAMP NOT NULL,
    CONSTRAINT comments_parent_id_fkey
        FOREIGN KEY (parent_id) REFERENCES comments(comment_id),
    CONSTRAINT comments_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================================
-- 索引 (PG 版 03_indexes.sql 相当)
-- ============================================================
-- 本書ではチューニングを扱わないため最小限の索引のみ。
-- 実機での EXPLAIN がストレスなく走る程度の補助。
CREATE INDEX idx_orders_user_id          ON orders(user_id);
CREATE INDEX idx_orders_ordered_at       ON orders(ordered_at);
CREATE INDEX idx_order_items_product_id  ON order_items(product_id);
CREATE INDEX idx_events_user_id          ON events(user_id);
CREATE INDEX idx_events_occurred_at      ON events(occurred_at);
CREATE INDEX idx_subscriptions_user_id   ON subscriptions(user_id);
