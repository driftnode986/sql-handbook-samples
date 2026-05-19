# ch06-group-by

書籍『実践 SQL ハンドブック』第 6 章 (GROUP BY と集約関数) のサンプルクエリ集。

## 実行

PostgreSQL 18 (`docker compose up -d` 起動済前提):

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch06-group-by/queries.sql
```

期待出力との比較:

```bash
psql -h localhost -p 5418 -U app -d handbook \
  -f ch06-group-by/queries.sql > /tmp/ch06_actual.txt 2>&1
diff ch06-group-by/expected_output.txt /tmp/ch06_actual.txt
```

## MySQL 8.4 での書き換え

本章で扱う SQL のうち、以下は **MySQL 8.4 では非対応**または構文差があります。

- **FILTER (WHERE ...) 句**: PG のみ。MySQL では `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` で代替
  - BQ #2 (月次サマリ): `COUNT(*) FILTER (WHERE status='paid')` → `SUM(CASE WHEN status='paid' THEN 1 ELSE 0 END)`
  - BQ #3 (プラン別): 同様の書き換え
  - 本文 節 6: 全クエリ同様
- **CUBE / GROUPING SETS**: PG のみ。MySQL では `UNION ALL` で代替 (本文 節 9.1 参照)
- **ARRAY_AGG**: PG のみ。MySQL では `JSON_ARRAYAGG` で代替 (配列型がないため)
- **STRING_AGG**: PG のみ。MySQL は `GROUP_CONCAT(値 ORDER BY ... SEPARATOR ',')` で書き換え
  - BQ #6 (商品別ユーザーリスト): `STRING_AGG(DISTINCT u.full_name, ', ' ORDER BY u.full_name)` → `GROUP_CONCAT(DISTINCT u.full_name ORDER BY u.full_name SEPARATOR ', ')`
  - MySQL の `group_concat_max_len` (デフォルト 1024 バイト) に注意。長い結合は途中切れする
- **ROLLUP**: 両 DB で動くが、MySQL は `GROUP BY a, b WITH ROLLUP` のレガシー構文も使える (本文 節 8.2 参照)
- **GROUPING() 関数**: MySQL 8.0+ でサポート、PG と同仕様

## 集約関数の NULL 扱い (本文 節 4 参照)

| 関数 | NULL 入力 | 空集合 |
|------|---------|-------|
| COUNT(*) | カウント | 0 |
| COUNT(col) | 除外 | 0 |
| SUM/AVG | 除外 | **NULL** |
| MAX/MIN | 除外 | **NULL** |
| STRING_AGG/GROUP_CONCAT | 除外 | **NULL** |
| ARRAY_AGG | **含む** | NULL |
| BOOL_AND/BOOL_OR | 除外 | NULL |

## トピック

- GROUP BY 評価順序 (WHERE → GROUP BY → HAVING → SELECT)
- 関数従属性 (PRIMARY KEY が GROUP BY にあれば他列 SELECT 可能)
- 集約関数の NULL 扱いと COALESCE 防御
- WHERE と HAVING の使い分け
- FILTER (WHERE ...) 句で条件付き集計
- 多対多 GROUP BY 水増し事故 (User 1 の例)
- STRING_AGG / ARRAY_AGG / JSON 集約
- ROLLUP / CUBE / GROUPING SETS + GROUPING() 関数
- MySQL ONLY_FULL_GROUP_BY モード対応
