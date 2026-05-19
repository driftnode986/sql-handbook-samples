# Ch10: CASE 式 - 行を分岐させる

実践 SQL ハンドブック 第 10 章のサンプルクエリ集。

## 実行

```bash
docker compose up -d
psql -h localhost -p 5418 -U app -d handbook -f ch10-case/queries.sql
```

接続パスワードは `handbook` (docker-compose.yml 参照)。

## カバーする機能

- searched CASE (汎用形) と simple CASE (値比較形) の構文
- simple CASE は NULL を比較できない (IS NULL は searched CASE のみ)
- 短絡評価 (実行時の保証、計画時の例外あり)
- ELSE 省略時の NULL 返却と COUNT(CASE) の自動除外
- 型統合の罠 (PG では文字列と数値の混在は明示 CAST が必要)
- SUM(CASE WHEN ...) / COUNT(CASE WHEN ...) によるピボット表
- FILTER 句との使い分け (PG のみ対応、MySQL は SUM(CASE) 代替)
- ORDER BY 内・GROUP BY 内・WHERE 内の CASE
- COALESCE と NULLIF が CASE の特殊形
- PG の GREATEST / LEAST の NULL 扱い (SQL 標準からの逸脱)

## MySQL 8.4 での注意点

- searched CASE / simple CASE / ネスト CASE は PG と完全に同じ
- FILTER 句は **非対応** → `COUNT(CASE WHEN ... THEN 1 END)` や `SUM(CASE WHEN ... THEN expr ELSE 0 END)` に書き換える
- MySQL 固有の `IF(cond, a, b)` と `IFNULL(a, b)` は CASE / COALESCE に統一する (移植性のため)
- `GREATEST` / `LEAST` は SQL 標準準拠で「1 つでも NULL → 結果 NULL」を返す (PG とは異なる)
- `STRING_AGG(c.name, ', ' ORDER BY c.sort_order)` は MySQL では `GROUP_CONCAT(c.name ORDER BY c.sort_order SEPARATOR ', ')` (第 6 章の構文差を参照)

## 期待出力

`expected_output.txt` を `psql -f queries.sql` の出力と diff 比較する。
