-- 第 03 章: データ型と NULL の落とし穴
-- 『実践 SQL ハンドブック』(著: 牧野 誠) 章末「業務クエリ集」5 本
--
-- 実行: psql -h localhost -p 5418 -U app -d handbook -f ch03-null/queries.sql
-- MySQL で実行する場合は README.md の互換性メモを参照

\pset null '(NULL)'

-- ============================================================
-- Q1. 継続中サブスクリプションの一覧
-- 「現時点で解約していないユーザーに新機能を案内したい」マーケティング要件
-- ============================================================
SELECT subscription_id, plan, started_at::date AS started, monthly_jpy
FROM subscriptions
WHERE ended_at IS NULL
ORDER BY started_at, subscription_id
LIMIT 5;

-- ============================================================
-- Q2. plan 別の継続 / 解約件数
-- 「プラン別の継続率を経営会議で報告したい」要件
-- COUNT(*) と COUNT(ended_at) の差で NULL 件数を出す定番テクニック
-- ============================================================
SELECT
  plan,
  COUNT(*)                        AS total,
  COUNT(ended_at)                 AS ended,
  COUNT(*) - COUNT(ended_at)      AS active,
  ROUND(
    (COUNT(*) - COUNT(ended_at))::numeric * 100
    / NULLIF(COUNT(*), 0),
    1
  ) AS active_rate_pct
FROM subscriptions
GROUP BY plan
ORDER BY plan;

-- ============================================================
-- Q3. 各サブスクの利用期間日数(継続中は固定基準日まで)
-- 「サブスクの利用期間を出したい」要件
-- COALESCE(ended_at, 基準日) で NULL を置換して期間計算
-- 業務では基準日を NOW() / CURRENT_TIMESTAMP に置き換える
-- ============================================================
SELECT
  subscription_id,
  plan,
  started_at::date AS started,
  COALESCE(ended_at::date, DATE '2026-05-19') AS ended_or_today,
  (COALESCE(ended_at, TIMESTAMPTZ '2026-05-19') - started_at)::interval AS duration
FROM subscriptions
WHERE plan = 'pro'
ORDER BY started_at, subscription_id
LIMIT 5;

-- ============================================================
-- Q4. 上司なし社員(CEO)を含めた階層整理
-- 「組織図を出すために、上司なし(CEO)も含めて 1 行で表示したい」要件
-- LEFT JOIN で manager_id IS NULL の行を取りこぼさず、COALESCE で表示を整える
-- ============================================================
SELECT
  e.employee_id,
  e.name      AS emp,
  e.title,
  e.manager_id,
  COALESCE(m.name, '(頂点)') AS mgr_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.employee_id
WHERE e.title IN ('CEO', 'Director')
ORDER BY e.employee_id
LIMIT 5;

-- ============================================================
-- Q5. ルートカテゴリと子カテゴリ数の集計
-- 「カテゴリツリーのトップレベルだけ、子カテゴリ数を添えて出したい」要件
-- parent_id IS NULL でルートを絞り、LEFT JOIN + COUNT(child.category_id) で
-- 非 NULL 件数を数える (COUNT(*) だと 0 件のルートでも 1 になる罠を回避)
-- ============================================================
SELECT
  root.category_id,
  root.name AS root_name,
  COUNT(child.category_id) AS child_count
FROM categories root
LEFT JOIN categories child ON child.parent_id = root.category_id
WHERE root.parent_id IS NULL
GROUP BY root.category_id, root.name
ORDER BY root.category_id;
