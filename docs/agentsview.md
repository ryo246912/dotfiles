# agentsview pg-sync

複数端末のセッション情報を Fly.io 上の PostgreSQL に集約し、read-only Web UI で参照する構成。

> [!IMPORTANT]
> 後半のFly構成はmigration元とrollback用に残している。移行先は「Atuin app／DBはFlyのまま、AgentsView appはCloud Run、AgentsView DBはCockroachDB」である。新規構築は以下の[Cloud Run／CockroachDBへの移行手順](#cloud-runcockroachdbへの移行手順)を上から順に実行する。

## Cloud Run／CockroachDBへの移行手順

対象構成:

- Atuin app／PostgreSQL: Fly.ioに残す
- AgentsView app: Google Cloud Runへ移す
- AgentsView DB: Fly PostgreSQLの`agentsview` schemaからCockroachDB Cloud Basicへ移す

この手順は、旧Fly DBを保持したまま検証し、最後にAgentsViewの書き込み先とviewerを切り替える。Atuinのdatabase／role／appには触れない。

### ゼロから構築する場合の全体手順

この節から順番に実行すれば、空のGoogle Cloud projectとCockroachDB Cloud accountから、検証用Cloud Runを起動できる。**Fly側の削除は最後まで行わない。** コマンドはrepository rootから開始し、`<...>`は自分の値へ置き換える。

#### A. 完了条件と作業順序

以下の**作業1〜10を番号順に実行する**。各作業末尾の「完了確認」が通るまで次へ進まない。Google Cloud／CockroachDBのconsole表記は変更されることがあるため、表記が異なる場合は併記した公式documentへのlinkから同じ機能を開く。

##### 作業1. account、CLI、課金alertを準備する

###### Google CloudのUI操作

1. [Google Cloud Console](https://console.cloud.google.com/)へloginする。
2. 上部のproject selectorを開き、**NEW PROJECT／新しいプロジェクト**を押す。
3. Project nameに`agentsview`等を入力し、Organization／Locationを選択して**CREATE**を押す。
4. 作成したprojectを選び、**Billing > Link a billing account**からbilling accountを紐付ける。無料枠を使う場合もbillingの有効化は必要。
5. **Billing > Budgets & alerts > CREATE BUDGET**を開き、scopeをこのprojectだけに限定する。
6. 月額予算を自分が許容する最小額にし、50%／90%／100%通知を有効化する。budgetは課金を自動停止しないため、通知先emailも確認する。

###### CockroachDB CloudのUI操作

1. [CockroachDB Cloud Console](https://cockroachlabs.cloud/)へloginし、organizationを作成または選択する。
2. 左navigationの**Access Management > API Keys**を開く。
3. **Create API key**を押し、Terraform専用名を入力する。
4. cluster／SQL userを作成できるorganization権限だけを選び、keyを作成する。
5. 表示されたsecretは再表示できないため、直ちにBitwarden Secrets Managerへ`COCKROACH_API_KEY`として保存する。画面やterminalへ貼ったままにしない。

###### CLI準備

repository rootでtoolをinstallし、versionを確認する。

```sh
mise trust
mise install

git --version
mise --version
fnox --version
flyctl version
gcloud version
terraform version
psql --version
pg_dump --version
docker version
```

Google CloudとFly.ioへloginする。

```sh
gcloud auth login
gcloud auth application-default login
flyctl auth login
```

**完了確認:** Google Cloud Consoleでprojectとbudgetが見え、CockroachDB API keyがsecret storeに保存され、上記commandがすべてversionを返す。

##### 作業2. 固定値、password、ローカルsecretを準備する

Cloud RunとCockroachDBは可能な限り同じGCP regionにする。CockroachDBのcluster作成画面で選択可能なregion名を確認してから値を決める。

###### 選択するregion

**日本から個人利用する現在の構成では、CockroachDBとCloud Runを両方`us-west2`にする。** CockroachDB Consoleで表示されるCaliforniaは`us-west2`、Google Cloudのregion表記ではLos Angelesである。利用者から北米西海岸までの経路が、Iowa／South Carolinaより短くなりやすく、Cloud RunとDBを同一region名に揃えられるためである。[Cloud Runの公式region一覧](https://cloud.google.com/run/docs/locations)でも`us-west2`、`us-central1`、`us-east1`、`asia-south1`を利用できる。

候補の優先順位は次のとおり。

| 優先 | CockroachDBの表示 | region ID     | Cloud Runも置く場所 | この構成での判断                                                        |
| ---: | ----------------- | ------------- | ------------------- | ----------------------------------------------------------------------- |
|    1 | California        | `us-west2`    | `us-west2`          | **採用**。日本からの対話的なviewer利用と、app／DB間の近さを両立しやすい |
|    2 | Iowa              | `us-central1` | `us-central1`       | 西海岸が利用できない場合。`us-centralq`ではなく`us-central1`            |
|    3 | Mumbai            | `asia-south1` | `asia-south1`       | 主な利用者がインド／南アジアにいる場合だけ優先                          |
|    4 | South Carolina    | `us-east1`    | `us-east1`          | 主な利用者が北米東海岸にいる場合向け。日本中心では優先しない            |

重要なのは、Cloud Runだけ東京など別regionへ置かず、**選んだCockroachDB regionとCloud Runのregion IDを一致させること**である。CockroachDBはGoogle Cloudとは別serviceなので同一region名でも無料通信を保証するものではないが、異なる大陸／米国内regionへ分離するよりappとDB間のlatencyを抑えやすい。Atuin app／DBはFly.io内に残るため、この選択の影響を受けない。

本番決定前に4候補を作り比べる必要はない。まず`us-west2`でrehearsalし、各PCからCloud Runへのp95、Cloud Run logのDB query時間、CockroachDB ConsoleのSQL latencyを記録する。許容できない場合だけ`us-central1`を短期間PoCし、低い方へ作り直す。CockroachDB cluster作成後のregion変更を前提にせず、Fly schemaを削除する前に決定する。

```sh
export GCP_PROJECT_ID='<google-cloud-project-id>'
export GCP_REGION='us-west2'
export TF_STATE_BUCKET="${GCP_PROJECT_ID}-terraform-state"
export COCKROACH_REGION='us-west2'
export TF_VAR_gcp_project_id="$GCP_PROJECT_ID"
export TF_VAR_gcp_region="$GCP_REGION"
export TF_VAR_cockroach_region="$COCKROACH_REGION"
export TF_VAR_github_repository='ryo246912/dotfiles'

gcloud config set project "$GCP_PROJECT_ID"
gcloud config set run/region "$GCP_REGION"
gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectId)'
```

URLへ安全に埋め込める16進passwordとAgentsView tokenを生成する。各出力をそれぞれ別のBitwarden secretへ保存し、terminalのscrollbackを消す。

```sh
openssl rand -hex 32 # TF_VAR_cockroach_owner_password
openssl rand -hex 32 # TF_VAR_cockroach_push_password
openssl rand -hex 32 # TF_VAR_cockroach_read_password
openssl rand -hex 32 # AGENTSVIEW_AUTH_TOKEN
openssl rand -hex 32 # AGENTSVIEW_CURSOR_SECRET
```

Bitwarden Secrets ManagerのUIでprojectを開き、**New secret**から次の5件を作る。CockroachDB URL 3件はcluster作成後の作業4で追加する。

```text
TF_VAR_cockroach_owner_password
TF_VAR_cockroach_push_password
TF_VAR_cockroach_read_password
AGENTSVIEW_AUTH_TOKEN
AGENTSVIEW_CURSOR_SECRET
```

`dot_config/fnox/config.toml`が参照するsecret名と完全一致させる。値を`terraform.tfvars`、`.env`、shell history、GitHub logへ保存しない。

**完了確認:** 次は値を表示せず、すべて`set`を返す。

```sh
fnox exec -- sh -c '
  for name in AGENTSVIEW_AUTH_TOKEN AGENTSVIEW_CURSOR_SECRET; do
    eval "test -n \"\${$name:-}\"" && echo "$name=set" || exit 1
  done
'
```

##### 作業3. Terraform state bucketを手動作成する

state bucketはそのstate自身で作成できないため、operatorが一度だけ作る。

```sh
gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
  --project="$GCP_PROJECT_ID" \
  --location="$GCP_REGION" \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets update "gs://${TF_STATE_BUCKET}" --versioning
gcloud storage buckets describe "gs://${TF_STATE_BUCKET}" \
  --format='yaml(name,location,uniformBucketLevelAccess,publicAccessPrevention,versioning_enabled)'
```

Google Cloud Consoleでは**Cloud Storage > Buckets > bucket名**を開き、**Protection**でObject versioningが有効、**Permissions**でPublic accessがPreventedになっていることを確認する。state fileをlocalやGitへcommitしない。

**完了確認:** `gcloud storage buckets describe`が対象bucketを返し、versioningとpublic access preventionが有効になっている。

##### 作業4. TerraformでCockroachDBとGoogle Cloudの土台を作る

Terraform変数fileを作る。このfileにpasswordやAPI keyを記載しない。

```sh
cp terraform/agentsview/terraform.tfvars.example terraform/agentsview/terraform.tfvars
sed -i.bak \
  -e "s/replace-with-project-id/${GCP_PROJECT_ID}/g" \
  -e "s/us-west2/${GCP_REGION}/g" \
  terraform/agentsview/terraform.tfvars
rm -f terraform/agentsview/terraform.tfvars.bak
```

CockroachDB API keyと3つのpasswordは、現在のshellへ手動`export`せずfnoxからTerraform processへ渡す。Bitwarden Secrets Managerに次の名前で登録し、`dot_config/fnox/config.toml`のmappingと一致させる。

```text
COCKROACH_API_KEY
TF_VAR_cockroach_owner_password
TF_VAR_cockroach_push_password
TF_VAR_cockroach_read_password
```

値を表示せず、fnoxが4つすべて解決できることを確認する。

```sh
fnox exec -- sh -c '
  for name in COCKROACH_API_KEY \
    TF_VAR_cockroach_owner_password \
    TF_VAR_cockroach_push_password \
    TF_VAR_cockroach_read_password; do
    eval "test -n \"\${$name:-}\"" || { echo "$name=missing" >&2; exit 1; }
    echo "$name=set"
  done
'
```

以後、CockroachDB providerまたはSQL user resourceを読む`terraform plan`／`apply`は必ず`fnox exec --`経由で実行する。`fnox exec -- terraform ...`の後ろへ`-var`でpasswordを重ねて渡さない。

初期化と静的確認を行う。

```sh
terraform -chdir=terraform/agentsview init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config='prefix=agentsview'
terraform -chdir=terraform/agentsview fmt -check -recursive
terraform -chdir=terraform/agentsview validate
```

初回だけ、Cloud Run service以外の土台をtarget applyする。planを読み、別projectや既存resourceを変更しないことを確認して`yes`を入力する。

```sh
fnox exec -- terraform -chdir=terraform/agentsview apply \
  -target=google_project_service.required \
  -target=google_artifact_registry_repository.agentsview \
  -target=google_secret_manager_secret.pg_url \
  -target=google_secret_manager_secret.config \
  -target=google_service_account.runtime \
  -target=google_service_account.deploy \
  -target=google_iam_workload_identity_pool.github \
  -target=cockroach_cluster.agentsview \
  -target=cockroach_database.agentsview \
  -target=cockroach_sql_user.owner \
  -target=cockroach_sql_user.push \
  -target=cockroach_sql_user.read
```

CockroachDB Consoleの**Clusters**で`agentsview` clusterが`Basic`としてReadyになり、**SQL Users**にowner／push／readが表示されることを確認する。Google Cloud ConsoleではArtifact Registry repository、2つのSecret Manager secret container、service accountが作成されていることを確認する。

**完了確認:** 次がID、database名、SQL hostを返す。

```sh
terraform -chdir=terraform/agentsview output cockroach_cluster_id
terraform -chdir=terraform/agentsview output cockroach_database
terraform -chdir=terraform/agentsview output cockroach_sql_host
```

##### 作業5. CockroachDB接続URL、schema、最小権限を作る

Terraform outputでhostとdatabaseを確認する。passwordはfnoxの子processだけへ渡すため、現在のshellへ`export`しない。

```sh
terraform -chdir=terraform/agentsview output -raw cockroach_sql_host
terraform -chdir=terraform/agentsview output -raw cockroach_database
```

Bitwarden Secrets ManagerのUIで、作業2に保存した各passwordと上記outputを使い、次のtemplateから3本のURLを作成する。16進passwordなので追加のURL encodeは不要である。

```text
postgresql://agentsview_owner:<owner password>@<SQL host>:26257/<database>?sslmode=verify-full
postgresql://agentsview_push:<push password>@<SQL host>:26257/<database>?sslmode=verify-full
postgresql://agentsview_read:<read password>@<SQL host>:26257/<database>?sslmode=verify-full
```

3本をBitwarden Secrets Managerへ同名で登録する。CockroachDB Consoleの**Connect**画面が別port、database、CA指定を案内した場合は、手作業で組み立てた値よりConsoleの接続文字列を優先し、usernameとpasswordだけ各role用に差し替える。

まず小さいproject名を確認し、owner URLでAgentsView schema migrationを実行する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<small-project>'
fnox exec -- sh -c '
  AGENTSVIEW_PG_SCHEMA=agentsview \
  AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_OWNER_PG_URL" \
    agentsview pg push --no-vectors --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
'
```

続いてowner接続で最小権限を設定する。

```sh
fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -v ON_ERROR_STOP=1' <<'SQL'
GRANT USAGE ON SCHEMA agentsview TO agentsview_push, agentsview_read;
GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push;
SQL
```

read userで書き込みができないことも確認する。2番目のcommandは失敗が正解である。

```sh
fnox exec -- sh -c '
  psql "$AGENTSVIEW_COCKROACH_READ_PG_URL" -X -v ON_ERROR_STOP=1 \
    -c "SELECT count(*) FROM agentsview.sessions;"
  if psql "$AGENTSVIEW_COCKROACH_READ_PG_URL" -X -v ON_ERROR_STOP=1 \
    -c "DELETE FROM agentsview.sessions WHERE 1=0"; then
    echo "ERROR: read user can write" >&2
    exit 1
  else
    echo "OK: read user is read-only"
  fi
'
```

**完了確認:** ownerでschemaが作成され、push userで`agentsview pg status`が成功し、read userの`SELECT`は成功、DMLはpermission deniedになる。

##### 作業6. Artifact Registryへ最初のimageをbuildする

Google Cloud Consoleの**Cloud Build > Settings**でbuild service accountを確認し、Artifact Registry writer権限がTerraformで付与されていることを確認する。次にrepository rootからimmutableなbootstrap tagをbuildする。

```sh
export AGENTSVIEW_IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/agentsview/agentsview:bootstrap"
gcloud builds submit dot_config/agentsview \
  --project="$GCP_PROJECT_ID" \
  --tag="$AGENTSVIEW_IMAGE"
gcloud artifacts docker images describe "$AGENTSVIEW_IMAGE" \
  --project="$GCP_PROJECT_ID" --format='value(image_summary.digest)'
```

Google Cloud Consoleの**Artifact Registry > Repositories > agentsview**で`bootstrap` imageとdigestが表示されることを確認する。

**完了確認:** 最後のcommandが`sha256:...`を返す。

##### 作業7. Secret Managerへ最初のsecret versionを登録する

Cloud Run URLはまだ存在しないため、初回configだけplaceholderを使う。URL確定後の作業8で必ず置き換える。

```sh
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
export AGENTSVIEW_CLOUD_RUN_URL='https://invalid.example'
fnox exec -- mise run agentsview:cloudrun:secrets

export TF_VAR_pg_url_secret_version=$(gcloud secrets versions list agentsview-pg-url \
  --project="$GCP_PROJECT_ID" --limit=1 --sort-by='~createTime' \
  --format='value(name)' | sed 's#.*/##')
export TF_VAR_config_secret_version=$(gcloud secrets versions list agentsview-config-toml \
  --project="$GCP_PROJECT_ID" --limit=1 --sort-by='~createTime' \
  --format='value(name)' | sed 's#.*/##')
printf 'pg_url version=%s\nconfig version=%s\n' \
  "$TF_VAR_pg_url_secret_version" "$TF_VAR_config_secret_version"
```

Google Cloud Consoleの**Security > Secret Manager**で両secretを開き、Enabledなversionが1つあることを確認する。値そのものを表示する必要はない。

**完了確認:** 両version変数が空でなく、Secret Manager UIでEnabledになっている。

##### 作業8. 通常のTerraform applyでCloud Runを作る

初回target applyのあとに必ず通常planを実行し、構成全体の依存関係とIAMを収束させる。

```sh
export TF_VAR_agentsview_image="$AGENTSVIEW_IMAGE"
fnox exec -- terraform -chdir=terraform/agentsview plan -out=tfplan
terraform -chdir=terraform/agentsview show tfplan
fnox exec -- terraform -chdir=terraform/agentsview apply tfplan
```

Cloud Run URLを取得し、placeholder configを実URLへ置き換える。

```sh
export AGENTSVIEW_CLOUD_RUN_URL=$(terraform -chdir=terraform/agentsview output -raw cloud_run_service_url)
fnox exec -- mise run agentsview:cloudrun:secrets
export TF_VAR_config_secret_version=$(gcloud secrets versions list agentsview-config-toml \
  --project="$GCP_PROJECT_ID" --limit=1 --sort-by='~createTime' \
  --format='value(name)' | sed 's#.*/##')
fnox exec -- terraform -chdir=terraform/agentsview apply
```

Google Cloud Consoleの**Cloud Run > ryo-agentsview**で、region、1 CPU、512 MiB、min 0、max 2、runtime service account、Secret Manager参照を確認する。**Revisions**で最新revisionが100% trafficになっていることも確認する。

**完了確認:** 次がHTTPS URLを返し、未認証APIが401を返す。

```sh
gcloud run services describe ryo-agentsview \
  --project="$GCP_PROJECT_ID" --region="$GCP_REGION" \
  --format='value(status.url)'
curl -i "${AGENTSVIEW_CLOUD_RUN_URL}/api/v1/sessions"
```

##### 作業9. 小規模データでmigration rehearsalとCloud Run検証を行う

全PCの`agentsview pg push`、`pg watch`、cron／launchd／systemd timerを一時停止する。FlyのAtuinは別schemaなので停止しない。停止確認後だけ次を実行する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<small-project>'
export AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes
fnox exec -- mise run agentsview:cockroach:migrate
fnox exec -- mise run agentsview:cockroach:status
fnox exec -- mise run agentsview:cockroach:push -- --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
```

認証と画面を確認する。

```sh
curl -i "${AGENTSVIEW_CLOUD_RUN_URL}/api/v1/sessions" # 401を期待
fnox exec -- sh -c 'curl -fsS \
  -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$AGENTSVIEW_CLOUD_RUN_URL"'/api/v1/sessions" >/dev/null'
```

UIではCloud Runの**Logs**または**Logging > Logs Explorer**を開き、resource typeをCloud Run Revision、service nameを`ryo-agentsview`に絞る。startup error、CockroachDB接続error、secret値、`token=`付きURLが記録されていないことを確認する。CockroachDB Consoleのcluster Metrics／Usageでstorage、RU、connection数を記録する。

**完了確認:** migration taskの全table件数比較が一致し、認証済みAPI、session一覧、detail、analytics、usageが表示され、Cloud RunとCockroachDBにerrorがない。

##### 作業10. 本番cutoverし、観察後にFly側AgentsViewを削除する

1. 全PCのpush／watch／timerを停止し、停止した端末一覧とUTC時刻を記録する。
2. `flyctl scale count 0 -a ryo-agentsview`で旧viewerを停止する。Atuinと`psgl`は停止しない。
3. 作業9と同じmigration commandを再実行して最終差分をcopyする。
4. table count、主要session本文、最大更新時刻をFly／CockroachDBで比較する。
5. 各PCの通常taskを`agentsview:cockroach:push`へ切り替え、小さいprojectから再開する。
6. Cloud Runを再度smoke testする。失敗した場合は新DBへのpushを再開せずFlyへrollbackする。
7. 旧Fly schemaとappを最低1〜2週間保持し、毎日Cloud Run error、CockroachDB RU／storage、backupを確認する。
8. 観察期間後に最新backupとrestore rehearsalを行い、承認してからFlyの`agentsview` schemaとappだけを削除する。

```sh
export AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes
fnox exec -- mise run agentsview:cockroach:migrate
fnox exec -- mise run agentsview:cockroach:status
fnox exec -- mise run agentsview:pg:remote-local:dump
```

削除直前にFly owner接続で件数を確認し、明示承認後だけ実行する。

```sql
SELECT count(*) FROM agentsview.sessions;
DROP SCHEMA agentsview CASCADE;
```

```sh
flyctl apps destroy ryo-agentsview
```

**完了確認:** Atuin syncがFly private PostgreSQLで継続し、全PCがCockroachDBへpushし、Cloud Run viewerとbackup／restoreが成功し、Flyから削除したのがAgentsView app／schemaだけである。

### AgentsView appの実行基盤はどれを選ぶか

調査日: **2026-09-02**

#### 結論

この用途では、**Cloud Runを継続するのが第一候補**。Fly.ioよりログの検索・絞り込み・保持が扱いやすく、現在の実装をそのまま利用できる。個人用AgentsViewは常時接続を必要とせず、閲覧時だけ起動できるため、Cloud Runのscale-to-zeroと相性がよい。

「管理画面の分かりやすさ」を最優先してGoogle Cloud自体を避けたいなら、**Northflank Developer Sandboxを第二候補としてPoC**する。ただしDeveloper Sandboxは本番SLAを期待する基盤ではなく、無料枠やresource planの変更リスクがCloud Runより高い。単純なスペック表だけでNorthflankへ即移行せず、cold start、ログ保持期間、CockroachDBへのlatencyを実測してから決める。

#### 比較表

無料枠は予告なく変わる。契約・移行直前に各公式Pricingを再確認する。ここでいう「スペック」は無料quotaまたは選択可能resourceの上限であり、専有CPU性能を保証しない。

|  順位 | 基盤                                                                                            | 無料computeの目安                                                                  | ログの使いやすさ                                                                            | AgentsViewとの相性                                                          | 判定                    |
| ----: | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ----------------------- |
| **1** | [Google Cloud Run](https://cloud.google.com/run/pricing)                                        | 月180,000 vCPU秒、360,000 GiB秒、200万request。現在は1 vCPU／512 MiB、min 0、max 2 | Cloud Run画面、Logs Explorer、CLI tail／read。構造化JSON、severity、request traceで検索可能 | 既存image／Secret Manager／deploy taskを実装済み。scale-to-zero可能         | **採用**                |
| **2** | [Northflank Developer Sandbox](https://northflank.com/pricing)                                  | Sandbox内のservice／CPU／memory quota。現行consoleで利用可能resource planを要確認  | app、build、deployment、logが一つのproject UIにまとまる                                     | OCI imageとsecretを登録しやすい。無料Sandboxの継続性・SLAは弱い             | **UI重視のPoC候補**     |
| **3** | [Azure Container Apps Consumption](https://azure.microsoft.com/pricing/details/container-apps/) | Consumptionの月次無料grantは公式Pricingで移行直前に確認                            | Portal／CLIでsystem logとconsole logを分離してlive stream可能                               | scale-to-zeroとsecret対応。Cloud Runから移す利益が小さく、Azure構築が増える | 既にAzureを使う場合のみ |
| **4** | [Koyeb Free](https://www.koyeb.com/pricing)                                                     | Free instanceは小さいCPU／memory枠。現行instance表を要確認                         | service画面でruntime logを見やすい                                                          | deployは簡単だが、CPU余裕とcold startはCloud Runより不利                    | hobby／検証用           |
| **5** | [Render Free](https://render.com/docs/free)                                                     | Free web service。idle時のspin-downや月間利用条件あり                              | dashboardからdeploy／runtime logを確認しやすい                                              | 操作は簡単だが、cold startと無料resourceが弱い                              | hobby／fallback         |
| **6** | Oracle Always Free VM                                                                           | VM quota内ならPaaSより大きいCPU／RAMを取れる場合がある                             | journald、rotation、検索、alertをすべて自分で構築                                           | raw specは強いが、今回避けたい運用・ログ監視負担が最大                      | **不採用**              |

#### Cloud Runを選ぶ理由

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

#### Cloud Runの弱点と対策

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

#### Northflankへ変更する判断基準

次をすべて満たす場合だけ、Cloud RunからNorthflankへ移す価値がある。

1. 現行Developer SandboxでAgentsView containerに512 MiB以上を割り当てられる。
2. idle／sleep後の起動時間がCloud Runより短い、または許容範囲である。
3. runtime logの保持期間、検索、downloadが必要条件を満たす。
4. CockroachDB regionへのp95 latencyとegress条件がCloud Run以下である。
5. 無料枠超過時が自動課金、停止、削除のどれになるか確認した。
6. `require_auth`、secret file mount相当、read-only DB URL、rollback用旧revisionを再現できる。

NorthflankはUIの分かりやすさでは魅力があるが、今回の目的は「無料・ログ改善・十分なspec・安全な移行」を同時に満たすこと。**現状ではCloud Runのままログ操作をCLI／saved queryへ整備する方が、再移行より低リスク**である。

### 実装済みファイル

| ファイル                                                | 目的                                                                        |
| ------------------------------------------------------- | --------------------------------------------------------------------------- |
| `dot_config/agentsview/Dockerfile`                      | upstream AgentsView imageをArtifact RegistryへmirrorするCloud Build context |
| `dot_config/agentsview/cloudrun.env.yaml`               | Cloud Runの非secret環境変数                                                 |
| `dot_config/agentsview/scripts/deploy-cloud-run.sh`     | 同じ設定でbuild／Cloud Run deployを行う共通script                           |
| `dot_config/agentsview/scripts/migrate-to-cockroach.sh` | Flyからdata-only dumpを取得し、CockroachDBへ冪等restoreして件数比較         |
| `dot_config/mise/tasks/agentsview.toml`                 | secret登録、deploy、migration、status、push task                            |

### 0. 変更前の安全確認

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
  pg_dump --dbname="$AGENTSVIEW_OWNER_PROXY_PG_URL" -Fc \
    -f "$HOME/backup/fly-all-$(date -u +%Y%m%dT%H%M%SZ).dump"
  pg_dump --dbname="$AGENTSVIEW_OWNER_PROXY_PG_URL" -Fc -n agentsview \
    -f "$HOME/backup/agentsview-$(date -u +%Y%m%dT%H%M%SZ).dump"
'
```

4. backupを空の検証PostgreSQLへrestoreできることを確認する。backup fileを作っただけでは合格にしない。

### 1. CockroachDBの権限設計を決める

Basic cluster、database、owner／push／read userは次節のTerraformで作成する。Terraformは10 GiB storage／5,000万RUのusage limitも設定し、意図しない有料利用を防ぐ。passwordはuserごとに異なるrandom valueを用意する。

CockroachDB Terraform providerはdatabase内のschema／table権限を管理しないため、AgentsViewのschema bootstrap後に次だけSQL consoleまたはowner接続で実行する。CockroachDB versionによって`ALL TABLES IN SCHEMA`／default privilegeの対応が異なる場合は、Consoleが示す現行syntaxに合わせる。

```sql
GRANT USAGE ON SCHEMA agentsview TO agentsview_push, agentsview_read;
GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push;
```

`terraform apply`後、`sslmode=verify-full`を含む3本のconnection URLをBitwarden Secrets Managerへ登録する。

| secret名                            | user               | 用途                            |
| ----------------------------------- | ------------------ | ------------------------------- |
| `AGENTSVIEW_COCKROACH_OWNER_PG_URL` | `agentsview_owner` | schema bootstrap／migrationのみ |
| `AGENTSVIEW_COCKROACH_PUSH_PG_URL`  | `agentsview_push`  | 各PCの`pg push`                 |
| `AGENTSVIEW_COCKROACH_READ_PG_URL`  | `agentsview_read`  | Cloud Run viewer                |

### 2. TerraformでGoogle Cloud／CockroachDBを準備

`terraform/agentsview`が次を一括管理する。

- Google Cloud API、Artifact Registry repository
- Cloud Run runtime／GitHub deploy service account
- Secret Managerのsecret containerとruntime IAM（secret value／versionはstateへ保存しない）
- Cloud Run v2 service、resource上限、secret mount、public invoker IAM
- GitHub Actions用Workload Identity Pool／Providerとproject IAM
- CockroachDB Cloud Basic cluster、database、owner／push／read SQL user

CockroachDB user passwordはTerraform 1.11以降のwrite-only `password_wo`を使うためstateへ保存されない。Cockroach Cloud API keyはproviderが`COCKROACH_API_KEY`から読み、tfvarsへ書かない。

#### 2.1 state bucketと初回認証

state bucketそのものは自身のstateで管理できないため、一度だけ手元のowner権限で作成する。bucket名は全世界で一意にする。

```sh
export GCP_PROJECT_ID='<project-id>'
export GCP_REGION='us-west2'
export TF_STATE_BUCKET="${GCP_PROJECT_ID}-terraform-state"

gcloud config set project "$GCP_PROJECT_ID"
gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
  --project="$GCP_PROJECT_ID" --location="$GCP_REGION" --uniform-bucket-level-access
gcloud storage buckets update "gs://${TF_STATE_BUCKET}" --versioning

gcloud auth application-default login
```

stateにはpassword本体を入れないが、resource IDや構成情報は入る。public access prevention、versioning、最小権限IAMを設定し、state fileをcommitしない。

#### 2.2 Terraformを初期化

```sh
cd terraform/agentsview
cp terraform.tfvars.example terraform.tfvars
# project、region、最初にbuildするimage URIを編集する。

terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config='prefix=agentsview'
terraform fmt -check -recursive
terraform validate
```

CockroachDB Cloudでorganization API keyを発行し、SQL user用に別々のrandom passwordを用意する。shell historyへ直接値を書かず、fnox等からexportする。

```sh
fnox exec -- sh -c '
  test -n "$COCKROACH_API_KEY"
  test -n "$TF_VAR_cockroach_owner_password"
  test -n "$TF_VAR_cockroach_push_password"
  test -n "$TF_VAR_cockroach_read_password"
  echo "CockroachDB Terraform secrets: set"
'
```

#### 2.3 bootstrap apply

最初はArtifact Registryにimageがなく、Secret Managerにversionもないため、依存resourceだけtarget applyする。

```sh
fnox exec -- terraform apply \
  -target=google_project_service.required \
  -target=google_artifact_registry_repository.agentsview \
  -target=google_artifact_registry_repository_iam_member.cloud_build_writer \
  -target=google_secret_manager_secret.pg_url \
  -target=google_secret_manager_secret.config \
  -target=google_service_account.runtime \
  -target=google_service_account.deploy \
  -target=google_iam_workload_identity_pool.github \
  -target=google_iam_workload_identity_pool_provider.github \
  -target=google_service_account_iam_member.github_deploy \
  -target=google_project_iam_member.deploy \
  -target=google_service_account_iam_member.deploy_uses_runtime
```

続いて最初のimageをbuildする。

```sh
image="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/agentsview/agentsview:bootstrap"
gcloud builds submit ../../dot_config/agentsview --project="$GCP_PROJECT_ID" --tag="$image"
```

repository rootへ戻り、CockroachDBのread-only URLとAgentsView configをSecret Managerへ登録する。初回だけ`AGENTSVIEW_CLOUD_RUN_URL=https://invalid.example`を使い、service作成後に実URLへ更新する。

```sh
cd ../..
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
export AGENTSVIEW_CLOUD_RUN_URL='https://invalid.example'
fnox exec -- mise run agentsview:cloudrun:secrets
```

`terraform/agentsview`へ戻り、secret version番号を確認してfull applyする。

```sh
export TF_VAR_agentsview_image="$image"
export TF_VAR_pg_url_secret_version=$(gcloud secrets versions list agentsview-pg-url \
  --project="$GCP_PROJECT_ID" --limit=1 --sort-by='~createTime' --format='value(name)' | sed 's#.*/##')
export TF_VAR_config_secret_version=$(gcloud secrets versions list agentsview-config-toml \
  --project="$GCP_PROJECT_ID" --limit=1 --sort-by='~createTime' --format='value(name)' | sed 's#.*/##')

cd terraform/agentsview
fnox exec -- terraform plan -out=tfplan
fnox exec -- terraform apply tfplan
```

planで`cockroach_cluster`が`plan = "BASIC"`、Cloud Runがmin 0／max 2、1 vCPU／512 MiBであることを確認する。`terraform apply`後に出る`cloud_run_service_url`を`AGENTSVIEW_CLOUD_RUN_URL`へ設定し、config secretを更新して新version番号で再applyする。

#### 2.4 deploy方法を確認する

初回構築とsecret version追加は手元で行い、通常deployはrepository rootから次を実行する。

```sh
mise run agentsview:cloudrun:deploy
```

このrepositoryには現時点でCloud Run用GitHub Actions workflowを含めていない。TerraformはGitHub Actions用Workload Identityを作成するが、CI deployを後から追加する場合にだけ、repositoryのEnvironment `production`へTerraform outputとGoogle Cloud／CockroachDBの値を登録する。初回bootstrapより先にCIを実行しない。

```sh
terraform -chdir=terraform/agentsview output -raw github_workload_identity_provider
terraform -chdir=terraform/agentsview output -raw deploy_service_account
```

state bucketをCIから操作する場合は、deploy service accountへbucket単位の権限を一度だけ付与する。service-account key JSONは作らず、GitHub OIDC／WIFを使う。

```sh
gcloud storage buckets add-iam-policy-binding "gs://${TF_STATE_BUCKET}" \
  --member="serviceAccount:$(terraform -chdir=terraform/agentsview output -raw deploy_service_account)" \
  --role=roles/storage.objectAdmin
```

### 3. CockroachDB schemaをbootstrapしてデータをcopy

#### 3.1 小さいprojectでbootstrap

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

#### 3.2 内容も照合

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

### 4. local dataとCockroachDBのpush／pull

#### 結論: pushは可能、DBからlocalへのpullは提供されない

AgentsViewの同期元はlocal PostgreSQLではなく、各PCにあるsession fileとAgentsViewのlocal SQLite indexである。`agentsview pg push`は、local sessionを同期してからshared databaseへupsertする**一方向同期**であり、PostgreSQL serverからlocal SQLite／session fileへ戻す`pg pull` commandはない。

CockroachDBはPostgreSQL wire protocolで接続でき、AgentsView 0.38.1はCockroachDBをshared databaseとして扱える。このrepositoryでは次の経路を採用する。

```text
各PCのsession file + local SQLite
    │
    │ agentsview pg push（public TLS、push role）
    ▼
CockroachDB Cloud Basic
    │
    │ SELECTのみ（read role）
    ▼
Cloud Run上のagentsview pg serve
```

通常の差分pushはFly proxyを使わず、各PCからCockroachDBのTLS endpointへ直接送る。

```sh
# 接続とwatermarkを確認
fnox exec -- mise run agentsview:cockroach:status

# まず1 projectだけ
fnox exec -- mise run agentsview:cockroach:push -- --projects '<project>'

# 差分を全projectへ反映
fnox exec -- mise run agentsview:cockroach:push

# schema resetや内容修復後に限り全件を再送
fnox exec -- mise run agentsview:cockroach:push -- --full --no-vectors
```

`agentsview:cockroach:push` taskは常に`--no-vectors`を追加し、CockroachDBに送る対象をsession contentへ限定する。AgentsViewはDB vendorだけを見てvector phaseを自動停止しないため、taskを介さず直接実行するときも`--no-vectors`または`push_vectors=false`を必ず指定する。incremental watermarkは接続target／project filterごとにlocal保存されるため、Fly PostgreSQL用watermarkとCockroachDB用watermarkは共有されない。初回CockroachDB pushは必ず小さいprojectで確認してから広げる。

#### 「pull」の代わりに何を使うか

| 目的                                      | 方法                                                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 別PCから同じsessionを閲覧する             | localへpullせず、Cloud Runのread-only viewerでCockroachDBを読む                                                           |
| 新しいPCのlocal AgentsViewへsessionを戻す | AgentsViewの`pg pull`ではできない。元のagent session directoryのbackup／同期機能で復元してから再indexする                 |
| CockroachDB障害に備える                   | `agentsview:pg:remote-local:dump`でdataをlocal PostgreSQLへmergeし、custom-format backupを作る。自動replicaとはみなさない |
| PostgreSQLへrollbackする                  | write停止後にschema／型を変換したexport/importをrehearsalする。CockroachDBのdumpをPostgreSQLへ無検証restoreしない         |
| localでSQL分析する                        | read-only SQL clientでCockroachDBへ直接接続するか、分析用exportを別DBへimportする。本番との双方向同期はしない             |

CockroachDBとPostgreSQLは同じwire protocolを話すが、DDL、sequence、権限、型、transaction semanticsは完全互換ではない。そのためCockroachDBのschema dumpをPostgreSQLへそのままrestoreする設計は採用しない。このrepositoryの`agentsview:pg:remote-local:dump`はdata-only／column INSERTとしてexportし、現在のAgentsViewがlocal PostgreSQLへ作ったschemaに不足rowだけをtransaction内でmergeする。

#### PR #1376のlocal PostgreSQL変更との関係

[PR #1376](https://github.com/ryo246912/dotfiles/pull/1376)で検討しているproxy readiness、Fly PostgreSQL backup、local PostgreSQL restoreは、次の用途では引き続き有効である。

1. CockroachDB cutover前のFly PostgreSQL snapshotをlocalへ退避する。
2. Fly proxyが実際にPostgreSQL protocolへ応答するまで待ってから旧DBをdumpする。
3. rollback rehearsal用に「Fly PostgreSQLから取得したPostgreSQL dump」をlocal PostgreSQLへrestoreする。

一方、PR #1376のlocal PostgreSQLをCockroachDBの自動pull先にはしない。cutover後の日常運用は、各PCのsession sourceからCockroachDBへ直接pushし、Cloud Runからreadする。backupが必要なときだけ`mise run agentsview:pg:remote-local:dump`を実行し、このmachineのlocal push、CockroachDB data export、local merge、sequence補正、custom-format dumpを順に行う。

```sh
# CockroachDB data + このmachineのsessionを統合したlocal PostgreSQL dump
fnox exec -- mise run agentsview:pg:remote-local:dump

# 旧Fly PostgreSQLをsourceにするrollback期間中のcommand
fnox exec -- mise run agentsview:pg:fly:remote-local:dump

# remoteへ接続せず、現在のlocal PostgreSQLだけをdump
mise run agentsview:pg:local:dump
```

CockroachDB側にだけ存在するrowはlocalへ追加するが、同じprimary keyがlocalにある場合は`ON CONFLICT DO NOTHING`でlocalを維持する。このdumpは完全な双方向同期やreplicaではなく、閲覧・disaster recovery用の統合snapshotである。importはtransaction内で行い、schema／型が合わなければ全体をrollbackする。

移行期間に同じlocal sessionをFly PostgreSQLとCockroachDBの両方へpushすること自体は可能だが、これはpull／replicationではなく2回の独立したpushである。長期dual-writeは削除、curation metadata、migration versionの差異を発見しにくいため、rehearsal期間だけに限定し、cutover後はCockroachDBを唯一のshared AgentsView databaseにする。

### 5. Cloud Run secretとserviceを作成

初回はCloud Run URLがまだないため、config作成用に一時URLを指定する。

```sh
export GCP_PROJECT_ID='<project-id>'
export GCP_REGION='us-west2'
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

### 6. Cloud Runを検証

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

### 7. Cutover

1. 全PCで旧`mise run agentsview:pg:push`の実行を止める。
2. Fly AgentsView appを停止し、旧viewerからのreadを止める。
3. cutover UTC timestampを記録する。
4. `AGENTSVIEW_MIGRATION_WRITES_PAUSED=yes`を設定し、`agentsview:cockroach:migrate`を再実行して最終差分をcopyする。
5. 厳密row countと主要sessionの内容を比較する。
6. 各PCの通常taskを`agentsview:cockroach:push`へ切り替える。
7. Cloud Run viewerで認証、session一覧、detail、analytics、usageをsmoke testする。
8. smoke test合格後だけCockroachDBへのpushを再開する。

旧Fly schemaはこの時点で削除しない。

### 8. Rollback

#### 新DBへのpush再開前

Cloud Run smoke testに失敗したら、pushを再開せず、各PCの接続先を旧`AGENTSVIEW_PROXY_PG_URL`へ戻してFly viewerを再起動する。新規writeがないため逆同期は不要。

#### 新DBへのpush再開後

1. 全PCのCockroachDB pushを停止する。
2. cutover timestamp以降のsession／messageをCockroachDBからexportする。
3. Fly schemaへimportする。
4. row count、primary key、最大更新時刻、代表session本文を照合する。
5. 合格後だけ旧Flyへのpushとviewerを再開する。

この差分export／importを事前rehearsalできない場合、新DBへのwrite再開後のrollbackは実施せず、CockroachDB側を修復する。

### 9. Flyの容量を解放

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

---

## Fly.io旧構成（migration元／rollback用）

### 構成

```text
PC-A (hostname: mac-work)          PC-B (hostname: mac-home)
└── ~/.agentsview/*.sqlite          └── ~/.agentsview/*.sqlite
        ↓ mise run agentsview:pg:push       ↓ mise run agentsview:pg:push
        └──────────────────────────────────┘
                        ↓
        Fly.io psgl (PostgreSQL / 既存 Atuin 共用)
        └── agentsview schema
                ├── sessions (machine=mac-work)
                └── sessions (machine=mac-home)
                        ↓ 読み取り
        Fly.io ryo-agentsview
        └── agentsview pg serve  →  https://ryo-agentsview.fly.dev
```

### 初回セットアップ

#### 1. Fly app を作成

```sh
flyctl apps create ryo-agentsview
```

#### 2. PostgreSQL role を分ける

公開 viewer と local push は別の DB role を使う。

- `agentsview_read`: Fly app の `pg serve` 用。通常運用は `SELECT` のみ。
- `agentsview_push_mac`: ローカル PC からの `agentsview pg push` 用。`agentsview` schema だけに DML 権限を持つ。
- `agentsview_owner`: 初回 schema 作成・migration 用。通常の app / local push では使わない。

mise task で実行する場合:

```sh
mise run agentsview:setup:db-roles
```

task は `dot_config/mise/tasks/agentsview.toml` の `agentsview:setup:db-roles` で定義している。`AGENTSVIEW_ADMIN_PG_USER`、`AGENTSVIEW_ADMIN_PG_DATABASE`、`AGENTSVIEW_PG_APP` は必要に応じて上書きできる。

> 下記の SQL は概念的な内容の抜粋。実際の task は `CREATE ROLE ... / ALTER ROLE ...` を存在チェック付きで冪等に実行し、role 属性（`NOSUPERUSER` 等）も毎回正規化するため、再セットアップや password rotation でも重複エラーにならない。

実行される SQL の内容:

```sql
CREATE ROLE agentsview_owner LOGIN PASSWORD '<owner-pass>';
CREATE ROLE agentsview_push_mac LOGIN PASSWORD '<push-pass>';
CREATE ROLE agentsview_read LOGIN PASSWORD '<read-pass>';

CREATE SCHEMA IF NOT EXISTS agentsview AUTHORIZATION agentsview_owner;

GRANT USAGE ON SCHEMA agentsview TO agentsview_read;
GRANT USAGE ON SCHEMA agentsview TO agentsview_push_mac;

GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push_mac;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push_mac;

ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT ON TABLES TO agentsview_read;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO agentsview_push_mac;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO agentsview_push_mac;
```

既存テーブルの owner が `agentsview_owner` ではない場合、default privileges は新規作成分に効かない。その場合は migration 後に上記の `GRANT ... ON ALL TABLES` / `GRANT ... ON ALL SEQUENCES` を再実行する。

初回 schema 作成と AgentsView upgrade 後の migration は `agentsview_owner` role で実行する。通常の app / local push では owner role を使わない。
`agentsview:setup:migrate` task は `flyctl proxy` を一時起動し、migration 後に proxy を停止する。`AGENTSVIEW_MIGRATION_PROJECTS` を設定すると小さい project だけで初回 migration を通せる。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<small-project>'

mise run agentsview:setup:migrate
```

migration 後に `GRANT ... ON ALL TABLES` / `GRANT ... ON ALL SEQUENCES` を再実行してから、local push 用の URL を `agentsview_push_mac` role に戻す。

#### 3. app secrets を設定

Fly app は公開 URL で参照されるが、`require_auth = true` と bearer token で API を閉じる。PostgreSQL 接続は `agentsview_read` role を使い、公開 viewer から DB へ書き込めないようにする。

```sh
mise run agentsview:fly:tokens
```

```sh
mise run agentsview:fly:secrets
```

手動で実行する場合:

```sh
AUTH=$(openssl rand -base64 32)
CURSOR=$(openssl rand -base64 32)

CONFIG_B64=$(
  printf 'public_url = "https://ryo-agentsview.fly.dev"\nrequire_auth = true\nauth_token = "%s"\ncursor_secret = "%s"\n\n[pg]\nallow_insecure = true\n' "$AUTH" "$CURSOR" \
  | base64 | tr -d '\n'
)

flyctl secrets set -a ryo-agentsview \
  AGENTSVIEW_PG_URL='postgres://agentsview_read:<read-pass>@psgl.flycast:5432/ryo_shellhistory?sslmode=disable' \
  AGENTSVIEW_CONFIG_TOML="$CONFIG_B64"

echo "Bearer token: $AUTH"  # 保管しておく
```

> `AGENTSVIEW_CONFIG_TOML` は Fly.io の `[[files]]` で `/data/config.toml` に展開されるため、secret には TOML を base64 encode した値を設定する。
> `public_url` は公開 URL / origin validation 用に入れる。
> `require_auth` / `auth_token` は env var 非対応のため config.toml 経由で渡す。
> `cursor_secret` は起動時の自動生成・config 書き戻しを避けるため、初回から明示する。
> `agentsview_read` role で schema migration が必要になった場合、`pg serve` は migration を skip して compatibility check に落ちる。AgentsView upgrade 後に migration が必要なときだけ、手元から `agentsview_owner` role で migration / push を実行し、完了後に app は read-only role のまま運用する。

> **PG 接続先の確認方法:** password を端末履歴・記録・画面共有へ露出させないため、`printenv` で接続文字列そのものを表示しない。private network の host は `psgl.flycast:5432`、database 名は `flyctl postgres db list -a psgl`、role 名は本手順で作成する `agentsview_*` を使う。password は fnox（bws）側にのみ保持し、URL を echo しない。
> `psgl.flycast` の Fly private network 経由では `sslmode=disable` + `[pg] allow_insecure = true` を使う。外部公開 host で TLS 接続する場合は `sslmode=require` + `allow_insecure = false` に戻す。

#### 4. デプロイ

```sh
# chezmoi source directory から実行する場合
flyctl deploy --app ryo-agentsview -c dot_config/agentsview/fly.toml
```

または mise task:

```sh
mise run agentsview:deploy
```

#### 5. 動作確認

```sh
# API が 401 を返すこと（認証必須）
curl -i https://ryo-agentsview.fly.dev/api/v1/sessions

# Bearer token で正常応答すること
curl -i -H "Authorization: Bearer <token>" https://ryo-agentsview.fly.dev/api/v1/sessions

# security headers が付いていること
curl -I https://ryo-agentsview.fly.dev
```

`curl -I` では少なくとも `Strict-Transport-Security`、`X-Content-Type-Options`、`X-Frame-Options`、`Referrer-Policy` が返ることを確認する。
`Content-Security-Policy` は AgentsView 本体も返すが、実行時の local/private origin が含まれることがあるため、Fly 側で追加した基本ヘッダーとは分けて見る。

### 複数 PC からのデータ push

各 PC から `mise run agentsview:pg:push` を実行するだけでよい。machine name（`AGENTSVIEW_PG_MACHINE`）は zsh 起動時に host-env.map の host-id から自動 export されるため（未設定なら `hostname` にフォールバック）、セッションは PC ごとに区別されて PostgreSQL に蓄積される。

#### 各 PC での設定

`agentsview:pg:status` / `agentsview:pg:push` / `agentsview:pg:dump` task は `flyctl proxy 15432:5432 -a psgl` を一時起動し、PostgreSQL が応答するまで待ってから `AGENTSVIEW_PROXY_PG_URL` を `AGENTSVIEW_PG_URL` として使い、実行後に proxy を停止する。

PostgreSQL client tools は mise で管理している。chezmoi の変更を反映してから install する。

```sh
chezmoi apply
mise install github:theseus-rs/postgresql-binaries
pg_isready --version
```

設定値は、shell に読み込まれているかと、AgentsView が実際に PostgreSQL へ接続できるかを分けて確認する。

```sh
# fnox exec 経由で値が解決できるか
# （URL には password が含まれるため、値そのものは表示せず有無だけ確認する）
fnox exec -- sh -c '[ -n "${AGENTSVIEW_PROXY_PG_URL:-}" ] && echo "AGENTSVIEW_PROXY_PG_URL is set" || echo "AGENTSVIEW_PROXY_PG_URL is unset"'

# proxy 起動込みで URL の host/db/schema に接続できるか
mise run agentsview:pg:status
```

push も proxy 起動込みで実行する。

```sh
mise run agentsview:pg:push
```

##### secure な local push 構成

目的は、`ryo-agentsview` app は Fly.io 上で起動したまま、ローカル PC から `agentsview pg push` だけを安全に実行すること。

推奨構成は、mise task が `flyctl proxy` を一時起動し、flyctl の user-mode WireGuard 経由で PostgreSQL へ接続する構成。PostgreSQL は public internet に出さない。

```text
local PC
  └─ mise run agentsview:pg:push
       └─ flyctl proxy 15432:5432 -a psgl
            └─ user-mode WireGuard
                 └─ psgl:5432
                      └─ agentsview schema
```

この構成では、ローカル PC から Fly private network までの通信は flyctl の user-mode WireGuard で保護される。AgentsView から見た DB host は `127.0.0.1` なので、local `~/.agentsview/config.toml` に `[pg] allow_insecure = true` を入れなくてよい。

`psgl.flycast` は Fly private network 用の host のため、WireGuard が有効でない通常のローカル DNS では名前解決できない。`lookup psgl.flycast: no such host` が出る場合は、DB URL や password ではなく private network への経路がないことが原因。
この repository の通常運用では、WireGuard client 常駐や `~/.agentsview/config.toml` の dotfiles 管理は採用しない。`flyctl proxy` を task 内で起動するため、local の AgentsView config に `[pg] allow_insecure = true` を追加する必要はない。

通常の push / status は proxy 起動と停止を task 内で行う。

```sh
mise run agentsview:pg:status
mise run agentsview:pg:push
```

`127.0.0.1` は local host なので、AgentsView の plaintext guard には通常止められない。

避ける構成:

- `psgl.flycast` を WireGuard なしで使う: local DNS では解決できない。
- PostgreSQL を public internet に出して `sslmode=disable` で使う: 通信経路が安全でない。
- DB password や bearer token を dotfiles に保存する: public repository に漏れるリスクがある。
- Fly app の `AGENTSVIEW_PG_URL` に push 用 role を使う: 公開 viewer 側が書き込み権限を持ってしまう。

public endpoint を使う場合だけ、PostgreSQL 側で TLS を有効にし、URL は `sslmode=require` または `sslmode=verify-full` にする。この場合は `[pg] allow_insecure = true` は不要。

hostname が重複しているか確認したい場合は明示的に指定:

```sh
AGENTSVIEW_PG_MACHINE="mac-work" mise run agentsview:pg:push   # PC ごとに異なる名前
```

#### push 操作

```sh
# 全プロジェクトを push
mise run agentsview:pg:push

# プロジェクトを絞って push（推奨）
mise run agentsview:pg:push -- --projects my-project,other-project

# 全 PC の同期状況確認（machine ごとの件数が表示される）
mise run agentsview:pg:status
```

Web UI（`https://ryo-agentsview.fly.dev`）で全 PC のセッションを一覧できる。

#### `agentsview pg serve` と `agentsview serve` の違い

| command               | backend      | 表示するsession                                             | このrepositoryでの用途           |
| --------------------- | ------------ | ----------------------------------------------------------- | -------------------------------- |
| `agentsview pg serve` | PostgreSQL   | 複数PCからpushしたsession、またはdumpからrestoreしたsession | **通常のlocal / Fly viewer**     |
| `agentsview serve`    | local SQLite | そのPCがlocal sourceから収集したsession                     | SQLite固有の調査が必要な場合のみ |

`agentsview pg serve` は設定されたPostgreSQLを直接読むviewerであり、PostgreSQLの内容を
`~/.agentsview/*.sqlite`へpullするcommandではない。反対に、`agentsview serve` は
local SQLiteを読み、PostgreSQLへpush済みの他PCのsessionやPostgreSQL dumpを自動的には表示しない。

```sh
mise run agentsview:serve
```

恒久運用は、`AGENTSVIEW_PROXY_PG_URL` を fnox（bws）に持たせ、PC ごとに変えたい場合だけ
`AGENTSVIEW_PG_MACHINE` を実行時に指定し、必要なときに `mise run agentsview:pg:push` を実行する
形にする。自動常駐 push や `~/.agentsview/config.toml` への DB URL 保存は、この repository では採用しない。

#### push 時間について（初回が遅い理由）

初回の全件 push は数時間かかることがある（例: 1353 セッション / 42894 メッセージで約 3h35m）。これは **帯域ではなく往復レイテンシ律速** で、この構成では想定内の挙動。

- push は `flyctl proxy 15432:5432 -a psgl`（user-mode WireGuard）経由で `nrt` リージョンの PostgreSQL に接続するため、全クエリがトンネル越しに東京まで往復する。
- 出力の `Connected to PostgreSQL in 2.89s` や、DDL 数本だけの `PostgreSQL schema ready in 21.122s` が、1 往復あたりのレイテンシが高いことを示すカナリア。行ごとの round-trip 回数 × RTT がそのまま積み上がる。
- **重要: 通常の差分 push では初回だけのコスト。** 2 回目以降は新規セッションや既存セッションの更新だけを push し、`--full` を指定した場合は全件再送のため同じ遅延が再発する。

初回のバルクロードを速くしたい場合の選択肢（任意）:

```sh
# 実 RTT を確認（自宅から遠いと WireGuard の RTT がそのまま効く）
flyctl ping psgl

# リージョン内から実行して RTT を減らす、あるいは初回だけ pg_dump / COPY で
# バルク投入する方法もある。差分運用に入れば体感問題にはならないため、
# 通常は初回の遅さは許容してよい。
```

### データ管理

`pg push` は一方向同期のため、リモート DB のデータは増加し続ける。

#### 容量確認

```sh
flyctl postgres connect -a psgl
```

```sql
SELECT pg_size_pretty(COALESCE(sum(pg_total_relation_size(relid)), 0))
FROM pg_statio_user_tables
WHERE schemaname = 'agentsview';
```

#### 古いデータの削除

```sql
DELETE FROM agentsview.sessions WHERE created_at < NOW() - INTERVAL '6 months';
VACUUM agentsview.sessions;
```

#### バックアップとlocal viewerへのrestore

CockroachDB移行後は`agentsview:pg:remote-local:dump`がCockroachDBの**dataだけ**をcolumn名付きINSERTとしてexportし、現在versionのschemaを持つlocal PostgreSQLへ不足rowをmergeする。その後、このmachineのsessionをlocal PostgreSQLへpushしてcustom-formatの統合dumpを作成する。CockroachDB固有のDDL、role、sequenceはPostgreSQLへrestoreしない。

旧Fly PostgreSQL用の同じ処理は`agentsview:pg:fly:remote-local:dump`として残す。Fly PostgreSQLが容量保護でread-onlyになっていてもdumpは取得できる。

```sh
# CockroachDB上の既存データと、このmachineのsessionをlocal PostgreSQLへ
# mergeし、PostgreSQL custom-formatの統合dumpを作成
mise run agentsview:pg:remote-local:dump

# migration前／rollback用: Fly PostgreSQLをsourceとして同じ処理を行う
mise run agentsview:pg:fly:remote-local:dump

# Fly PostgreSQLをbackup
mise run agentsview:pg:dump

# backupをfzfで選択してlocal PostgreSQLへrestore
mise run agentsview:pg:local:restore

# machineごとのsession件数を確認
mise run agentsview:pg:local:status

# serveを起動せずlocal sessionだけを差分push
mise run agentsview:pg:local:push

# merge済みのlocal PostgreSQLをbackup（このmachineのsessionを差分pushしてからdumpする）
mise run agentsview:pg:local:dump

# local PostgreSQLを使って agentsview pg serve を起動
mise run agentsview:serve
# open http://127.0.0.1:8080

# local PostgreSQLを停止
mise run agentsview:pg:local:down
```

ほかのmachineにも未pushデータがある場合は、各machineで`agentsview:pg:local:dump`を実行し（差分pushを含む）、作成された`agentsview-local-*.dump`を集約先へコピーする。集約先でdumpごとに次を実行し、最後にもう一度`agentsview:pg:local:dump`を実行する。

```sh
AGENTSVIEW_RESTORE_DUMP=/path/to/agentsview-local-other-machine.dump \
  mise run agentsview:pg:local:restore
mise run agentsview:pg:local:dump
```

`agentsview:pg:local:dump`は、local PostgreSQLに`agentsview` schemaが無い場合はdumpせずに終了し、先に実行すべきtaskを表示する。schemaはlocal pushかrestoreで作成される。

CockroachDB exportは`agentsview-cockroach-data-*.sql`、最終的なlocal PostgreSQL backupは`agentsview-local-*.dump`として`AGENTSVIEW_BACKUP_DIR`へ保存される。data importはtransaction内で実行され、schema／型の非互換や途中のINSERT失敗があればlocal PostgreSQLへのmerge全体をrollbackする。同じprimary keyがlocalにある場合はlocal rowを維持するため、これはCockroachDBの完全replicaではなく、disaster recovery／閲覧用の統合backupである。

特定 PC のデータのみ削除したい場合:

```sql
DELETE FROM agentsview.sessions WHERE machine = 'mac-old';
```

### GitHub Actions でのデプロイ

`dot_config/agentsview/fly.toml` または workflow 自体を main branch に merge すると `deploy-agentsview` workflow が実行される。

```yaml
- name: Deploy AgentsView
  run: flyctl deploy --app ryo-agentsview -c dot_config/agentsview/fly.toml
  env:
    FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### token の更新

通常は `AUTH` と `CURSOR` を再生成しない。Bearer token をローテーションしたい場合だけ `AUTH` を更新し、`CURSOR` は既存値を維持する。
既存値を保存していない場合は両方を再生成してよいが、Bearer token は変わる。

```sh
AUTH="<existing-or-new-auth-token>"
CURSOR="<existing-cursor-secret>"

CONFIG_B64=$(
  printf 'public_url = "https://ryo-agentsview.fly.dev"\nrequire_auth = true\nauth_token = "%s"\ncursor_secret = "%s"\n\n[pg]\nallow_insecure = true\n' "$AUTH" "$CURSOR" \
  | base64 | tr -d '\n'
)

flyctl secrets set -a ryo-agentsview \
  AGENTSVIEW_CONFIG_TOML="$CONFIG_B64"

echo "Bearer token: $AUTH"
```

### デプロイ状況メモ

#### 根本原因（2026-06-10 特定）

最終的に必要だった修正は以下。

1. Fly.io の `[[files]]` で使う `AGENTSVIEW_CONFIG_TOML` は base64 encode して secret に設定する。
2. `AGENTSVIEW_CONFIG_TOML` には `public_url`、`require_auth`、`auth_token`、`cursor_secret` を含める。
3. Fly app から `psgl.flycast` へ private network 経由で接続する場合は、`sslmode=disable` と `[pg] allow_insecure = true` を使う。
4. 公開 viewer の `AGENTSVIEW_PG_URL` は read-only role、local push の `AGENTSVIEW_PROXY_PG_URL` は push role に分ける。

`cursor_secret` は起動時に config へ自動生成・書き戻しされるが、Fly の `[[files]]` で注入した `/data/config.toml` は secret から再生成されるため、起動時の書き戻しに依存しない。初回 secrets 設定時から `cursor_secret` を明示する。

`AGENTSVIEW_AUTH_TOKEN` 環境変数は AgentsView v0.29.0 の env loader では読まれない。`require_auth` / `auth_token` / `cursor_secret` は `AGENTSVIEW_CONFIG_TOML` から `/data/config.toml` に注入する。

`psgl.flycast` に `sslmode=require` で接続すると、private network 側の PostgreSQL 接続では TLS startup に失敗することがある。Fly app 側は private network 内接続として `sslmode=disable` を使い、AgentsView の plaintext guard は `/data/config.toml` の `[pg] allow_insecure = true` で明示的に許可する。

#### 現状（2026-06-10）

- `dot_config/agentsview/fly.toml` は作成済み。
- 公式 image `ghcr.io/wesm/agentsview:0.29.0` を使用し、`PG_SERVE=1` で `agentsview pg serve` を起動する。
- `[[files]]` で `/data/config.toml` を base64 encoded secret から注入する。
- Fly.io app `ryo-agentsview` は作成済み。
- secrets は `AGENTSVIEW_CONFIG_TOML` と `AGENTSVIEW_PG_URL` を使う。
- security headers と HTTPS 強制は `fly.toml` に設定済み。
- setup / deploy / local push は `dot_config/mise/tasks/agentsview.toml` の `agentsview:*` task に集約済み。
- `dot_config/agentsview/fly.toml` の main merge 時 deploy は `.github/workflows/deploy-agentsview.yaml` で自動化済み。

#### 次の確認

Bearer token なし API が `401` を返すことを確認する。

```sh
curl -i https://ryo-agentsview.fly.dev/api/v1/sessions
```

保存済み bearer token 付き API が `200` 系を返すことを確認する。`AUTH` と `CURSOR` は通常ローテーション不要で、保存済みの値があれば再利用する。

```sh
curl -i -H "Authorization: Bearer <auth_token>" https://ryo-agentsview.fly.dev/api/v1/sessions
```

各 PC の `AGENTSVIEW_PROXY_PG_URL` が `fnox exec --` 経由で解決できることと、AgentsView が proxy 経由で DB に接続できることを確認する。

```sh
fnox exec -- sh -c '[ -n "${AGENTSVIEW_PROXY_PG_URL:-}" ] && echo set || echo unset'
mise run agentsview:pg:status
```

1プロジェクトだけ先に push し、migration とデータ増加を確認する。

```sh
mise run agentsview:pg:push -- --projects <project>
mise run agentsview:pg:status
```

最後に Web UI で push した session が表示されることを確認する。

```sh
open https://ryo-agentsview.fly.dev
```
