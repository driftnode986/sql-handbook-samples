# Ch05: OUTER JOIN: 欠損を扱う

LEFT / RIGHT / FULL OUTER JOIN を中心に、`COALESCE`・`generate_series`・`LEFT JOIN LATERAL` を用いて欠損データを可視化するパターンを実機検証する。

## 起動

```bash
cd ~/Workspace/sql-handbook-samples
docker compose up -d
```

## 実行 (PostgreSQL 18)

```bash
docker exec -i sql-handbook-pg psql -U app -d handbook -f - < ch05-outer-join/queries.sql
```

結果が `expected_output.txt` と一致するか:

```bash
docker exec -i sql-handbook-pg psql -U app -d handbook -f - < ch05-outer-join/queries.sql \
  | diff - ch05-outer-join/expected_output.txt
```

## MySQL 8.4 での実行

本章のクエリの多くは MySQL でも動作するが、以下は MySQL 非対応または構文差あり:

- **`generate_series`**: MySQL 8.4 には相当機能なし。再帰 CTE で代替する (本書 Ch12 で扱う):

  ```sql
  WITH RECURSIVE cal(d) AS (
    SELECT DATE '2025-12-26'
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM cal WHERE d < DATE '2026-01-02'
  )
  SELECT cal.d, COUNT(o.order_id) AS orders
  FROM cal
  LEFT JOIN orders o ON DATE(o.ordered_at) = cal.d AND o.status = 'paid'
  GROUP BY cal.d
  ORDER BY cal.d;
  ```

- **`FULL OUTER JOIN`**: MySQL 8.4 は非対応。`UNION ALL` で代替 (本書節 7 参照)
- **`COUNT(*) FILTER (WHERE ...)`**: MySQL 8.4 は非対応。`SUM(CASE WHEN ... THEN 1 ELSE 0 END)` で代替

`LATERAL` は MySQL 8.0.14+ で利用可能なので業務クエリ 4 はそのまま動く。

## クエリ構成

- 節 3-9 の本文クエリ 6 本 + 業務クエリ集 5 本 = 計 11 クエリ
- 全クエリ PG 18 で実機検証済み (2026-05-19)
