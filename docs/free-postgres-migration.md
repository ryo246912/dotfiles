# Fly.io から移行できる無料 PostgreSQL／アプリ基盤の比較

調査日: **2026-09-01**

> [!IMPORTANT]
> 無料枠は予告なく変わる。契約前にリンク先の Pricing、利用可能リージョン、休止・削除条件を再確認すること。本稿の「容量」は、バックアップや WAL を含む請求対象容量ではなく、原則としてサービスが公表するデータベースストレージ枠である。

## 結論

Fly.io の 1 GB を明確に超えたい場合、現実的な順序は次のとおり。

1. **CockroachDB Cloud Basic** — **10 GiB**。AgentsView 0.38.1 は upstream が CockroachDB 対応を明記している。一方、Atuin 18.8.0 の migration には PostgreSQL 固有の trigger function があるため、Atuin の移行先には採用しない。
2. **Oracle Cloud Always Free VM にセルフホスト** — 最大 **200 GB の Block Volume** をアプリと DB で共有でき、容量は最も大きい。ただし運用、バックアップ、セキュリティ、障害対応をすべて自分で負う。
3. **Google Cloud Always Free VM にセルフホスト** — 対象 US リージョンの `e2-micro` と **30 GB-month** の Standard Persistent Disk。小規模アプリと DB の同居向けだが RAM が厳しい。

「完全な PostgreSQL」「managed」「1 GB 超」「期限なし」「カード不要」「アプリも同じ事業者で無料」をすべて同時に満たす大手 PaaS は、今回確認できなかった。現在のデータ増加源が AgentsView schema なら、**AgentsView だけ CockroachDB Cloud Basic へ分離し、Atuin は既存 PostgreSQL に残す**ことで、無料のまま安全に容量を空けやすい。

## Atuin／AgentsView に対する具体的な推奨

この repository の実構成では、Atuin と AgentsView はどちらも 256 MB のコンテナで、HTTP request がないと Fly Machine を停止する設定になっている。両アプリは現在一つの PostgreSQL database を共有し、AgentsView だけを `agentsview` schema と read／push／owner role で分離している。アプリとDBを分けてよいという要件を踏まえ、**AgentsView の app／DB だけを先に分離する**のが最小リスクとなる。

### 推奨順

