# Fly.io から移行できる無料 PostgreSQL／アプリ基盤の比較

調査日: **2026-09-01**

> [!IMPORTANT]
> 無料枠は予告なく変わる。契約前にリンク先の Pricing、利用可能リージョン、休止・削除条件を再確認すること。本稿の「容量」は、バックアップや WAL を含む請求対象容量ではなく、原則としてサービスが公表するデータベースストレージ枠である。

## 結論

Fly.io の 1 GB を明確に超えたい場合、現実的な順序は次のとおり。

1. **Xata** — managed PostgreSQL の操作感を維持しながら、Free で **15 GB**。まず互換性を検証する第一候補。
2. **CockroachDB Cloud Basic** — **10 GiB**。PostgreSQL wire protocol 対応だが PostgreSQL そのものではないため、ORM・拡張・SQL の互換性試験が必須。
3. **Oracle Cloud Always Free VM にセルフホスト** — 最大 **200 GB の Block Volume** をアプリと DB で共有でき、容量は最も大きい。ただし運用、バックアップ、セキュリティ、障害対応をすべて自分で負う。
4. **Google Cloud Always Free VM にセルフホスト** — 対象 US リージョンの `e2-micro` と **30 GB-month** の Standard Persistent Disk。小規模アプリと DB の同居向けだが RAM が厳しい。

「完全な PostgreSQL」「managed」「1 GB 超」「期限なし」「カード不要」「アプリも同じ事業者で無料」をすべて同時に満たす大手 PaaS は、今回確認できなかった。DB を Xata、アプリを Koyeb／Render／Cloudflare Workers 等に分ける構成が、無料と運用負荷のバランスを取りやすい。

## 1 GB を超える有力候補

