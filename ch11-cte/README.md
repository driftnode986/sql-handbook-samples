# Ch11: WITH (CTE) - 読める SQL を書く

実践 SQL ハンドブック 第 11 章のサンプルクエリ集。

## 実行

```bash
docker compose up -d
psql -h localhost -p 5418 -U app -d handbook -f ch11-cte/queries.sql
```

接続パスワードは `handbook` (docker-compose.yml 参照)。

## カバーする機能

- `WITH cte AS (...) SELECT ... FROM cte` の基本構文
- 列名の明示 `WITH cte (col1, col2) AS (...)`
- 複数 CTE のカンマ区切り
- CTE 間の前方参照ルール (cte1 → cte2 のみ、相互再帰は不可)
- 同じ CTE を複数回参照する自己 JOIN パターン (月次前月比)
- 派生テーブルと CTE の比較
- VIEW と CTE の使い分け
- 名前解決の優先順位 (派生テーブル > CTE > 実テーブル / VIEW)
- 第 8 章サブクエリと CTE の書き換え対比
- 第 10 章 CASE 式の CTE による分解
- アンチパターン: 不要な CTE
- ROW_NUMBER + PARTITION BY での順位付け (第 13 章先取り)

## MySQL 8.4 での注意点

- `WITH cte AS (...) SELECT ...` 構文は PG と完全に同じ
- カンマ区切りの複数 CTE、列名明示、前方参照ルール、名前解決優先順位も同じ
- `MATERIALIZED` / `NOT MATERIALIZED` 修飾子は **非対応** (構文エラー)、optimizer が自動判定
- データ修正 CTE (`WITH DELETE ... RETURNING`) は **非対応** (PG のみ)
- `FILTER (WHERE ...)` 句は **非対応**、`COUNT(CASE WHEN ... THEN 1 END)` で代替
- `DATE_TRUNC('month', ts)` は **非対応**、`DATE_FORMAT(ts, '%Y-%m-01')` で代替
- `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` は MySQL 8.0+ で対応 (第 13 章で本格的に扱う)

## 期待出力

`expected_output.txt` を `psql -f queries.sql` の出力と diff 比較する。
