# AgentsViewをCloud Run／CockroachDBへ移行する手順

対象構成:

- Atuin app／PostgreSQL: Fly.ioに残す
- AgentsView app: Google Cloud Runへ移す
- AgentsView DB: Fly PostgreSQLの`agentsview` schemaからCockroachDB Cloud Basicへ移す

この手順は、旧Fly DBを保持したまま検証し、最後にAgentsViewの書き込み先とviewerを切り替える。Atuinのdatabase／role／appには触れない。

## 実装済みファイル

| ファイル                                                | 目的                                                                        |
| ------------------------------------------------------- | --------------------------------------------------------------------------- |
| `dot_config/agentsview/Dockerfile`                      | upstream AgentsView imageをArtifact RegistryへmirrorするCloud Build context |
| `dot_config/agentsview/cloudrun.env.yaml`               | Cloud Runの非secret環境変数                                                 |
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

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<small-project>'
fnox exec -- mise run agentsview:cockroach:migrate
```

taskは次を順に行う。

1. `flyctl proxy`で旧Fly PostgreSQLへ接続する。
2. AgentsView自身の`pg push`でCockroachDB用schemaを作成する。
3. Flyの`agentsview` schemaをdata-only／column insert形式でprivate backupへ保存する。
4. `ON CONFLICT DO NOTHING`付きでCockroachDBへrestoreする。
5. source／targetのtable一覧と正確な`count(*)`を比較する。
6. 不一致なら非zero終了し、Flyをsource of truthのまま維持する。

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
4. `agentsview:cockroach:migrate`を再実行して最終差分をcopyする。
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

削除前にCloud Run URL、GitHub Actions deploy、各PCからのpushがすべて正常であることを再確認する。