|  順位 | アプリ                                                                         | DB                                                     | 月額 0 円にする条件                                                          | 選ぶ理由                                                                     |
| ----: | ------------------------------------------------------------------------------ | ------------------------------------------------------ | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **1** | **Atuin と AgentsView は Fly.io に残す**                                       | **AgentsView は CockroachDB、Atuin は既存 PostgreSQL** | 現在の Fly app compute が無料 allowance／credit 内であること                 | app を変えず、増え続ける AgentsView data を10 GiB枠へ分離できる              |
| **2** | **[Google Cloud Run](https://cloud.google.com/run/pricing) に2サービス**       | **AgentsView は CockroachDB、Atuin は PostgreSQL**     | Cloud Run の request、CPU、memory、egress の無料枠内。billing account は必要 | appもFlyから出せる。DBは互換性に応じて分ける                                 |
| **3** | **[Northflank Developer Sandbox](https://northflank.com/pricing) に2サービス** | **CockroachDB Cloud Basic**                            | 現行 Sandbox が2サービスを許容し、compute／egress 上限内                     | Docker image をほぼそのまま使え、アプリを一事業者にまとめられる              |
| **4** | **Atuin は Koyeb、AgentsView は Render（PoC／個人用途のみ）**                  | **AgentsViewはCockroachDB、AtuinはPostgreSQL**         | 各社のfree web serviceと通信枠内                                             | 低いCPU／RAM、休止、月間instance-hoursの制約があり、本番の可用性は期待しない |
| **5** | **Oracle Always Free VM に両アプリと PostgreSQL**                              | VM 内 PostgreSQL                                       | Always Free compute／block volume 内                                         | 最大容量。ただし managed ではなく、単一 VM の保守と backup は自己責任        |

**確定案は「Fly app 2個を維持 + AgentsView DBだけCockroachDBへ分離」**である。ただし、先に `pg_schema_size('agentsview')` を測り、AgentsView が容量の主因であることを確認する。既存 app は `auto_stop_machines = "stop"`、`min_machines_running = 0` なので、compute の実請求が無料範囲なら app 移転から得られる利点は小さい。Fly.io の Billing 画面で直近2か月の app compute、IPv4、egress が本当に0円か確認し、0円でなければCloud Runへ移す。

### Cloud Run はどの程度まで無料か

- Atuin は `ghcr.io/atuinsh/atuin`、AgentsView は `ghcr.io/kenn-io/agentsview` の既存 OCI image を利用できる。
- 2サービスを独立して scale-to-zero でき、Koyeb + Render のように運用画面や secret 管理を二社へ分割しなくてよい。
- AtuinはCloud Runの汎用`PORT`を読まず`ATUIN_PORT`で待受portを決めるため、現在の8888から`ATUIN_PORT=8080`へ明示的に変更する。AgentsViewは現在と同じ8080を利用できる。
- CockroachDB Cloud へは public TLS endpoint で接続する。Fly private hostname の `psgl.flycast` と `sslmode=disable` は移行後に使用しない。

一方、Atuin sync と AgentsView viewer を合わせた Cloud Run の compute は無料枠に収まりやすいものの、**Cloud Run と CockroachDB Cloud 間の DB traffic は external egress になり得る**。無料枠は保存容量だけでなく egress も監視する。CockroachDB Cloud と同じ／近いリージョンが選べない場合は latency も実測する。

[Cloud Run の公式料金表](https://cloud.google.com/run/pricing)で request-based billing に毎月付く無料枠は、billing account 全体で **180,000 vCPU-seconds、360,000 GiB-seconds、200万requests**。1 vCPU／512 MiBならCPU枠が先に尽き、**2アプリ合計で約50 vCPU-hours／月**が目安となる。

| 使い方（2アプリ合計）     |             概算CPU時間 | 判定             |
| ------------------------- | ----------------------: | ---------------- |
| 1万requests／月、平均1秒  |  約2.8時間 + cold start | 十分余裕あり     |
| 10万requests／月、平均1秒 | 約27.8時間 + cold start | 無料枠内の見込み |
| 1万requests／月、平均5秒  | 約13.9時間 + cold start | 無料枠内の見込み |
| 常時接続requestが1本      |           月730時間相当 | 無料にならない   |

個人用のAtuin syncと、必要時だけ開くAgentsViewであれば50時間のbillable CPU枠には通常余裕がある。ただしrepositoryだけから実trafficは確定できない。Cloud Run移行後は `container/billable_instance_time`、request count、outbound data transferにbudget alertを設定する。AgentsViewの画面やSSEを常時開く運用は避け、`min-instances=0`、request-based billingを維持する。外向き通信の無料条件はcompute枠とは別で、公式料金表はNorth America内のdata transferについて月1 GiBの無料枠を記載しているため、東京から外部DBへのegressが必ず無料とはみなさない。

したがって、**現在のようにAtuinは同期時だけ、AgentsViewは閲覧時だけ起動する個人利用なら、月1万requests・平均5秒（約13.9 vCPU-hours）程度までは、cold startを加えても50 vCPU-hoursに対して約36時間の余裕がある**。月10万requests・平均1秒でも約22時間の余裕がある。一方、画面の常時接続、`min-instances=1`、instance-based billingのいずれかを使うと、この見積もりは適用できない。

これはrequest数と処理時間から出した上限見積もりであり、現在のFly Metricsを取得した実測値ではない。この実行環境には`flyctl`と利用者のFly／Google Cloud credentialがないため、現行trafficとの照合やCloud Runへの実deployは実行していない。移行判断前にFly Metricsの直近30日について、2アプリ合計のrequest数、平均／p95 duration、egressを上表へ代入する。

### 採用可能: Cloud Run 2サービス + AgentsViewはCockroachDB + AtuinはGCE PostgreSQL

質問の構成は**実現できる**。Google Cloud Free Programに無料のmanaged PostgreSQLがあるわけではなく、Compute EngineのAlways Free `e2-micro` VMへ自分でPostgreSQLをインストールする構成になる。

```text
Internet
  ├─ Cloud Run: atuin
  │    └─ Direct VPC egress（private ranges only）
  │         └─ GCE e2-micro private IP:5432
  │              └─ PostgreSQL（Atuin専用）
  └─ Cloud Run: agentsview
       └─ public TLS
            └─ CockroachDB Cloud Basic（AgentsView専用）
```

この構成を**appも含めてFly.ioから出す場合の推奨案**とする。Atuinは本物のPostgreSQLを維持でき、AgentsViewはupstreamが対応を明記するCockroachDBへ分離できる。

#### 無料に収める必須条件

1. GCE VMはFree Tier対象の`e2-micro`を1台だけ使い、対象リージョンの`us-west1`、`us-central1`、`us-east1`のいずれかに置く。
2. Standard Persistent DiskはbootとPostgreSQL dataを含めて合計30 GB-month以内にする。30 GBすべてをDB dataに使えるわけではない。
3. Cloud RunもVMと同じリージョン、推奨は`us-central1`に置き、AtuinからPostgreSQLへのlatencyとリージョン間network料金を避ける。
4. VMにはexternal IPv4を付けない。PostgreSQLはprivate IPだけでlistenし、Cloud Runのservice accountからDirect VPC egress経由で到達させる。
5. Direct VPC egressは`private-ranges-only`にする。`all-traffic`ではAgentsViewからCockroachDBへの通信にもCloud NAT等が必要となり、無料構成を崩しやすい。
6. Cloud Runは両サービスとも`min-instances=0`、request-based billingを使い、前節の合計50 vCPU-hours／月の範囲に収める。
7. PostgreSQLのfirewall ingressはCloud Runが使うsubnet rangeからTCP 5432だけを許可する。`0.0.0.0/0`へ5432を公開しない。
8. VM管理はexternal IPを常設せず、IAP TCP forwardingでSSHする。

[Cloud Run Direct VPC egress](https://cloud.google.com/run/docs/configuring/vpc-direct-vpc)はServerless VPC Access connectorなしでVPC private addressへ接続できる。このため、常時稼働connectorの追加費用を避けながらAtuinからprivate PostgreSQLへ接続できる。ただしVPC networkのdata transfer料金は別なので、同一リージョンに置いてbilling reportを監視する。

#### この構成の制約

- `e2-micro`は約1 GB RAMなので、Atuin PostgreSQL専用にする。AgentsView DBや両app containerを同じVMへ追加しない。
- PostgreSQLは`max_connections`を小さくし、Cloud Runの最大instance数と1instanceあたりconnection poolを制限する。無制限scale-outはDB connectionを枯渇させる。
- VM、PostgreSQL、OS patch、監視、vacuum、backup、restoreは自己管理となり、Cloud SQLのPITR／HAは利用できない。
- 30 GB diskはbackupではない。無料を厳守するなら、暗号化したdumpの保管先とretentionを別途決め、その保存容量／egressも無料枠に収まるか確認する。
- external IPなしのVMは一般Internetへ直接出られない。OS updateにCloud NATを常設すると課金され得るため、patch取得方法または短時間だけ使う有料egressを運用設計に含める。「厳密に毎月0円」とsecurity patchの容易さにはtrade-offがある。
- 単一VM／単一diskでHAではない。個人用syncでは許容できても、停止を許容できないproductionには推奨しない。

#### 採用判定

| 要件                                    | 判定                                                                              |
| --------------------------------------- | --------------------------------------------------------------------------------- |
| Atuinが本物のPostgreSQLを使う           | ✅ GCE VM上のPostgreSQL                                                           |
| AgentsViewが1 GB超のmanaged無料DBを使う | ✅ CockroachDB Cloud Basic 10 GiB                                                 |
| app 2個をscale-to-zeroで無料運用する    | ✅ Cloud Run無料枠内なら可能                                                      |
| DBをInternetへ公開しない                | ✅ Atuin DBはDirect VPC、AgentsView DBはproviderのTLS endpoint                    |
| DB運用もmanaged                         | ⚠️ AgentsViewのみmanaged。Atuin PostgreSQLは自己管理                              |
| 無条件で必ず0円                         | ⚠️ 対象region、disk、Cloud Run compute、RU、network、backupの全上限を守る必要あり |

結論として、**個人用Atuin／AgentsViewで停止を許容でき、PostgreSQLを自分で保守できるなら、この構成を採用してよい**。完全managedを優先する場合はAtuin用DBだけ有料PostgreSQLにする必要がある。

### アプリごとの配置条件

#### Atuin

- container command は現在と同じ `server start`。
- `ATUIN_HOST=0.0.0.0`、`ATUIN_PORT=8080`、`ATUIN_OPEN_REGISTRATION=false` を設定する。
- database URLはCockroachDBへ変更せず、既存の本物のPostgreSQLを使う。appをCloud Runへ移す場合も、Atuin用PostgreSQLは別途必要となる。
- history sync は cold start を許容しやすいが、client timeout 内に起動できることを実機で確認する。

#### AgentsView

- `PG_SERVE=1`、`AGENTSVIEW_DISABLE_UPDATE_CHECK=1`、`AGENTSVIEW_PG_SCHEMA=agentsview` を維持する。
- `AGENTSVIEW_PG_URL` は CockroachDB Cloud 上の **read-only role** にする。local PC の `pg push` は別の **read/write role**、migration だけ owner role を使用する。
- Fly の `[[files]]` は他 PaaS でそのまま使えない。`AGENTSVIEW_CONFIG_TOML` から `/data/config.toml` を作る entrypoint、secret file 機能、または各 PaaS の volume／mount 機能へ置き換える。
- local PC からの push は `flyctl proxy` を廃止し、CockroachDB Cloud の TLS endpoint へ直接接続する。接続 URL を shell history や CI log に出さない。

### CockroachDB互換性の確認結果

#### AgentsView 0.38.1: 採用可能

[AgentsView 0.38.1の公式pg-sync文書](https://github.com/kenn-io/agentsview/blob/v0.38.1/docs/pg-sync.md)はCockroachDBをshared databaseとして明示的にサポートし、0.33.0以降はanalytics／usage queryもCockroachDB向けに改善したとしている。repository内にもCockroachDBを考慮したquery／indexとPostgreSQL integration testがある。したがって、**AgentsView schemaの移行先としては適合**と判断する。

注意点は、CockroachDBにpgvectorがないためAgentsViewのvector pushが自動的にskipされ、session contentの同期だけが継続されること。現在semantic／hybrid searchにpgvectorを使っている場合、その機能を失ってよいか確認する。

[CockroachDB Cloud Basicの公式料金表](https://www.cockroachlabs.com/pricing/)では、毎月最初の**10 GiB storageと5,000万 Request Units**が無料範囲となる。現在のFly Volume全体が約0.9 GiBでも、AgentsView schemaはそれ以下なので、storageだけなら移行直後に少なくとも約9.1 GiB、現状の10倍超の余裕がある。ただしFly Volumeの0.9 GiBにはAtuin、WAL、ログも含まれるため、正確な余裕は次で計算する。

```text
CockroachDB storage余裕 [GiB] = 10 - pg_schema_size('agentsview') / 1024^3
概算の成長可能月数 = storage余裕 / AgentsView schemaの月間増加量
```

Request Unitsは保存容量と別の上限であり、repositoryから実際のquery回数は確定できない。無料を厳守する場合はCockroachDB Consoleで月次RU使用量とstorage alertを設定し、検証push後に増分を測る。Basicで無料分を超えた際の課金・停止設定は、cluster作成時の現行画面で確認する。

#### Atuin 18.8.0: 採用しない

[Atuin 18.8.0のPostgreSQL migration](https://github.com/atuinsh/atuin/tree/v18.8.0/crates/atuin-server-postgres/migrations)には、`CREATE OR REPLACE FUNCTION ... RETURNS trigger`、`LANGUAGE plpgsql VOLATILE COST 100`、`TG_OP`、`CREATE TRIGGER ... EXECUTE PROCEDURE`が含まれる。CockroachDBの一般的なwire compatibilityだけでは、このmigrationと将来のAtuin upgradeを保証できない。upstreamにもCockroachDBをsupported backendとする記載やtestを確認できなかったため、**Atuin DBはCockroachDBへ移さない**。

#### 本番移行前の最終ゲート

upstreamの対応表があっても、実アカウント／実schemaの検証なしでcutoverはしない。CockroachDB Cloud Basicの検証clusterで次を通す。

1. AgentsView 0.38.1の空DB migrationと`pg push --projects <small-project>`が成功する。
2. `agentsview pg status`、viewer、analytics、usage画面が成功する。
3. read-only app userとread/write push userを分けられる。owner/default privilegesはCockroachDBの権限モデルに合わせ、同一SQLの再現を要件にしない。
4. local PCとFly／Cloud Runの両方からTLS接続でき、connection／request unit上限内である。
5. schema単位のexportと、空の検証DBへのrestoreが成功する。

この5項目が通れば、AgentsView DBのCockroachDB移行を進めてよい。実際のcredentialがないため本調査ではlive clusterへの書き込み試験は実行しておらず、これはcutover直前の必須作業として残る。

**現時点の判定は「ソースとupstreamの対応表では適合、live cluster試験は未実施」**である。CockroachDB accountと接続secretを作らずに本番相当migrationを確認することはできないため、「確認済み」を静的互換性と実接続互換性に分ける。上記5項目をlive clusterで通すまではDB接続先を切り替えない。

## 1 GB を超える有力候補

| 候補                                                                                                          |                                     無料 DB 容量 | PostgreSQL 互換性                             | アプリも無料         | 重要な制約                                                                                 | 判定                       |
| ------------------------------------------------------------------------------------------------------------- | -----------------------------------------------: | --------------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------ | -------------------------- |
| [CockroachDB Cloud Basic](https://www.cockroachlabs.com/pricing/)                                             |                                           10 GiB | wire protocol／多くの SQL は互換。ただし別 DB | なし                 | PostgreSQL 拡張、細かな型・DDL・locking semantics に差                                     | **互換試験できれば有力**   |
| [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)                                                  | Block Volume 合計 200 GB（OS・DB・アプリで共有） | VM 上の本物の PostgreSQL                      | VM／ARM Compute あり | managed DB ではない。Always Free capacity 不足、アカウント停止、リージョン制約の報告に注意 | **運用できるなら最大容量** |
| [Google Cloud Free Program](https://cloud.google.com/free/docs/free-cloud-features)                           |             Standard Persistent Disk 30 GB-month | VM 上の本物の PostgreSQL                      | `e2-micro` 1台       | 対象 US リージョン限定、外向き通信上限、RAM 約 1 GB。Cloud SQL は無料対象外                | **低負荷・自己運用向け**   |
| [CockroachDB self-hosted](https://www.cockroachlabs.com/docs/stable/deploy-cockroachdb-on-premises) + 上記 VM |                                VM のディスク次第 | PostgreSQL 互換 DB                            | 同じ VM              | 単一ノードでは耐障害性を失い、PostgreSQL より重い                                          | 特殊用途のみ               |

## アプリ無料枠との組み合わせ

DB とアプリを別事業者にするとネットワーク遅延と egress が増えるため、同一または近接リージョンを選ぶ。

| アプリ基盤                                                                        | 無料枠の概要                          | DB の置き方                    | 注意点                                                                 |
| --------------------------------------------------------------------------------- | ------------------------------------- | ------------------------------ | ---------------------------------------------------------------------- |
| [Koyeb](https://www.koyeb.com/pricing)                                            | Free Web Service あり                 | CockroachDB を外部接続         | PoC／個人用途向け。低い CPU／RAM、scale-to-zero、帯域の制約を確認      |
| [Render](https://render.com/pricing)                                              | Free Web Service あり                 | 外部 DB 推奨                   | idle 時の spin-down と再起動遅延。Free Postgres は永続移行先にしにくい |
| [Cloudflare Workers](https://developers.cloudflare.com/workers/platform/pricing/) | 1日単位の request／CPU 無料枠         | Hyperdrive 経由または HTTP API | Node.js 常駐サーバーとは実行モデルが異なる。TCP 直結可否を設計時に確認 |
| [Deno Deploy](https://deno.com/deploy/pricing)                                    | request／転送量等の Free 枠           | 外部 DB                        | Deno runtime への適合が必要                                            |
| [Vercel Hobby](https://vercel.com/pricing)                                        | serverless／edge の Hobby 枠          | Marketplace または外部 DB      | 非商用条件、function duration、帯域、接続数に注意                      |
| [Netlify Free](https://www.netlify.com/pricing/)                                  | Functions／Web 配信の Free 枠         | 外部 DB                        | credit 制の上限と DB connection pooling を確認                         |
| Oracle Always Free VM                                                             | VM 内にアプリと PostgreSQL を同居     | localhost                      | 単一障害点。最低でも外部 object storage へ暗号化 backup                |
| Google Cloud `e2-micro`                                                           | VM 内に軽量アプリと PostgreSQL を同居 | localhost                      | メモリ不足対策が必須。Docker 多段構成は特に厳しい                      |

汎用的な候補一覧としては上表のとおりだが、この構成では **Fly appを維持し、AgentsViewだけCockroachDBへ分離**を先に検証する。appも移すならCloud Runを利用するが、DBはAgentsView用CockroachDBとAtuin用PostgreSQLに分ける。PostgreSQLの完全互換が必須で自己運用可能なら **Oracle Always Free VM + PostgreSQL**を選ぶ。

## 候補にはなるが「1 GB 超の恒久無料」を満たさないサービス

比較対象を多く残すため、不採用理由も記録する。

| サービス                                                                                                 | 無料枠／状態                                            | 今回の評価                                                                                     |
| -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [Neon Free](https://neon.com/pricing)                                                                    | Free あり。project、compute、storage、history に上限    | serverless PostgreSQL として優秀だが、単一 DB で Fly.io の 1 GB を確実に上回るか現行表を再確認 |
| [Supabase Free](https://supabase.com/pricing)                                                            | DB 500 MB 級の Free 枠                                  | 1 GB より小さい。Auth／Storage／Realtime をまとめたい場合のみ                                  |
| [Prisma Postgres](https://www.prisma.io/pricing)                                                         | Free plan あり                                          | operation 数と storage 上限を要確認。1 GB 超を主目的に即決しない                               |
| [Nile](https://www.thenile.dev/pricing)                                                                  | Free plan あり                                          | tenant 特化。容量、compute 時間、製品成熟度を要検証                                            |
| [Koyeb Database](https://www.koyeb.com/pricing)                                                          | Free database が提供される時期・条件あり                | 1 GB 前後なら今回の容量問題を先送りするだけ                                                    |
| [Render Postgres](https://render.com/docs/free#free-postgres-databases)                                  | Free DB は容量・期限・失効条件あり                      | production の恒久移行先には不向き                                                              |
| [Railway](https://railway.com/pricing)                                                                   | credit／trial 型                                        | 恒久無料枠として予算を組まない。小額従量課金を許容するなら簡単                                 |
| [Aiven](https://aiven.io/pricing)                                                                        | trial／credit の提供あり                                | trial 終了後は有料。managed 品質重視なら有料候補                                               |
| [Heroku Postgres](https://www.heroku.com/pricing)                                                        | Eco／Mini 等は有料                                      | 無料前提を満たさない                                                                           |
| [DigitalOcean Managed Databases](https://www.digitalocean.com/pricing/managed-databases)                 | 有料                                                    | 無料前提を満たさない                                                                           |
| [Crunchy Bridge](https://www.crunchydata.com/products/crunchy-bridge/pricing)                            | trial 後は有料                                          | PostgreSQL 品質は高いが無料前提を満たさない                                                    |
| [Amazon RDS](https://aws.amazon.com/rds/free/)                                                           | 新規アカウントの期間・credit 型無料                     | 永続的な無料移行先ではない                                                                     |
| [Azure Database for PostgreSQL](https://azure.microsoft.com/pricing/details/postgresql/flexible-server/) | trial credit／期間限定施策                              | 永続的な無料移行先ではない                                                                     |
| [Google Cloud SQL](https://cloud.google.com/sql/pricing)                                                 | trial credit は使えるが Always Free 対象外              | VM セルフホストなら無料枠内、managed Cloud SQL は不可                                          |
| [ElephantSQL](https://www.elephantsql.com/)                                                              | サービス終了                                            | 新規候補から除外                                                                               |
| [Tembo](https://tembo.io/)                                                                               | 提供形態が変化                                          | 古い無料枠紹介を信用せず、現行提供状況を確認                                                   |
| [PlanetScale](https://planetscale.com/pricing)                                                           | PostgreSQL ではなく主に Vitess/MySQL 系、無料条件も変化 | PostgreSQL 移行先ではない                                                                      |
| [Turso](https://turso.tech/pricing)                                                                      | SQLite/libSQL                                           | 容量は魅力的でも PostgreSQL ではない                                                           |
| [Cloudflare D1](https://developers.cloudflare.com/d1/platform/pricing/)                                  | SQLite 系 serverless DB                                 | PostgreSQL ではない。SQL／migration の作り直しが必要                                           |
| [MongoDB Atlas](https://www.mongodb.com/pricing)                                                         | Free cluster あり                                       | document DB。データモデル変更が必要                                                            |

## 移行前に、まず Fly.io 側で確認すること

Fly Volume の 90% 使用はユーザーが確認した値であり、下記 SQL から算出した値ではない。実データ、不要 index、table bloat、WAL、ログ、古い job データのどれが占めているかを実測する。移行しても増加原因は残るため、先に内訳を取る。

まず `fly ssh console -a psgl` で DB Machine に入り、mount point は `fly.toml`／`mount` の構成に合わせて、例えば `df -h /data` と `du -xhd1 /data` を実行する。Fly Metrics の filesystem 使用量とも照合する。`pg_database_size` は database object の容量であり、Fly Volume 全体、WAL、DB 外のログを表さない。

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
3. **CockroachDB に schema を投入** — `pg_dump --schema-only` から始め、DDL error を一覧化する。
4. **匿名化した production 相当データで試験** — 容量だけでなく query latency、index、transaction、migration、connection pooling を測る。
5. **restore rehearsal** — backup を「取れた」ではなく、新しい空 DB に restore して件数と checksum を照合する。
6. **短時間の書き込み停止で cutover** — 標準手順は Atuin sync／AgentsView push を止め、最終 dump／restore、row count と主要値の照合、接続先変更、smoke test の順とする。dual-write は採用しない。
7. **rollback window を確保** — Fly.io 側を即削除せず、規約と費用が許す期間 read-only で保持する。

dual-write が不可避なら、両 DB への書き込みを冪等にし、片側失敗の retry queue、再同期、遅延監視を実装する。cutover 時点を記録して行単位の key／更新時刻／checksum を照合し、rollback 時は新 DB で発生した書き込みを旧 DB へ逆同期してから戻す。これらを rehearsal で検証できない場合は dual-write を行わない。

### 最低限の受け入れテスト

- schema、row count、主要 aggregate の一致
- timezone、collation、case sensitivity、sequence／identity の一致
- transaction isolation、unique／foreign key、advisory lock の挙動
- ORM migration と connection pool（PgBouncer 対応を含む）
- cron／queue worker／background job の二重実行防止
- backup export と restore、障害時の連絡経路
- 無料上限到達時が「課金」「read-only」「停止」「削除」のどれか

## 最終判断

- **最小の変更でmanagedを維持:** AgentsView schemaだけCockroachDB Cloud Basicへ移し、Atuinは既存PostgreSQLに残す。
- **CockroachDBの対象:** upstreamが対応を明記するAgentsViewだけ。Atuinには使用しない。
- **月額 0 円と容量を最優先し、Linux／DB を運用可能:** Oracle Cloud Always Free VM。
- **DBだけ移す:** Fly app 2個は維持し、AgentsView DBだけCockroachDBへ移す。Fly computeの実請求が0円か毎月確認する。
- **appも移す:** Cloud Runに2サービスを置き、AgentsViewはCockroachDB、Atuinは本物のPostgreSQLへ接続する。billing account、egress、cold startを監視する。
- **本番データが重要:** 無料枠だけで決めない。安価な paid PostgreSQL は、バックアップ、PITR、SLA、サポート、突然の無料枠変更リスクを含めると総コストが低い場合が多い。
