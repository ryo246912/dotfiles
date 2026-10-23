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

|  順位 | アプリ                                                                         | DB                                                  | 月額 0 円にする条件                                      | 選ぶ理由                                                                     |
| ----: | ------------------------------------------------------------------------------ | --------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **1** | **AgentsViewだけ[Google Cloud Run](https://cloud.google.com/run/pricing)**     | **AgentsViewはCockroachDB、Atuin app／DBはFly**     | Cloud RunとFly appが各無料枠内。billing accountは必要    | 採用構成。Fly DBを非公開のままAgentsView dataを10 GiB枠へ分離できる          |
| **2** | **Atuin と AgentsView は Fly.io に残す**                                       | **AgentsView はCockroachDB、Atuinは既存PostgreSQL** | 現在のFly app computeが無料allowance／credit内であること | Cloud Runで問題が起きた場合のrollback／暫定構成                              |
| **3** | **[Northflank Developer Sandbox](https://northflank.com/pricing) に2サービス** | **AgentsViewはCockroachDB、Atuinは別のPostgreSQL**  | 現行Sandboxが2サービスを許容し、compute／egress上限内    | appはまとめられるが、Atuin DBにはCockroachDBを使わない                       |
| **4** | **Atuin は Koyeb、AgentsView は Render（PoC／個人用途のみ）**                  | **AgentsViewはCockroachDB、AtuinはPostgreSQL**      | 各社のfree web serviceと通信枠内                         | 低いCPU／RAM、休止、月間instance-hoursの制約があり、本番の可用性は期待しない |
| **5** | **Oracle Always Free VM に両アプリと PostgreSQL**                              | VM 内 PostgreSQL                                    | Always Free compute／block volume 内                     | 最大容量。ただし managed ではなく、単一 VM の保守と backup は自己責任        |

**確定案は「Atuin app／DBはFly.ioを維持 + AgentsView appはCloud Run + AgentsView DBはCockroachDB」**であり、移行は完了している（Fly上のAgentsView appは削除済み）。

### Cloud Run はどの程度まで無料か

- AgentsViewは`ghcr.io/kenn-io/agentsview`の既存OCI imageを利用できる。
- AgentsViewだけを1サービスとしてscale-to-zeroでき、Atuinは現在のFly app設定を維持する。
- AgentsViewは現在と同じ8080を利用できる。
- AgentsViewのDB接続だけCockroachDB Cloudのpublic TLS endpointへ変更する。Atuinは引き続きFly private hostnameの`psgl.flycast`とprivate network用設定を使う。

AgentsView viewerのCloud Run computeは無料枠に収まりやすいものの、**Cloud RunとCockroachDB Cloud間のDB trafficはexternal egressになり得る**。無料枠は保存容量だけでなくegressも監視する。CockroachDB Cloudと同じ／近いリージョンが選べない場合はlatencyも実測する。CockroachDB BasicはInternetから到達できるpublic TLS endpointであり、TLSと認証は通信を保護するがendpoint自体をprivateにはしない。

[Cloud Run の公式料金表](https://cloud.google.com/run/pricing)で request-based billing に毎月付く無料枠は、billing account 全体で **180,000 vCPU-seconds、360,000 GiB-seconds、200万requests**。1 vCPU／512 MiBならCPU枠が先に尽き、**billing account全体で約50 vCPU-hours／月**が目安となる。

| AgentsViewの使い方        |             概算CPU時間 | 判定             |
| ------------------------- | ----------------------: | ---------------- |
| 1万requests／月、平均1秒  |  約2.8時間 + cold start | 十分余裕あり     |
| 10万requests／月、平均1秒 | 約27.8時間 + cold start | 無料枠内の見込み |
| 1万requests／月、平均5秒  | 約13.9時間 + cold start | 無料枠内の見込み |
| 常時接続requestが1本      |           月730時間相当 | 無料にならない   |

必要時だけ開く個人用AgentsViewであれば、50時間のbillable CPU枠には通常余裕がある。ただしrepositoryだけから実trafficは確定できない。Cloud Run移行後は `container/billable_instance_time`、request count、outbound data transferにbudget alertを設定する。AgentsViewの画面やSSEを常時開く運用は避け、`min-instances=0`、request-based billingを維持する。外向き通信の無料条件はcompute枠とは別で、公式料金表はNorth America内のdata transferについて月1 GiBの無料枠を記載しているため、東京から外部DBへのegressが必ず無料とはみなさない。

したがって、**AgentsViewを閲覧時だけ起動する個人利用なら、月1万requests・平均5秒（約13.9 vCPU-hours）程度までは、cold startを加えても50 vCPU-hoursに対して約36時間の余裕がある**。月10万requests・平均1秒でも約22時間の余裕がある。一方、画面の常時接続、`min-instances=1`、instance-based billingのいずれかを使うと、この見積もりは適用できない。

これはrequest数と処理時間から出した上限見積もりであり、現在のFly Metricsを取得した実測値ではない。この実行環境には`flyctl`と利用者のFly／Google Cloud credentialがないため、現行trafficとの照合やCloud Runへの実deployは実行していない。移行判断前にFly Metricsの直近30日について、AgentsViewのrequest数、平均／p95 duration、egressを上表へ代入する。

### 希望構成: Cloud Run 2サービス + AgentsViewはCockroachDB + Atuin DBだけFly.io

Atuin DBだけをFly.ioに残し、Atuin appをCloud Runへ移す構成は、**現在の`psgl.flycast`を使うままでは接続できない**。`*.flycast`はFly private network内のaddressであり、Google Cloud Runから直接routeできないためである。

```text
Internet
  ├─ Cloud Run: agentsview
  │    └─ public TLS → CockroachDB Cloud Basic
  └─ Cloud Run: atuin
       └─ 到達不可 → psgl.flycast:5432（Fly private network）
```

#### 実現方法と判定

| 方法                                                  | 月額0円                                                       | security／運用                                              | 判定               |
| ----------------------------------------------------- | ------------------------------------------------------------- | ----------------------------------------------------------- | ------------------ |
| Fly PostgreSQLをpublic TCP/TLSで公開                  | public IPv4、egress等が課金され得る                           | Cloud Runの送信元IPは標準では固定されず、広い公開範囲が必要 | **非推奨**         |
| Cloud Runにstatic outbound IPを付け、Fly側でallowlist | Cloud NAT等の費用が発生                                       | public TLSとfirewallを適切に構成可能                        | 有料なら可能       |
| Cloud RunからFly WireGuardへ接続                      | Cloud Runの実行制約とephemeral instance上でのtunnel運用が複雑 | reconnect、key、health check、scale-outを自己管理           | **本番非推奨**     |
| Fly上にTCP proxy／tunnel appを追加                    | Fly app computeとnetwork費用次第                              | proxyが新たな単一障害点                                     | 移行の利点が小さい |
| Atuin appもFlyに残す                                  | 現在のFly allowance内なら0円                                  | `psgl.flycast`をprivateのまま利用可能                       | **推奨**           |

Cloud Runの送信元IPを固定する標準構成は、Direct VPC egressの`all-traffic`とCloud NAT／static external IPを組み合わせる。これは「無料だけ」という要件には適さない。送信元を固定せずFly PostgreSQLの5432をInternet全体へ公開する方法も技術的には可能だが、databaseを直接攻撃対象にするため採用しない。

#### 無料を優先する確定構成

```text
Fly.io
  └─ Atuin app
       └─ psgl.flycast（既存Fly PostgreSQL／Atuin dataのみ）

Google Cloud Run
  └─ AgentsView app
       └─ public TLS → CockroachDB Cloud Basic（AgentsView data）
```

この構成ならAgentsView dataをCockroachDBへ移すことでFly volumeを空けながら、Atuinのapp／DB間通信はprivateのまま維持できる。Fly側に残るのはAtuin appとAtuin DBであり、「Atuin DBだけFlyに残す」構成にはならないが、**無料・security・運用の単純さを同時に満たす最も近い構成**である。

どうしてもAtuin appもCloud Runへ移す場合は、次のどちらかを選ぶ。

1. Atuin DBをGCE Always Free `e2-micro`上のPostgreSQLへ移し、Direct VPC egressでprivate接続する。
2. Cloud NAT／static IP等の少額課金を許容し、Fly PostgreSQLをTLS、固定送信元allowlist、最小権限role付きで公開する。

したがって、月額0円を絶対条件とする本稿の最終推奨は、**Atuin app + Atuin DBはFly.io、AgentsView appはCloud Run、AgentsView DBはCockroachDB Cloud Basic**とする。

### アプリごとの配置条件

#### Atuin

- appもFly.ioに残し、現在のcontainer command `server start`を維持する。
- `ATUIN_HOST=0.0.0.0`、`ATUIN_PORT=8888`、`ATUIN_OPEN_REGISTRATION=false`を変更しない。
- database URLは現在の`psgl.flycast`を使い、Atuin専用database／roleへ接続する。AgentsView schemaを移行・検証後にFly側から削除して容量を空ける。
- `auto_stop_machines="stop"`と`min_machines_running=0`を維持し、app computeがFly allowance内か毎月確認する。

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

```sql
SELECT COALESCE(sum(pg_total_relation_size(relid)), 0) AS agentsview_bytes
FROM pg_statio_user_tables
WHERE schemaname = 'agentsview';
```

```text
CockroachDB storage余裕 [GiB] = 10 - agentsview_bytes / 1024^3
概算の成長可能月数 = storage余裕 / AgentsView schemaの月間増加量 [GiB/月]
```

Request Unitsは保存容量と別の上限であり、repositoryから実際のquery回数は確定できない。無料を厳守する場合はCockroachDB Consoleで月次RU使用量とstorage alertを設定し、検証push後に増分を測る。Basicで無料分を超えた際の課金・停止設定は、cluster作成時の現行画面で確認する。

#### Atuin 18.8.0: 採用しない

[Atuin 18.8.0のPostgreSQL migration](https://github.com/atuinsh/atuin/tree/v18.8.0/crates/atuin-server-postgres/migrations)には、`CREATE OR REPLACE FUNCTION ... RETURNS trigger`、`LANGUAGE plpgsql VOLATILE COST 100`、`TG_OP`、`CREATE TRIGGER ... EXECUTE PROCEDURE`が含まれる。CockroachDBの一般的なwire compatibilityだけでは、このmigrationと将来のAtuin upgradeを保証できない。upstreamにもCockroachDBをsupported backendとする記載やtestを確認できなかったため、**Atuin DBはCockroachDBへ移さない**。
