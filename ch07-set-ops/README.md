# ch07-set-ops

書籍『実践 SQL ハンドブック』第 7 章 (UNION・INTERSECT・EXCEPT) のサンプルクエリ集。

## 実行

PostgreSQL 18 (`docker compose up -d` 起動済前提):

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch07-set-ops/queries.sql
```

期待出力との比較:

```bash
psql -h localhost -p 5418 -U app -d handbook \
  -f ch07-set-ops/queries.sql > /tmp/ch07_actual.txt 2>&1
diff ch07-set-ops/expected_output.txt /tmp/ch07_actual.txt
```

## MySQL 8.4 での書き換え

本章のクエリは大半が **PG 18 / MySQL 8.4 で共通** ですが、MySQL では以下に注意:

- **INTERSECT / EXCEPT は MySQL 8.0.31+ で対応**。本書は MySQL 8.4 LTS を扱うので問題ないが、過去バージョンでは UNION + 副問い合わせで代替する必要あり
- **INTERSECT ALL / EXCEPT ALL** も MySQL 8.0.31+ で対応
- 内側 SELECT に `ORDER BY` / `LIMIT` を書く構文 (括弧で囲む) は両 DB 同一
- 集合演算の NULL 扱い (NULL 同士を等しいとみなす) も両 DB 同一仕様

## 主要な結果数値 (本文との一致確認)

| クエリ | 結果行数 | 補足 |
|--------|---------|------|
| 節 1 UNION | 3 | status 3 種に縮約 |
| 節 1 UNION ALL | 10 | 重複保持 |
| 節 2 INTERSECT (2024 ∩ 2025 paid) | 435 | 定着顧客 |
| 節 3 EXCEPT (2024 - 2025) | 187 | 離脱ユーザー |
| 節 3 EXCEPT 逆方向 (2025 - 2024) | 178 | 2025 新規 |
| BQ #1 各テーブル行数 | 3 | events 30K / orders 5K / subscriptions 800 |
| BQ #2 = 節 2 と同じ | 435 | 定着顧客 |
| BQ #3 = 節 3 と同じ | 187 | 離脱ユーザー |
| BQ #4 未契約者 | 200 | Ch05 の数字と一致 |
| BQ #5 Books + Knives Top 3 | 6 | UNION ALL + 内側 LIMIT |

## トピック

- UNION / UNION ALL の使い分け (重複除去 vs 保持、性能観点)
- INTERSECT で共通集合 (定着顧客抽出)
- EXCEPT で差集合 (離脱・未契約者抽出、非可換)
- Union Compatible (列数・型互換、列名は最初の SELECT 由来)
- 演算子の優先順位 (INTERSECT > UNION = EXCEPT)
- ORDER BY / LIMIT の配置 (全体 vs 内側 SELECT)
- 集合演算の NULL 扱い (NULL 同士を「等しい」とみなす)
- EXCEPT vs NOT IN (NULL 安全性)
