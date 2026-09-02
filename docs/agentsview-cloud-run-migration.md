# AgentsViewをCloud Run／CockroachDBへ移行する手順

対象構成:

- Atuin app／PostgreSQL: Fly.ioに残す
- AgentsView app: Google Cloud Runへ移す
- AgentsView DB: Fly PostgreSQLの`agentsview` schemaからCockroachDB Cloud Basicへ移す

この手順は、旧Fly DBを保持したまま検証し、最後にAgentsViewの書き込み先とviewerを切り替える。Atuinのdatabase／role／appには触れない。

## AgentsView appの実行基盤はどれを選ぶか

調査日: **2026-09-02**

### 結論

この用途では、**Cloud Runを継続するのが第一候補**。Fly.ioよりログの検索・絞り込み・保持が扱いやすく、現在の実装をそのまま利用できる。個人用AgentsViewは常時接続を必要とせず、閲覧時だけ起動できるため、Cloud Runのscale-to-zeroと相性がよい。

「管理画面の分かりやすさ」を最優先してGoogle Cloud自体を避けたいなら、**Northflank Developer Sandboxを第二候補としてPoC**する。ただしDeveloper Sandboxは本番SLAを期待する基盤ではなく、無料枠やresource planの変更リスクがCloud Runより高い。単純なスペック表だけでNorthflankへ即移行せず、cold start、ログ保持期間、CockroachDBへのlatencyを実測してから決める。

### 比較表

無料枠は予告なく変わる。契約・移行直前に各公式Pricingを再確認する。ここでいう「スペック」は無料quotaまたは選択可能resourceの上限であり、専有CPU性能を保証しない。

