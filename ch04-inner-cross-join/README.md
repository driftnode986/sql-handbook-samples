# 第4章: INNER JOIN・CROSS JOIN

書籍『実践 SQL ハンドブック』(著: 牧野 誠) 第 4 章のサンプルクエリ。

## 前提

ルート `README.md` の手順で `docker compose up -d` 済みであること (PostgreSQL は port 5418、MySQL は port 3308)。

## 実行

PostgreSQL 18 で実行:

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch04-inner-cross-join/queries.sql
```

(パスワード: `handbook`)

期待される出力は `expected_output.txt` を参照。実行結果が一致しない場合は schema/seed の更新が必要。

## ファイル

- `queries.sql`: 章本文の SQL + 章末業務クエリ集 5 本 (合計 16 文)
- `expected_output.txt`: PostgreSQL 18 での実行結果

## MySQL での検証

本章のクエリは `generate_series` (PostgreSQL 固有関数) を除いて、MySQL 8.4 でも同等の動作をします。
`generate_series` 部分は MySQL では再帰 CTE で代替できますが、本章の検証では PG のみで実行します。
