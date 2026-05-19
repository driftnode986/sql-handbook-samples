# Ch09: EXISTS と NOT EXISTS

実践 SQL ハンドブック 第 9 章のサンプルクエリ集。

## 実行

```bash
docker compose up -d
psql -h localhost -p 5418 -U app -d handbook -f ch09-exists/queries.sql
```

接続パスワードは `handbook` (docker-compose.yml 参照)。

## カバーする機能

- EXISTS / NOT EXISTS の基本構文と SELECT 1 慣習
- NOT EXISTS と NOT IN の NULL 安全性の対比
- NOT EXISTS と LEFT JOIN + IS NULL の等価性
- INNER JOIN vs EXISTS の挙動差 (multi-match 行水増し)
- 二重 NOT EXISTS による関係除算 (Relational Division)
- HAVING COUNT(DISTINCT) との比較
- EXISTS の AND / OR 結合 (多段相関)

## MySQL 8.4 での注意点

- EXISTS / NOT EXISTS 構文は PG と完全に同じ
- 二重 NOT EXISTS / VALUES 句も対応
- Semi-join / Anti-join 最適化は optimizer_switch で制御可能 (詳細は本書スコープ外)

## 期待出力

`expected_output.txt` を `psql -f queries.sql` の出力と diff 比較する。
