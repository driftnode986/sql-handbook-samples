-- 『実践 SQL ハンドブック』 第 02 章: SELECT の文法を正しく理解する
-- 業務クエリ集 5 本 (本書 chapters/02_select.md と byte-for-byte 一致)
--
-- 実行: psql -h localhost -p 5418 -U app -d handbook -f ch02-select/queries.sql

-- ============================================================
-- クエリ1: 2025 年 12 月後半に登録した日本のユーザー一覧
-- ============================================================
SELECT user_id, email, full_name, signup_date
FROM users
WHERE country = 'JP'
  AND signup_date >= DATE '2025-12-15'
ORDER BY signup_date DESC, user_id
LIMIT 10;

-- ============================================================
-- クエリ2: 注文金額トップ 10 (キャンセル除外、同点者も全員取得)
-- ============================================================
SELECT order_id, total_jpy
FROM orders
WHERE status = 'paid'
ORDER BY total_jpy DESC
FETCH FIRST 10 ROWS WITH TIES;

-- ============================================================
-- クエリ3: 顧客一覧のページネーション (20 件 × 3 ページ目)
-- ============================================================
SELECT user_id, full_name, email
FROM users
ORDER BY signup_date DESC, user_id
LIMIT 20 OFFSET 40;

-- ============================================================
-- クエリ4: ユーザー登録のある国一覧 (DISTINCT)
-- ============================================================
SELECT DISTINCT country
FROM users
ORDER BY country;

-- ============================================================
-- クエリ5: サブスクリプションを契約終了日順に並べ、継続中を末尾に
-- ============================================================
SELECT subscription_id, plan, started_at::date AS started_at,
       ended_at::date AS ended_at, monthly_jpy
FROM subscriptions
WHERE subscription_id BETWEEN 320 AND 330
ORDER BY ended_at NULLS LAST, subscription_id;
