# 第 02 章: SELECT の文法を正しく理解する

『実践 SQL ハンドブック』(著: 牧野 誠) 第 02 章のサンプルクエリ。

## 含まれているクエリ

`queries.sql` には章末「業務クエリ集」の 5 本を収録:

1. 2025 年 12 月後半に登録した日本のユーザー一覧
2. 注文金額トップ 10 (キャンセル除外、同点者も全員取得 `WITH TIES`)
3. 顧客一覧のページネーション (20 件 × 3 ページ目)
4. ユーザー登録のある国一覧 (`DISTINCT`)
5. サブスクリプションを契約終了日順に並べ、継続中を末尾に (`NULLS LAST`)

## 実行方法

リポジトリのトップで `docker compose up -d` 済みの状態で、

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch02-select/queries.sql
```

期待出力は `expected_output.txt` に同梱しています。実行結果と diff することで自分の環境での再現性を確認できます。

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch02-select/queries.sql > /tmp/ch02-actual.txt
diff /tmp/ch02-actual.txt ch02-select/expected_output.txt
```

差分が出なければ完璧に再現できています。

## MySQL での実行

クエリ 5 は `NULLS LAST` 構文を使っているため MySQL 8.4 ではエラーになります。MySQL では `ORDER BY ended_at IS NULL, ended_at, subscription_id` のように書き換えてください。本書 chapters/02_select.md 5.2 節および業務クエリ 5 の「読み解き」で書き換え方法を解説しています。

その他の 4 クエリは MySQL 8.4 でもそのまま動きます。

```bash
docker exec -i sql-handbook-mysql mysql -uapp -phandbook handbook < ch02-select/queries.sql
```
