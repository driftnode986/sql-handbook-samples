# sql-handbook-samples

書籍『[実践 SQL ハンドブック](https://www.amazon.co.jp/dp/B0H28SX1N9)』(著: 牧野 誠 / Amazon Kindle) のサンプル DB と業務クエリ集の repo。

## quick start (5 分)

```bash
git clone https://github.com/driftnode986/sql-handbook-samples
cd sql-handbook-samples
docker compose up -d
# PostgreSQL 18 が localhost:5418、MySQL 8 が localhost:3308 で起動
# seed まで自動完了 (約 30 秒)
```

第 5 章 OUTER JOIN の章末クエリを試す:

```bash
psql -h localhost -p 5418 -U app -d handbook -f ch05-outer-join/queries.sql
```

MySQL でも同じクエリを試す:

```bash
mysql -h 127.0.0.1 -P 3308 -u app -p handbook < ch05-outer-join/queries.sql
```

## サンプル DB 規模

| テーブル | 行数 | 用途 |
|---|---|---|
| users | 1,000 | 顧客 |
| products | 200 | 商品マスタ |
| orders | 5,000 | 注文ヘッダ |
| order_items | 12,000 | 注文明細 |
| categories | 20 (階層あり) | 再帰 CTE 用 |
| subscriptions | 800 | SaaS 月次課金 |
| events | 30,000 | ユーザーアクションログ |
| employees | 100 (階層あり) | 自己結合 |
| comments | 2,000 (階層あり) | コメントツリー |

合計約 52,000 行。

## verify all

全章の queries.sql を実機検証:

```bash
bash scripts/verify-all.sh
```

全て PASS すれば exit 0、1 つでも diff が出れば exit 1。GitHub Actions でも PR ごとに自動実行。

## ライセンス

MIT