| 候補                                                                                                          |                                     無料 DB 容量 | PostgreSQL 互換性                             | アプリも無料         | 重要な制約                                                                                 | 判定                       |
| ------------------------------------------------------------------------------------------------------------- | -----------------------------------------------: | --------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------ | -------------------------- |
| [Xata Free](https://xata.io/pricing)                                                                          |                                            15 GB | PostgreSQL ベース。接続方法・対応拡張を要確認 | なし                 | 帯域・branch・同時実行等にも上限。新旧プロダクトの説明が混在し得る                         | **managed 第一候補**       |
| [CockroachDB Cloud Basic](https://www.cockroachlabs.com/pricing/)                                             |                                           10 GiB | wire protocol／多くの SQL は互換。ただし別 DB | なし                 | PostgreSQL 拡張、細かな型・DDL・locking semantics に差                                     | **互換試験できれば有力**   |
| [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)                                                  | Block Volume 合計 200 GB（OS・DB・アプリで共有） | VM 上の本物の PostgreSQL                      | VM／ARM Compute あり | managed DB ではない。Always Free capacity 不足、アカウント停止、リージョン制約の報告に注意 | **運用できるなら最大容量** |
| [Google Cloud Free Program](https://cloud.google.com/free/docs/free-cloud-features)                           |             Standard Persistent Disk 30 GB-month | VM 上の本物の PostgreSQL                      | `e2-micro` 1台       | 対象 US リージョン限定、外向き通信上限、RAM 約 1 GB。Cloud SQL は無料対象外                | **低負荷・自己運用向け**   |
| [CockroachDB self-hosted](https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-on-premises) + 上記 VM |                                VM のディスク次第 | PostgreSQL 互換 DB                            | 同じ VM              | 単一ノードでは耐障害性を失い、PostgreSQL より重い                                          | 特殊用途のみ               |

### Xata を最初に試す理由

- Fly.io の 1 GB に対し公称 15 GB で、当面の余裕が大きい。
- 接続文字列を使う一般的な PostgreSQL クライアント／ORMから試しやすい。
- セルフホストと違い、OS パッチや PostgreSQL プロセス監視の負担を減らせる。

ただし `pg_dump` がそのまま restore できるか、必要な extension（PostGIS、`pg_trgm`、`uuid-ossp` 等）、connection pooling、バックアップ／PITR、休眠・削除ポリシーは、実データ投入前に確認する。

## アプリ無料枠との組み合わせ

DB とアプリを別事業者にするとネットワーク遅延と egress が増えるため、同一または近接リージョンを選ぶ。

| アプリ基盤                                                                        | 無料枠の概要                          | DB の置き方                    | 注意点                                                                 |
| --------------------------------------------------------------------------------- | ------------------------------------- | ------------------------------ | ---------------------------------------------------------------------- |
| [Koyeb](https://www.koyeb.com/pricing)                                            | Free Web Service あり                 | Xata／CockroachDB を外部接続   | scale-to-zero、リソース、帯域、無料 DB の現行条件を確認                |
| [Render](https://render.com/pricing)                                              | Free Web Service あり                 | 外部 DB 推奨                   | idle 時の spin-down と再起動遅延。Free Postgres は永続移行先にしにくい |
| [Cloudflare Workers](https://developers.cloudflare.com/workers/platform/pricing/) | 1日単位の request／CPU 無料枠         | Hyperdrive 経由または HTTP API | Node.js 常駐サーバーとは実行モデルが異なる。TCP 直結可否を設計時に確認 |
| [Deno Deploy](https://deno.com/deploy/pricing)                                    | request／転送量等の Free 枠           | 外部 DB                        | Deno runtime への適合が必要                                            |
| [Vercel Hobby](https://vercel.com/pricing)                                        | serverless／edge の Hobby 枠          | Marketplace または外部 DB      | 非商用条件、function duration、帯域、接続数に注意                      |
| [Netlify Free](https://www.netlify.com/pricing/)                                  | Functions／Web 配信の Free 枠         | 外部 DB                        | credit 制の上限と DB connection pooling を確認                         |
| Oracle Always Free VM                                                             | VM 内にアプリと PostgreSQL を同居     | localhost                      | 単一障害点。最低でも外部 object storage へ暗号化 backup                |
| Google Cloud `e2-micro`                                                           | VM 内に軽量アプリと PostgreSQL を同居 | localhost                      | メモリ不足対策が必須。Docker 多段構成は特に厳しい                      |

推奨構成は、低運用負荷なら **Koyeb Free + Xata Free**、PostgreSQL の完全互換が必須で自己運用可能なら **Oracle Always Free VM + PostgreSQL + アプリ同居**。

## 候補にはなるが「1 GB 超の恒久無料」を満たさないサービス

比較対象を多く残すため、不採用理由も記録する。

| サービス                                                                                                 | 無料枠／状態                                            | 今回の評価                                                                                                                   |
| -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| [Neon Free](https://neon.com/pricing)                                                                    | Free あり。project、compute、storage、history に上限    | serverless PostgreSQL として優秀だが、単一 DB で Fly.io の 1 GB を確実に上回るか現行表を再確認。容量目的だけなら Xata に劣る |
| [Supabase Free](https://supabase.com/pricing)                                                            | DB 500 MB 級の Free 枠                                  | 1 GB より小さい。Auth／Storage／Realtime をまとめたい場合のみ                                                                |
| [Prisma Postgres](https://www.prisma.io/pricing)                                                         | Free plan あり                                          | operation 数と storage 上限を要確認。1 GB 超を主目的に即決しない                                                             |
| [Nile](https://www.thenile.dev/pricing)                                                                  | Free plan あり                                          | tenant 特化。容量、compute 時間、製品成熟度を要検証                                                                          |
| [Koyeb Database](https://www.koyeb.com/pricing)                                                          | Free database が提供される時期・条件あり                | 1 GB 前後なら今回の容量問題を先送りするだけ                                                                                  |
| [Render Postgres](https://render.com/docs/free#free-postgres-databases)                                  | Free DB は容量・期限・失効条件あり                      | production の恒久移行先には不向き                                                                                            |
| [Railway](https://railway.com/pricing)                                                                   | credit／trial 型                                        | 恒久無料枠として予算を組まない。小額従量課金を許容するなら簡単                                                               |
| [Aiven](https://aiven.io/pricing)                                                                        | trial／credit の提供あり                                | trial 終了後は有料。managed 品質重視なら有料候補                                                                             |
| [Heroku Postgres](https://www.heroku.com/pricing)                                                        | Eco／Mini 等は有料                                      | 無料前提を満たさない                                                                                                         |
| [DigitalOcean Managed Databases](https://www.digitalocean.com/pricing/managed-databases)                 | 有料                                                    | 無料前提を満たさない                                                                                                         |
| [Crunchy Bridge](https://www.crunchydata.com/products/crunchy-bridge/pricing)                            | trial 後は有料                                          | PostgreSQL 品質は高いが無料前提を満たさない                                                                                  |
| [Amazon RDS](https://aws.amazon.com/rds/free/)                                                           | 新規アカウントの期間・credit 型無料                     | 永続的な無料移行先ではない                                                                                                   |
| [Azure Database for PostgreSQL](https://azure.microsoft.com/pricing/details/postgresql/flexible-server/) | trial credit／期間限定施策                              | 永続的な無料移行先ではない                                                                                                   |
| [Google Cloud SQL](https://cloud.google.com/sql/pricing)                                                 | trial credit は使えるが Always Free 対象外              | VM セルフホストなら無料枠内、managed Cloud SQL は不可                                                                        |
| [ElephantSQL](https://www.elephantsql.com/)                                                              | サービス終了                                            | 新規候補から除外                                                                                                             |
| [Tembo](https://tembo.io/)                                                                               | 提供形態が変化                                          | 古い無料枠紹介を信用せず、現行提供状況を確認                                                                                 |
| [PlanetScale](https://planetscale.com/pricing)                                                           | PostgreSQL ではなく主に Vitess/MySQL 系、無料条件も変化 | PostgreSQL 移行先ではない                                                                                                    |
| [Turso](https://turso.tech/pricing)                                                                      | SQLite/libSQL                                           | 容量は魅力的でも PostgreSQL ではない                                                                                         |
| [Cloudflare D1](https://developers.cloudflare.com/d1/platform/pricing/)                                  | SQLite 系 serverless DB                                 | PostgreSQL ではない。SQL／migration の作り直しが必要                                                                         |
| [MongoDB Atlas](https://www.mongodb.com/pricing)                                                         | Free cluster あり                                       | document DB。データモデル変更が必要                                                                                          |

## 移行前に、まず Fly.io 側で確認すること

90% が「実データ」ではなく、不要 index、table bloat、WAL、ログ、古い job データの可能性もある。移行しても再発するため、先に内訳を取る。

```sql
-- DB 全体
SELECT pg_size_pretty(pg_database_size(current_database()));

-- table + index の大きい順
SELECT
  schemaname,
  relname,
  pg_size_pretty(pg_total_relation_size(relid)) AS total,
  pg_size_pretty(pg_relation_size(relid)) AS table_only,
  pg_size_pretty(pg_indexes_size(relid)) AS indexes
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 30;

-- dead tuples の目安
SELECT schemaname, relname, n_live_tup, n_dead_tup,
       last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 30;
```

緊急対応では、不要データを retention policy に沿って削除し通常の `VACUUM (ANALYZE)` を行う。`VACUUM FULL` は排他 lock と追加ディスク領域を必要とするため、空き容量が 10% しかない本番で安易に実行しない。不要 index の削除や `REINDEX CONCURRENTLY` も、依存関係・一時容量・実行時間を確認してから行う。

## 推奨する比較検証手順

1. **容量の猶予を作る** — Fly Volume の一時増量または不要データの安全な削除を先に行い、移行中の write failure を防ぐ。
2. **要件表を作る** — PostgreSQL version、extensions、最大 connection、リージョン、個人／商用、月間 egress、PITR、RPO/RTO を記録する。
3. **Xata と CockroachDB に同じ schema を投入** — `pg_dump --schema-only` から始め、DDL error を一覧化する。
4. **匿名化した production 相当データで試験** — 容量だけでなく query latency、index、transaction、migration、connection pooling を測る。
5. **restore rehearsal** — backup を「取れた」ではなく、新しい空 DB に restore して件数と checksum を照合する。
6. **dual-write または短時間停止で cutover** — TTL を下げ、最終差分、read-only 化、接続先変更、smoke test の順に進める。
7. **rollback window を確保** — Fly.io 側を即削除せず、規約と費用が許す期間 read-only で保持する。

### 最低限の受け入れテスト

- schema、row count、主要 aggregate の一致
- timezone、collation、case sensitivity、sequence／identity の一致
- transaction isolation、unique／foreign key、advisory lock の挙動
- ORM migration と connection pool（PgBouncer 対応を含む）
- cron／queue worker／background job の二重実行防止
- backup export と restore、障害時の連絡経路
- 無料上限到達時が「課金」「read-only」「停止」「削除」のどれか

## 最終判断

- **最小の変更で managed を維持:** Xata を PoC。だめなら Neon／有料最小プランも含めて再比較する。
- **PostgreSQL 互換差をアプリ側で吸収可能:** CockroachDB Cloud Basic。
- **月額 0 円と容量を最優先し、Linux／DB を運用可能:** Oracle Cloud Always Free VM。
- **アプリも完全無料で簡単に:** Xata + Koyeb を第一案、Xata + Render を第二案。ただし双方の休止・egress・商用条件を確認する。
- **本番データが重要:** 無料枠だけで決めない。安価な paid PostgreSQL は、バックアップ、PITR、SLA、サポート、突然の無料枠変更リスクを含めると総コストが低い場合が多い。