|  順位 | 基盤                                                                                            | 無料computeの目安                                                                  | ログの使いやすさ                                                                            | AgentsViewとの相性                                                          | 判定                    |
| ----: | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ----------------------- |
| **1** | [Google Cloud Run](https://cloud.google.com/run/pricing)                                        | 月180,000 vCPU秒、360,000 GiB秒、200万request。現在は1 vCPU／512 MiB、min 0、max 2 | Cloud Run画面、Logs Explorer、CLI tail／read。構造化JSON、severity、request traceで検索可能 | 既存image／Secret Manager／deploy taskを実装済み。scale-to-zero可能         | **採用**                |
| **2** | [Northflank Developer Sandbox](https://northflank.com/pricing)                                  | Sandbox内のservice／CPU／memory quota。現行consoleで利用可能resource planを要確認  | app、build、deployment、logが一つのproject UIにまとまる                                     | OCI imageとsecretを登録しやすい。無料Sandboxの継続性・SLAは弱い             | **UI重視のPoC候補**     |
| **3** | [Azure Container Apps Consumption](https://azure.microsoft.com/pricing/details/container-apps/) | 月180,000 vCPU秒、360,000 GiB秒、200万request                                      | Portal／CLIでsystem logとconsole logを分離してlive stream可能                               | scale-to-zeroとsecret対応。Cloud Runから移す利益が小さく、Azure構築が増える | 既にAzureを使う場合のみ |
| **4** | [Koyeb Free](https://www.koyeb.com/pricing)                                                     | Free instanceは小さいCPU／memory枠。現行instance表を要確認                         | service画面でruntime logを見やすい                                                          | deployは簡単だが、CPU余裕とcold startはCloud Runより不利                    | hobby／検証用           |
| **5** | [Render Free](https://render.com/docs/free)                                                     | Free web service。idle時のspin-downや月間利用条件あり                              | dashboardからdeploy／runtime logを確認しやすい                                              | 操作は簡単だが、cold startと無料resourceが弱い                              | hobby／fallback         |
| **6** | Oracle Always Free VM                                                                           | VM quota内ならPaaSより大きいCPU／RAMを取れる場合がある                             | journald、rotation、検索、alertをすべて自分で構築                                           | raw specは強いが、今回避けたい運用・ログ監視負担が最大                      | **不採用**              |

### Cloud Runを選ぶ理由

1. **ログ監視がFly.ioより明確**: containerのstdout／stderrはCloud Loggingへ自動送信される。Cloud Run service画面で直近ログ、Logs Explorerで期間・severity・revision・文字列を絞り込める。
2. **CLIでも読める**: browserを開かず、次のcommandで直近ログと追従表示を使える。

   ```sh
   gcloud run services logs read ryo-agentsview \
     --project="$GCP_PROJECT_ID" --region="$GCP_REGION" --limit=100

   gcloud beta run services logs tail ryo-agentsview \
     --project="$GCP_PROJECT_ID" --region="$GCP_REGION"
   ```

   `logs tail`がcomponent不足を返す場合は、gcloudが案内するlog-streaming componentを追加する。CIでは追従表示を使わず、終了する`logs read`だけを使う。

3. **無料ログ枠に余裕がある**: [Cloud Logging pricing](https://cloud.google.com/logging/pricing)は通常log storageについて最初の50 GiB／project／月を無料とし、30日までの保存をingestion料金に含める。個人用AgentsViewのapp logは通常この規模を大幅に下回る。ただしaudit／network logや同一projectの他serviceも合算して監視する。
4. **必要時だけ高いresourceを使える**: 無料枠は固定の低spec VMを1か月占有する方式ではなく、request処理中のvCPU秒／GiB秒に充当される。現在の1 vCPU／512 MiBで不足したら、memoryを1 GiBへ上げて実測できる。ただし1 GiBは無料memory秒を2倍消費する。
5. **既存実装を再利用できる**: build、Secret Manager mount、read-only CockroachDB URL、min 0／max 2、deploy taskが既にこのrepositoryにある。別PaaSへ移るとsecret、domain、health check、logging、rollbackをもう一度検証する必要がある。

### Cloud Runの弱点と対策

| 弱点                                               | 対策                                                                                                      |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Google Cloud Consoleは機能が多く、最初は画面が複雑 | 日常操作を`gcloud run services logs read`、`logs tail`、`mise run agentsview:cloudrun:deploy`へ限定する   |
| scale-to-zero後にcold startがある                  | 個人viewerでは許容する。常時`min=1`にはせず無料を維持する                                                 |
| CockroachDBへの通信はexternal egress               | 同一または近いregionを選び、Cloud BillingとCockroachDB Consoleの転送量を監視する                          |
| `--allow-unauthenticated`でURL自体は公開           | AgentsViewの`require_auth=true`と長いbearer tokenを維持し、未認証APIが401になることをdeployごとに確認する |
| Logs Explorerのqueryに慣れが必要                   | service名とseverityを固定したsaved queryを作り、error alertだけ先に設定する                               |

推奨saved query:

```text
resource.type="cloud_run_revision"
resource.labels.service_name="ryo-agentsview"
severity>=ERROR
```

最低限、次をalert／budget対象にする。

- Cloud Run revisionの5xx response
- container startup失敗とCockroachDB接続失敗
- request latencyのp95
- instance countとbillable instance time
- Cloud Logging ingestion量
- CockroachDB RU、storage、connection数

### Northflankへ変更する判断基準

次をすべて満たす場合だけ、Cloud RunからNorthflankへ移す価値がある。

1. 現行Developer SandboxでAgentsView containerに512 MiB以上を割り当てられる。
2. idle／sleep後の起動時間がCloud Runより短い、または許容範囲である。
3. runtime logの保持期間、検索、downloadが必要条件を満たす。
4. CockroachDB regionへのp95 latencyとegress条件がCloud Run以下である。
5. 無料枠超過時が自動課金、停止、削除のどれになるか確認した。
6. `require_auth`、secret file mount相当、read-only DB URL、rollback用旧revisionを再現できる。

NorthflankはUIの分かりやすさでは魅力があるが、今回の目的は「無料・ログ改善・十分なspec・安全な移行」を同時に満たすこと。**現状ではCloud Runのままログ操作をCLI／saved queryへ整備する方が、再移行より低リスク**である。

## 実装済みファイル

| ファイル                                                | 目的                                                                        |
| ------------------------------------------------------- | --------------------------------------------------------------------------- |
| `dot_config/agentsview/Dockerfile`                      | upstream AgentsView imageをArtifact RegistryへmirrorするCloud Build context |
| `dot_config/agentsview/cloudrun.env.yaml`               | Cloud Runの非secret環境変数                                                 |
| `dot_config/agentsview/scripts/deploy-cloud-run.sh`     | 同じ設定でbuild／Cloud Run deployを行う共通script                           |
| `dot_config/agentsview/scripts/migrate-to-cockroach.sh` | Flyからdata-only dumpを取得し、CockroachDBへ冪等restoreして件数比較         |
| `dot_config/mise/tasks/agentsview.toml`                 | secret登録、deploy、migration、status、push task                            |

## 0. 変更前の安全確認

1. Atuin／AgentsViewへの書き込みはまだ止めない。
2. Fly volumeとschema容量を記録する。

```sh
fly ssh console -a psgl -C 'df -h /data'
flyctl proxy 15432:5432 -a psgl
```

別terminalで、ownerまたはread可能なroleを使用する。

```sql
SELECT pg_size_pretty(pg_database_size(current_database()));
SELECT pg_size_pretty(COALESCE(sum(pg_total_relation_size(relid)), 0))
FROM pg_statio_user_tables
WHERE schemaname = 'agentsview';
```

3. Fly PostgreSQL全体とAgentsView schemaのbackupを別々に取得する。passwordをcommand historyへ直接書かない。

```sh
umask 077
mkdir -p ~/backup
fnox exec -- sh -c '
  PGDATABASE="$AGENTSVIEW_OWNER_PROXY_PG_URL" pg_dump -Fc \
    -f "$HOME/backup/fly-all-$(date -u +%Y%m%dT%H%M%SZ).dump"
  PGDATABASE="$AGENTSVIEW_OWNER_PROXY_PG_URL" pg_dump -Fc -n agentsview \
    -f "$HOME/backup/agentsview-$(date -u +%Y%m%dT%H%M%SZ).dump"
'
```

4. backupを空の検証PostgreSQLへrestoreできることを確認する。backup fileを作っただけでは合格にしない。

## 1. CockroachDB Cloud Basicを作成

1. CockroachDB CloudでBasic clusterを作る。
2. Cloud Runから近いregionを選ぶ。
3. monthly usage limit／alertを設定し、10 GiB storageと5,000万RUの無料枠を監視する。
4. SQL consoleでowner、push、read用userを分けて作る。passwordはそれぞれ異なるrandom valueにする。

```sql
CREATE USER agentsview_owner WITH PASSWORD '<owner-password>';
CREATE USER agentsview_push WITH PASSWORD '<push-password>';
CREATE USER agentsview_read WITH PASSWORD '<read-password>';

GRANT CREATE ON DATABASE defaultdb TO agentsview_owner;
```

schema bootstrap後に次を実行する。CockroachDB versionによって`ALL TABLES IN SCHEMA`／default privilegeの対応が異なる場合は、Consoleが示す現行syntaxに合わせる。

```sql
GRANT USAGE ON SCHEMA agentsview TO agentsview_push, agentsview_read;
GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push;
```

5. `sslmode=verify-full`を含む3本のconnection URLをBitwarden Secrets Managerへ登録する。

| secret名                            | user               | 用途                            |
| ----------------------------------- | ------------------ | ------------------------------- |
| `AGENTSVIEW_COCKROACH_OWNER_PG_URL` | `agentsview_owner` | schema bootstrap／migrationのみ |
| `AGENTSVIEW_COCKROACH_PUSH_PG_URL`  | `agentsview_push`  | 各PCの`pg push`                 |
| `AGENTSVIEW_COCKROACH_READ_PG_URL`  | `agentsview_read`  | Cloud Run viewer                |

## 2. Google Cloudを準備

以下は一度だけ実行する。値は自分のprojectへ置き換える。

```sh
export GCP_PROJECT_ID='<project-id>'
export GCP_REGION='us-central1'
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

gcloud config set project "$GCP_PROJECT_ID"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  iamcredentials.googleapis.com

gcloud artifacts repositories create agentsview \
  --repository-format=docker \
  --location="$GCP_REGION"

gcloud iam service-accounts create agentsview-runtime \
  --display-name='AgentsView Cloud Run runtime'
```

Secret Managerから読めるのはruntime service accountだけにする。

```sh
for secret in agentsview-pg-url agentsview-config-toml; do
  gcloud secrets create "$secret" --replication-policy=automatic 2>/dev/null || true
  gcloud secrets add-iam-policy-binding "$secret" \
    --member="serviceAccount:${GCP_RUNTIME_SERVICE_ACCOUNT}" \
    --role=roles/secretmanager.secretAccessor
done
```

任意でGitHub Actionsからdeployする場合は、Workload Identity Federationを作り、deploy service accountへ最低限次の権限を付ける。現在の`.github/workflows/deploy-agentsview.yaml`は移行完了までFly rollback用として残すため、自動deployは有効化せず、まず`mise run agentsview:cloudrun:deploy`を使う。

- `roles/run.admin`
- runtime accountに対する`roles/iam.serviceAccountUser`
- `roles/cloudbuild.builds.editor`
- Artifact Registryへimageを書ける権限

以下はこのrepository専用providerを作る例。既存poolがある場合は再利用し、名前を読み替える。

```sh
export GITHUB_REPOSITORY='ryo246912/dotfiles'
export WIF_POOL='github'
export WIF_PROVIDER='dotfiles'
export GCP_PROJECT_NUMBER=$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')
export GCP_DEPLOY_SERVICE_ACCOUNT="agentsview-deploy@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create agentsview-deploy \
  --display-name='AgentsView GitHub deploy'

gcloud iam workload-identity-pools create "$WIF_POOL" \
  --location=global \
  --display-name='GitHub Actions'

gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER" \
  --location=global \
  --workload-identity-pool="$WIF_POOL" \
  --issuer-uri='https://token.actions.githubusercontent.com' \
  --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository' \
  --attribute-condition="assertion.repository == '${GITHUB_REPOSITORY}'"

gcloud iam service-accounts add-iam-policy-binding "$GCP_DEPLOY_SERVICE_ACCOUNT" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${GCP_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/attribute.repository/${GITHUB_REPOSITORY}"

for role in roles/run.admin roles/cloudbuild.builds.editor; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${GCP_DEPLOY_SERVICE_ACCOUNT}" \
    --role="$role"
done

gcloud iam service-accounts add-iam-policy-binding "$GCP_RUNTIME_SERVICE_ACCOUNT" \
  --member="serviceAccount:${GCP_DEPLOY_SERVICE_ACCOUNT}" \
  --role=roles/iam.serviceAccountUser

build_sa=$(gcloud builds get-default-service-account)
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:${build_sa}" \
  --role=roles/artifactregistry.writer

export GCP_WORKLOAD_IDENTITY_PROVIDER=$(
  gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER" \
    --location=global \
    --workload-identity-pool="$WIF_POOL" \
    --format='value(name)'
)
```

後からCloud Run用workflowを有効化する場合は、GitHub repositoryのproduction environmentへ次を登録する。

| 種別     | 名前                             | 内容                          |
| -------- | -------------------------------- | ----------------------------- |
| variable | `GCP_PROJECT_ID`                 | Google Cloud project ID       |
| variable | `GCP_REGION`                     | 例: `us-central1`             |
| variable | `GCP_RUNTIME_SERVICE_ACCOUNT`    | runtime service account email |
| secret   | `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name    |
| secret   | `GCP_SERVICE_ACCOUNT`            | deploy service account email  |

上の例では`GCP_WORKLOAD_IDENTITY_PROVIDER`の出力と`GCP_DEPLOY_SERVICE_ACCOUNT`を、それぞれ同名のGitHub secretへ登録する。

service-account key JSONは作らない。GitHub ActionsはOIDCの短命credentialを使う。

## 3. CockroachDB schemaをbootstrapしてデータをcopy

### 3.1 小さいprojectでbootstrap

`AGENTSVIEW_MIGRATION_PROJECTS`には、最初に試す小さいprojectを1つ指定する。

dump後の件数比較を決定的にし、copy中の更新を落とさないため、全PCの`agentsview pg push`、`agentsview pg watch`、定期実行を一時停止する。Atuinは別schemaへ書くため停止不要。停止を確認したoperatorだけが確認変数を設定する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<small-project>'
export AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes
fnox exec -- mise run agentsview:cockroach:migrate
```

taskは次を順に行う。

1. `flyctl proxy`で旧Fly PostgreSQLへ接続する。
2. AgentsView自身の`pg push`でCockroachDB用schemaを作成する。
3. Flyの`agentsview` schemaをdata-only／column insert形式でprivate backupへ保存する。
4. `ON CONFLICT DO NOTHING`付きでCockroachDBへrestoreする。
5. source／targetのtable一覧と正確な`count(*)`を比較する。
6. 不一致なら非zero終了し、Flyをsource of truthのまま維持する。

`AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes`がなければscriptはcopy前に停止する。これは自動的にwrite processを検出した印ではなく、operatorが全端末の停止を確認したという明示的な承認である。検証copy後は旧Flyへのpushを再開してよいが、cutover時には再度停止して最終copyする。

dumpは`~/backup/agentsview-fly-<UTC timestamp>.sql`へmode 0600で残る。このfileにはsession内容が含まれるためcommit、共有、cloud uploadをしない。

### 3.2 内容も照合

taskは全tableの`count(*)`を比較する。最終判断では、主要tableの最大更新時刻と代表sessionの内容もsource／targetで比較する。

```sql
SELECT count(*) FROM agentsview.sessions;
SELECT count(*) FROM agentsview.messages;
```

実際のtable名は次で確認する。

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'agentsview'
ORDER BY table_name;
```

さらに各PCからCockroachDBへ直接接続できることを確認する。

```sh
fnox exec -- mise run agentsview:cockroach:status
fnox exec -- mise run agentsview:cockroach:push -- --projects '<small-project>'
```

semantic／hybrid searchを利用している場合、CockroachDBではpgvectorが使えないためここで中止する。利用しない場合は、vector searchが`501 Not Available`になる機能差を受け入れて先へ進む。

## 4. Cloud Run secretとserviceを作成

初回はCloud Run URLがまだないため、config作成用に一時URLを指定する。

```sh
export GCP_PROJECT_ID='<project-id>'
export GCP_REGION='us-central1'
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
export AGENTSVIEW_CLOUD_RUN_URL='https://invalid.example'

fnox exec -- mise run agentsview:cloudrun:secrets
mise run agentsview:cloudrun:deploy
```

実URLを取得し、config secretを更新して新revisionをdeployする。

```sh
export AGENTSVIEW_CLOUD_RUN_URL=$(
  gcloud run services describe ryo-agentsview \
    --project="$GCP_PROJECT_ID" --region="$GCP_REGION" \
    --format='value(status.url)'
)
fnox exec -- mise run agentsview:cloudrun:secrets
mise run agentsview:cloudrun:deploy
```

Cloud Runでは次のようにsecretを注入する。

- `AGENTSVIEW_PG_URL`: Secret Managerの`agentsview-pg-url`を環境変数として参照
- `/data/config.toml`: `agentsview-config-toml`をread-only secret volumeとしてmount

`--allow-unauthenticated`はCloud Run URLへの到達だけを許可する。AgentsView自身の`require_auth=true`とbearer tokenは維持する。

## 5. Cloud Runを検証

```sh
url=$(gcloud run services describe ryo-agentsview \
  --project="$GCP_PROJECT_ID" --region="$GCP_REGION" \
  --format='value(status.url)')

curl -i "$url/api/v1/sessions"                    # 401を期待
fnox exec -- sh -c 'curl -fsS -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$url"'/api/v1/sessions" >/dev/null'
curl -I "$url"                                    # UI応答を確認
```

Google Cloud Consoleで次も確認する。

- `min instances = 0`、`max instances = 2`
- memory 512 MiB、CPU 1、request-based billing
- runtime service accountが`agentsview-runtime`
- secretの値がlogへ出ていない
- CockroachDB RU、storage、connection数が無料枠内

## 6. Cutover

1. 全PCで旧`mise run agentsview:pg:push`の実行を止める。
2. Fly AgentsView appを停止し、旧viewerからのreadを止める。
3. cutover UTC timestampを記録する。
4. `AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes`を設定し、`agentsview:cockroach:migrate`を再実行して最終差分をcopyする。
5. 厳密row countと主要sessionの内容を比較する。
6. 各PCの通常taskを`agentsview:cockroach:push`へ切り替える。
7. Cloud Run viewerで認証、session一覧、detail、analytics、usageをsmoke testする。
8. smoke test合格後だけCockroachDBへのpushを再開する。

旧Fly schemaはこの時点で削除しない。

## 7. Rollback

### 新DBへのpush再開前

Cloud Run smoke testに失敗したら、pushを再開せず、各PCの接続先を旧`AGENTSVIEW_PROXY_PG_URL`へ戻してFly viewerを再起動する。新規writeがないため逆同期は不要。

### 新DBへのpush再開後

1. 全PCのCockroachDB pushを停止する。
2. cutover timestamp以降のsession／messageをCockroachDBからexportする。
3. Fly schemaへimportする。
4. row count、primary key、最大更新時刻、代表session本文を照合する。
5. 合格後だけ旧Flyへのpushとviewerを再開する。

この差分export／importを事前rehearsalできない場合、新DBへのwrite再開後のrollbackは実施せず、CockroachDB側を修復する。

## 8. Flyの容量を解放

最低1〜2週間の観察期間を置き、全PCがCockroachDBへpushし、backup／restore rehearsalも成功してから実施する。

```sql
-- 最終確認。実行前に必ず最新backupを作る。
SELECT count(*) FROM agentsview.sessions;

-- owner接続で実行。CASCADE対象を表示・確認してから承認する。
DROP SCHEMA agentsview CASCADE;
```

通常の`VACUUM`はOSへdiskを返さない。Fly volumeの物理使用量をすぐ減らすための`VACUUM FULL`はlockと追加空き容量を必要とするため、空き10%の状態では実行しない。schema削除後の`df`、Fly Metrics、Atuin syncを確認し、必要ならmaintenance windowを別途設ける。

最後にFly AgentsView appを削除する。Atuin appと`psgl`は削除しない。

```sh
flyctl apps destroy ryo-agentsview
```

削除前にCloud Run URL、`mise run agentsview:cloudrun:deploy`（および任意で有効化したGitHub Actions deploy）、各PCからのpushがすべて正常であることを再確認する。
