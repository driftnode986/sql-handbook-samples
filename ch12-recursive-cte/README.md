# Ch12: 再帰 CTE - 階層と経路を扱う

実践 SQL ハンドブック 第 12 章のサンプルクエリ集。

## 実行

```bash
docker compose up -d
psql -h localhost -p 5418 -U app -d handbook -f ch12-recursive-cte/queries.sql
```

接続パスワードは `handbook` (docker-compose.yml 参照)。

## カバーする機能

- `WITH RECURSIVE cte AS (anchor UNION ALL recursive)` の基本構造
- 評価アルゴリズム (working table + intermediate table)
- WHERE 句による明示終了 / UNION DISTINCT / LIMIT / cte_max_recursion_depth
- PG 固有の `CYCLE` 句 (SQL:1999 標準、循環検出)
- PG 固有の `SEARCH BREADTH/DEPTH FIRST` 句 (探索順制御)
- MySQL アンカー型決定罠 (`CHAR(3)` 切り詰め) と `CAST` 回避
- MySQL 再帰部禁止構文 (集約・ウィンドウ・GROUP BY・ORDER BY・DISTINCT)
- カテゴリツリー / 組織図 / コメントスレッドの全展開
- 日付シリーズ生成 (PG `generate_series` の MySQL 代替)
- 集約の連鎖 (BOM 展開・カテゴリ配下集計)
- 通常 CTE と再帰 CTE の混在パターン
- 第 13 章ウィンドウ関数との使い分け

## MySQL 8.4 での注意点

- `WITH RECURSIVE` は MySQL 8.0+ で対応
- 自己参照する CTE が 1 つでもあれば `RECURSIVE` キーワード必須
- `CYCLE` 句、`SEARCH BREADTH/DEPTH FIRST` 句は **非対応** (手動 path 配列で代替)
- アンカー部 SELECT の型のみで列型が決まる (`CAST(... AS CHAR(N))` で広げる)
- 再帰部での `GROUP BY` / `ORDER BY` / `DISTINCT` / 集約関数 / ウィンドウ関数 / 複数自己参照は禁止
- `cte_max_recursion_depth` デフォルト 1000 (安全弁、本来は WHERE 句で停止)
- `generate_series` 非対応のため、連続値生成は再帰 CTE 必須
- データ修正 CTE (`WITH DELETE ... RETURNING`) は **非対応** (PG のみ)

## 期待出力

`expected_output.txt` を `psql -f queries.sql` の出力と diff 比較する。

## サンプル DB の階層構造

- **categories** (20 行): 最大 depth 3、ルート 3 (Books / Electronics / Home)、最深部は `Electronics > Computers > Laptops > Gaming Laptops`
- **employees** (100 行): 最大 depth 3、CEO 1 + Director 5 + Manager 20 + Member 74
- **comments** (2000 行): 最大 depth 2、ルート 500 + 1 段返信 1000 + 2 段返信 500
