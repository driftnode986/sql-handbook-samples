-- PostgreSQL 18 用 索引
-- 書籍『実践 SQL ハンドブック』(著: 牧野 誠) の companion repo
--
-- 本書ではチューニングを扱わないため最小限の索引のみ。
-- 実機での EXPLAIN ANALYZE がストレスなく走る程度の補助。

CREATE INDEX idx_orders_user_id          ON orders(user_id);
CREATE INDEX idx_orders_ordered_at       ON orders(ordered_at);
CREATE INDEX idx_order_items_product_id  ON order_items(product_id);
CREATE INDEX idx_events_user_id          ON events(user_id);
CREATE INDEX idx_events_occurred_at      ON events(occurred_at);
CREATE INDEX idx_subscriptions_user_id   ON subscriptions(user_id);
