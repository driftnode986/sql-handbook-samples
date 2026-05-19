# Ch08: サブクエリと相関サブクエリ

実践 SQL ハンドブック 第 8 章のサンプルクエリ集。

## 実行

```bash
docker compose up -d
psql -h localhost -p 5418 -U app -d handbook -f ch08-subquery/queries.sql
```

接続パスワードは `handbook` (docker-compose.yml 参照)。

## カバーする機能

- スカラサブクエリ (1 行 1 列 / 0 行 NULL / 複数行エラー)
- 派生テーブル (FROM 句サブクエリ + LATERAL)
- IN / NOT IN / ANY / ALL の使い分け
- NOT IN の NULL 罠と 3 通りの安全化 (IS NOT NULL 明示 / EXCEPT / NOT EXISTS)
- 行サブクエリ ((user_id, status) IN ...)
- 相関サブクエリの評価モデル

## MySQL 8.4 での注意点

- 行サブクエリの `ANY` / `ALL` (例: `(1, 2) > ALL (SELECT ...)`) は非対応 (PG のみ)
- `IN` サブクエリの内側 `LIMIT` は構文エラー (ERROR 1235)。派生テーブルでラップ回避
- 派生テーブルの `AS` 別名は必須 (ERROR 1248)

## 期待出力

`expected_output.txt` を `psql -f queries.sql` の出力と diff 比較する。
