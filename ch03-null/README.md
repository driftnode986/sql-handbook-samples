# 第 03 章: データ型と NULL の落とし穴

『実践 SQL ハンドブック』(著: 牧野 誠) 第 03 章のサンプルクエリ。

## 含まれているクエリ

`queries.sql` には章末「業務クエリ集」の 5 本を収録:

1. 継続中サブスクリプションの一覧 (`ended_at IS NULL`)
2. plan 別の継続 / 解約件数 (`COUNT(*) - COUNT(ended_at)` で NULL 件数を集計)
3. 各サブスクの利用期間日数 (`COALESCE` で継続中を基準日まで計算)
4. 上司なし社員(CEO)を含めた階層整理 (`LEFT JOIN` + `COALESCE`)
5. ルートカテゴリと子カテゴリ数の集計 (`parent_id IS NULL` + `COUNT(child.col)` の非 NULL 集計)

## 実行方法

リポジトリのトップで `docker compose up -d` 済みの状態で:

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch03-null/queries.sql
```

期待出力は `expected_output.txt` に同梱しています。実行結果と diff することで自分の環境での再現性を確認できます。

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch03-null/queries.sql > /tmp/ch03-actual.txt
diff /tmp/ch03-actual.txt ch03-null/expected_output.txt
```

差分が出なければ完璧に再現できています。

## MySQL での実行

本章のクエリは大半が PG / MySQL 共通の標準 SQL のみを使っているため、MySQL 8.4 でもほぼそのまま動きます。ただし以下の点に注意してください。

- `(timestamp - timestamp)::interval` の構文 (Q3) は PG 固有です。MySQL では `TIMESTAMPDIFF(DAY, started_at, COALESCE(ended_at, '2026-05-19 00:00:00'))` のように `TIMESTAMPDIFF` を使うか、`DATEDIFF` で日数のみ取得する形に書き換えてください。
- `TIMESTAMPTZ` リテラル (Q3) は MySQL では `TIMESTAMP` か `DATETIME` を使います。
- `::date` / `::numeric` のキャスト構文は PG 固有です。MySQL では `CAST(col AS DATE)` / `CAST(col AS DECIMAL(10,2))` に書き換えます。

```bash
# PG クエリをそのまま実行(Q3 はエラー、Q1/Q2/Q4/Q5 は動く)
docker exec -i sql-handbook-mysql mysql -uapp -phandbook handbook < ch03-null/queries.sql
```

MySQL 互換版のクエリを別ファイルで用意する場合は `mysql_queries.sql` を追加投入する方針です(現状は PG 版のみ)。

## 章で扱った重要な NULL の挙動

`queries.sql` で示している実機の挙動はすべて、本書 chapters/03_null.md の各節と対応しています。

- Q1: 「NULL は `IS NULL` でしか判定できない」(本書 §1, §3)
- Q2: 「`COUNT(*)` と `COUNT(col)` の差で NULL 件数を出す」(本書 §6)
- Q3: 「`COALESCE` で NULL を別の値に置換」(本書 §5.1)
- Q4: 「LEFT JOIN で右側が NULL になる行を取りこぼさない + COALESCE で表示を整える」(本書 §4.1, §5.1)
- Q5: 「`COUNT(col)` が非 NULL のみ数える性質を業務集計に応用する」(本書 §6, Q5 読み解き)

NULL の挙動が原因で「期待した値が出ない」「結果が空になる」と感じたら、まず本書 chapters/03_null.md の三値論理 (§2) と集約関数 §6 を参照してください。
