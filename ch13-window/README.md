# Ch13: ウィンドウ関数 - 集計の革命

実践 SQL ハンドブック 第 13 章のサンプルクエリ集。本書最終章。

## 実行

```bash
docker compose up -d
psql -h localhost -p 5418 -U app -d handbook -f ch13-window/queries.sql
```

## カバーする機能

- `OVER (PARTITION BY ... ORDER BY ... frame_clause)` 構文
- ランキング関数 5 種 (ROW_NUMBER / RANK / DENSE_RANK / PERCENT_RANK / CUME_DIST)
- NTILE による分位 (四分位・十分位 等)
- LAG / LEAD で前後の行を参照 (前月比・購入間隔)
- FIRST_VALUE / LAST_VALUE / NTH_VALUE とフレーム依存性 (LAST_VALUE 罠回避)
- フレーム句 (ROWS / RANGE、UNBOUNDED PRECEDING、N PRECEDING、CURRENT ROW)
- 集約関数 (SUM / COUNT / AVG) のウィンドウ化 - 累計・移動平均
- WINDOW 句で名前付きウィンドウ定義を再利用
- ウィンドウ関数の WHERE/HAVING 制限とサブクエリ経由フィルタ
- 第 12 章再帰 CTE との組み合わせパターン

## MySQL 8.4 での注意点

- ウィンドウ関数は MySQL 8.0+ で対応 (8.4 LTS も含む)
- 構文は PostgreSQL とほぼ完全互換
- 非対応: `GROUPS` フレームモード、`EXCLUDE` 句、`RESPECT/IGNORE NULLS`、`FROM FIRST/FROM LAST`
- NULL の ORDER BY デフォルトが PG (`NULLS LAST`) と MySQL (`NULLS FIRST`) で異なる
- `DATE_TRUNC` の代わりに `DATE_FORMAT(ts, '%Y-%m-01')` を使う

## 期待出力

`expected_output.txt` を `psql -f queries.sql` の出力と diff 比較する。
