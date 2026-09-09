# agentsview pg-sync

複数端末のセッション情報をCockroachDB Cloudに集約し、Cloud Run上のread-only Web UIで参照する構成。

> [!IMPORTANT]
> Fly.ioからの移行は完了している。Fly上のAgentsView app（`ryo-agentsview`）と`agentsview` schema／roleは削除済みで、rollback先は存在しない。Atuinは引き続きFly.io（`psgl`／`ryo-shellhistory`）を使う。新規構築は[Cloud Run／CockroachDBへの移行手順](#cloud-runcockroachdbへの移行手順)を上から順に実行する。

## 実装済みファイル

| ファイル                                             | 目的                                                                                                                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `dot_config/agentsview/Dockerfile`                   | upstream AgentsView imageをArtifact RegistryへmirrorするCloud Build context。`FROM`のtagがdeployするAgentsView version                                       |
| `dot_config/agentsview/cloudrun-service.yaml`        | clrndが所有するCloud Run Service manifest（Knative形式）。image、resource、scaling、環境変数、Secret Manager参照                                             |
| `dot_config/agentsview/clrnd.yml`                    | clrnd設定。region、service名、manifest pathだけを持ち、project IDはcommitしない                                                                              |
| `dot_config/agentsview/scripts/cloudrun.sh`          | Cloud Run系taskの実体。設定解決、image URIの組み立て、secret versionのpin、Cloud Build、clrnd実行                                                            |
| `dot_config/agentsview/compose.yaml`                 | local検証用PostgreSQLのDocker Compose定義                                                                                                                    |
| `dot_config/agentsview/executable_prepare-dump-auth` | dump／psql用に一時`.pgpass`を作り、passwordをprocess引数へ出さないためのhelper                                                                               |
| `dot_config/mise/tasks/agentsview.toml`              | `agentsview:*` task。secret登録、build／deploy／diff／status／rollback、local PostgreSQL、CockroachDBへのpush                                                |
| `dot_config/mise/config.toml`                        | clrnd、terraform、gcloud、postgresql-binariesなどのversion pin                                                                                               |
| `terraform/agentsview/*.tf`                          | CockroachDB、Artifact Registry、runtime／deploy service account、Secret Manager container／IAM、Cloud Run invoker IAM、GitHub ActionsのWorkload Identity連携 |
| `.github/workflows/deploy-agentsview.yaml`           | mainへのmergeでCloud Run関連fileに差分があったときだけbuild → deployを実行するworkflow                                                                       |

各ファイルを変更したあとの適用手順は[運用: インフラ設定を変更したあとの適用手順](#運用-インフラ設定を変更したあとの適用手順)にある。

## Cloud Run／CockroachDBへの移行手順

対象構成:

- Atuin app／PostgreSQL: Fly.ioに残す（`psgl`／`ryo-shellhistory`）
- AgentsView app: Google Cloud Run
- AgentsView DB: CockroachDB Cloud Basic

AgentsViewのsource of truthは各PCのlocal SQLite archiveであり、CockroachDBはそこからの派生である。Atuinのdatabase／role／appには触れない。

### ゼロから構築する場合の全体手順

この節から順番に実行すれば、空のGoogle Cloud projectとCockroachDB Cloud accountから、Cloud Run viewerを起動できる。コマンドはrepository rootから開始し、`<...>`は自分の値へ置き換える。

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

Terraformはservice accountのAPI keyでCockroachDB Cloud APIを呼ぶ。**1. service accountを作成**し、**2. そのservice accountでAPI keyを発行**する、という2段階である。

**1. サービスアカウントを作成する（未作成の場合）**

1. [CockroachDB Cloud Console](https://cockroachlabs.cloud/)へloginし、organizationを作成または選択する。
2. 左navigationの**Access Management**ページを開く。
3. **Service Accounts** tabを選択する。
4. **Create**をクリックする。
5. **Account name**と**Description**を入力して作成する。

作成直後のservice accountは`Organization Member`だけを持ち、cluster作成権限がない。**Actions > Edit Roles**を開き、organization scopeで**Cluster Creator**を付与する。既存clusterも含めて管理させる必要がある場合だけ**Cluster Admin**を使う。

**2. API Key を発行する**

1. **Access Management**ページの**Service Accounts** tabを開く。
2. API Keyを作成したいservice accountをクリックし、**Service Account Details**ページを開く。
3. **Create API Key**をクリックする。
4. **API key name**を入力し、**Create**をクリックする。
5. 表示された**Secret key**をコピーして安全な場所に保存する。

Secret keyは`CCDB1_...`形式で、**画面を閉じると二度と表示できない**。直ちにBitwarden Secrets Managerへ`COCKROACH_API_KEY`として保存する。保存するのはSecret key全体であり、API keyのnameやUUIDではない。

###### CLI準備

repository rootでtoolをinstallし、versionを確認する。

```sh
mise trust
mise install

git --version
mise --version
fnox --version
gcloud version
fnox exec -- terraform version
psql --version
pg_dump --version
docker version
```

Google Cloudへloginする。

```sh
gcloud auth login
gcloud auth application-default login
```

**完了確認:** Google Cloud Consoleでprojectとbudgetが見え、CockroachDB service accountにorganization scopeの`Cluster Creator`が表示され、その`CCDB1_...` secretがsecret storeに保存され、上記commandがすべてversionを返す。

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

```sh
export GCP_PROJECT_ID='<google-cloud-project-id>'
export GCP_REGION='us-west2'
export TF_STATE_BUCKET="${GCP_PROJECT_ID}-terraform-state"
export TF_VAR_gcp_project_id="$GCP_PROJECT_ID"

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
  terraform/agentsview/terraform.tfvars
rm -f terraform/agentsview/terraform.tfvars.bak
```

次に[Bitwarden Secrets Manager](https://vault.bitwarden.com/#/sm)で、`dot_config/fnox/config.toml`の`providers.bws.project_id`と同じprojectを開く。**Secrets > New secret**から次の4件を、名前の大文字・小文字も完全一致させて作成する。

| Secret name                       | Value                                                      |
| --------------------------------- | ---------------------------------------------------------- |
| `COCKROACH_API_KEY`               | Terraform用service accountで発行した`CCDB1_...` Secret key |
| `TF_VAR_cockroach_owner_password` | 作業2で生成したowner用16進password                         |
| `TF_VAR_cockroach_push_password`  | 作業2で生成したpush用16進password                          |
| `TF_VAR_cockroach_read_password`  | 作業2で生成したread用16進password                          |

Bitwarden Secrets Managerの**Machine accounts**で、`BWS_ACCESS_TOKEN`を発行したmachine accountを開き、上記projectへのread accessがあることも確認する。別projectへsecretを作った場合や、machine accountにproject accessがない場合、mappingが表示されても`secret ... not found`になる。

4件を個別に取得できるか確認する。値をterminalへ表示しない。

```sh
for name in \
  COCKROACH_API_KEY \
  TF_VAR_cockroach_owner_password \
  TF_VAR_cockroach_push_password \
  TF_VAR_cockroach_read_password; do
  test -n "$(fnox get "$name")" || { echo "$name=missing" >&2; exit 1; }
  echo "$name=set"
done
```

###### `Error acquiring the state lock`が出た場合

`googleapi: Error 412: ... conditionNotMet`は認証失敗やCockroachDB secret不足ではない。GCS backendの`agentsview/default.tflock`が既に存在し、別のTerraform processが同じstateを操作中、または以前中断したprocessのlockが残っていることを示す。提示されたlockは`Who: ryo.@Mac`、`Created: 2026-09-05 08:50:00 UTC`なので、同じMacで先に実行したplanが異常終了または中断され、lockだけが残った可能性が高い。`gcloud auth application-default login`は正常に完了しており、このlock errorの原因ではない。

まず同じstateを操作しているprocessがないことを確認する。別terminal、IDE task、CIのTerraform applyが実行中なら、force unlockせず完了を待つ。

```sh
ps aux | rg '[t]erraform.*agentsview' || true
gh run list --limit 10
```

実行中processがなく、Lock Infoの`Who`と`Created`が自分の中断した実行に一致すると確認できた場合だけ、表示されたIDでlockを解除する。提示された例のIDは`1788598201425938`だが、実行時は必ず最新errorに表示されたIDを使う。確認promptには内容を確認して`yes`と答える。

```sh
fnox exec -- terraform -chdir=terraform/agentsview force-unlock 1788598201425938
fnox exec -- terraform -chdir=terraform/agentsview plan -input=false
```

別processが実行中のままforce unlockすると、同じstateへ同時書き込みして破損させる可能性がある。GCS上の`.tflock`を手動削除せず、通常運用で`-lock=false`も使用しない。解除後も直ちに同じlockが作られる場合は、別processが動いているため停止して調査する。

初期化と静的確認を行う。

```sh
fnox exec -- terraform -chdir=terraform/agentsview init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config='prefix=agentsview'
fnox exec -- terraform -chdir=terraform/agentsview fmt -check -recursive
fnox exec -- terraform -chdir=terraform/agentsview validate
```

初回だけ、`google_cloud_run_v2_service_iam_member.public`**以外のすべて**をtarget applyする。invoker bindingだけは、clrndがCloud Run Serviceを作った後（作業8）でないと「service not found」で失敗するため外す。

この一覧はこのrunbookで唯一のbootstrap target一覧で、2.3節と復旧手順もこれを参照する。特に次は作業6・作業8より前に必要なので落とさない。

- `google_artifact_registry_repository_iam_member.cloud_build_writer`: 作業6の`gcloud builds submit`がbuildしたimageをpushできない。
- `google_secret_manager_secret_iam_member.runtime_*`: Cloud Runはrevision作成時にruntime service accountがsecretを読めることを検証する。
- `google_artifact_registry_repository_iam_member.runtime_reader`: revision起動時のimage pullに必要。

planを読み、別projectや既存resourceを変更しないことを確認して`yes`を入力する。

```sh
fnox exec -- terraform -chdir=terraform/agentsview apply \
  -target=google_project_service.required \
  -target=google_artifact_registry_repository.agentsview \
  -target=google_artifact_registry_repository_iam_member.cloud_build_writer \
  -target=google_artifact_registry_repository_iam_member.runtime_reader \
  -target=google_secret_manager_secret.pg_url \
  -target=google_secret_manager_secret.config \
  -target=google_secret_manager_secret_iam_member.runtime_pg_url \
  -target=google_secret_manager_secret_iam_member.runtime_config \
  -target=google_service_account.runtime \
  -target=cockroach_cluster.agentsview \
  -target=cockroach_database.agentsview \
  -target=cockroach_sql_user.owner \
  -target=cockroach_sql_user.push \
  -target=cockroach_sql_user.read
```

CockroachDB Consoleの**Clusters**で`agentsview` clusterが`Basic`としてReadyになり、**SQL Users**にowner／push／readが表示されることを確認する。Google Cloud ConsoleではArtifact Registry repository、2つのSecret Manager secret container、service accountが作成されていることを確認する。

**完了確認:** 次がID、database名、SQL hostを返す。

```sh
fnox exec -- terraform -chdir=terraform/agentsview output cockroach_cluster_id
fnox exec -- terraform -chdir=terraform/agentsview output cockroach_database
fnox exec -- terraform -chdir=terraform/agentsview output cockroach_sql_host
```

###### Cloud Run serviceがtaintedのまま残っている場合

以前のTerraform構成でCloud Run Serviceを作った環境では、失敗したserviceがstate上でtaintedとして残っていることがある。planに次が出るのがその状態である。

```text
# google_cloud_run_v2_service.agentsview is tainted, so must be replaced
```

現在のコードはCloud Run Serviceを管理しないため、この状態のままapplyすると「削除」計画になり、旧stateの`deletion_protection = true`によって次のerrorで止まる。

```text
Error: cannot destroy service without setting deletion_protection=false and running `terraform apply`
```

**taintを解除してTerraformで作り直すのではなく、2.0.4の手順でstateからownershipを外す。** 実serviceはGoogle Cloud上に残り、以降はclrndが所有する。

```sh
fnox exec -- terraform -chdir=terraform/agentsview untaint google_cloud_run_v2_service.agentsview || true
fnox exec -- terraform -chdir=terraform/agentsview state rm google_cloud_run_v2_service.agentsview
fnox exec -- terraform -chdir=terraform/agentsview state rm google_cloud_run_v2_service_iam_member.public || true
```

CockroachDB clusterはpersistent dataを持つため`delete_protection = true`を維持する。

state整理のあとは、**この段階で通常applyを実行しない。** Cloud Run Serviceはまだclrndが作っていないため、通常applyに含まれる`google_cloud_run_v2_service_iam_member.public`が「service not found」で失敗する。作業4の`-target=`付きapplyをそのまま再実行して、失敗したCockroachDB clusterと土台resourceだけを収束させる。

作業4と同じ`-target=`一覧をそのまま使う（Cloud Runのinvoker bindingだけを除いた全resource）。

失敗前に作った`tfplan`は再利用しない。通常のplan／applyは作業8で、clrndがserviceを作った後に実行する。そこで初めてCloud Run関連の変更が`google_cloud_run_v2_service_iam_member.public`の作成1件だけになる。`us-central1`のimageで作られた失敗revisionは、正しい`us-west2` imageでclrnd deployすれば置き換わる。

##### 作業5. CockroachDB接続URL、schema、最小権限を作る

Terraform outputでhostとdatabaseを確認する。passwordはfnoxの子processだけへ渡すため、現在のshellへ`export`しない。

```sh
fnox exec -- terraform -chdir=terraform/agentsview output -raw cockroach_sql_host
fnox exec -- terraform -chdir=terraform/agentsview output -raw cockroach_database
```

Bitwarden Secrets ManagerのUIで、作業2に保存した各passwordと上記outputを使い、次のtemplateから3本のURLを作成する。16進passwordなので追加のURL encodeは不要である。

```text
postgresql://agentsview_owner:<owner password>@<SQL host>:26257/<database>?sslmode=verify-full
postgresql://agentsview_push:<push password>@<SQL host>:26257/<database>?sslmode=verify-full
postgresql://agentsview_read:<read password>@<SQL host>:26257/<database>?sslmode=verify-full
```

3本をBitwarden Secrets Managerへ同名で登録する。CockroachDB Consoleの**Connect**画面が別port、database、CA指定を案内した場合は、手作業で組み立てた値よりConsoleの接続文字列を優先し、usernameとpasswordだけ各role用に差し替える。

まずlocal AgentsViewに存在するprojectをsession数の少ない順に表示する。

```sh
agentsview projects --format json |
  jq -r 'sort_by(.session_count)[] | select(.name != "" and .session_count > 0) | [.session_count, .name] | @tsv'
```

出力の1列目はsession数、2列目が`--projects`へ渡すproject名である。最初はsession数が少なく、内容を確認できるprojectを1つ選ぶ。例えば実際の一覧に`dotfiles`があれば次のように設定する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='dotfiles'
fnox exec -- sh -c '
  AGENTSVIEW_PG_SCHEMA=agentsview \
  AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_OWNER_PG_URL" \
    agentsview pg push --no-vectors --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
'
```

もしエラーが出た場合は、接続を確認する。

```sh
fnox exec -- sh -c '
  psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -v ON_ERROR_STOP=1 \
    -c "SELECT current_user, current_database();"
'
```

`root certificate file "~/.postgresql/root.crt" does not exist`は、password認証へ到達する前にlibpqがCA bundleを見つけられていない状態である。`PGSSLROOTCERT=system`の後に`SSL error: certificate verify failed`へ変わる場合、使用中の`psql`がlinkするOpenSSLのdefault trust storeが空またはmacOS Keychainと連携していない。`system`を続けて使わず、上記のように実在するCA bundleを明示する。

macOSでは最初に`/etc/ssl/cert.pem`を使う。これは`MISE_ENV`に`mac`を含むhostで読み込まれるため、mise shell activation後の`fnox exec`、`psql`、AgentsViewに共通して適用される。既に開いているshellには遡って反映されないので、chezmoi適用後に新しいshellを開くか上記の`exec zsh`を実行する。

`/etc/ssl/cert.pem`が存在しないmacOS hostでは、`dot_config/mise/config.mac.toml`の値を次のHomebrew OpenSSL bundleへ変更し、chezmoiを再適用する。

```sh
export PGSSLROOTCERT="$(brew --prefix openssl@3)/etc/openssl@3/cert.pem"
test -r "$PGSSLROOTCERT"
```

Linuxでは通常`/etc/ssl/certs/ca-certificates.crt`を使う。どのOSでも`test -r`が成功してから接続し、`sslmode=disable`やhostnameを検証しない設定へ弱めない。migration scriptはこれらの既知のpathからreadableなCA bundleを自動選択する。

このcommandもSQLSTATE `28P01`になる場合、TerraformがSQL userへ設定した`TF_VAR_cockroach_owner_password`と、後から手作業で作った`AGENTSVIEW_COCKROACH_OWNER_PG_URL`内のpasswordが一致していない。特に、SQL user作成後にBitwardenの`TF_VAR_cockroach_owner_password`だけを更新した場合や、URLへ別userのpasswordを貼った場合に発生する。

5. 上記`psql`を再実行し、`current_user`が`agentsview_owner`になることを確認してから`agentsview pg push`へ進む。

CockroachDB Console等でpasswordを別途変更していない前提で、planが`No changes`なのにURLだけが28P01になる場合、URL secretだけが誤っている可能性が高い。`TF_VAR_cockroach_owner_password`と同じ値で`AGENTSVIEW_COCKROACH_OWNER_PG_URL`を作り直し、Terraform applyは行わず`psql`を再試行する。Consoleで変更した履歴がある場合は、planの有無にかかわらず上記rotationを実施してTerraformをsource of truthへ戻す。

続いて最小権限を設定する。CockroachDB CloudのConsole／APIで作成したSQL userは初期状態で`admin` roleに所属する。そのため、`GRANT SELECT`だけを追加しても既存の`admin`権限は消えず、read userは書き込み可能なままである。最初にpush／read userから`admin`を`REVOKE`する必要がある。

bootstrap時に一度だけ行う操作なのでmise taskにはしない。owner接続の`psql`で次を実行する。passwordをcommand historyやprocess引数へ出さないよう、URLはfnox経由で渡す。

```sh
fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -v ON_ERROR_STOP=1' <<'SQL'
-- CockroachDB CloudはConsole／APIで作ったSQL userをadminのmemberにする。
-- 応用側の権限を付ける前に、継承された広い権限を外す。
REVOKE admin FROM agentsview_push, agentsview_read;

-- schemaとtableの最小権限。push userにだけ、schema syncに必要なCREATEを与える。
GRANT USAGE ON SCHEMA agentsview TO agentsview_read;
GRANT CREATE, USAGE ON SCHEMA agentsview TO agentsview_push;
GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push;

-- owner／push userが今後作るtableにも同じ最小権限が適用されるようにする。
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT ON TABLES TO agentsview_read;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO agentsview_push;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO agentsview_push;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_push IN SCHEMA agentsview
  GRANT SELECT ON TABLES TO agentsview_read;
SQL
```

read userが読めて書けないことを必ず検証する。`SELECT`の失敗やnetwork／TLS errorを成功扱いにしないこと。

```sh
# SELECTは成功する
fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_READ_PG_URL" -X -v ON_ERROR_STOP=1 \
  -c "SELECT count(*) FROM agentsview.sessions;"'

# DELETEは SQLSTATE 42501（permission denied）で失敗する
fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_READ_PG_URL" -X -v ON_ERROR_STOP=1 \
  --set=VERBOSITY=verbose -c "DELETE FROM agentsview.sessions WHERE 1=0"'
```

`REVOKE`前に`DELETE 0`が返るのは、対象rowが0件だっただけで権限検査には成功している状態である。`REVOKE`後は同じstatementが`permission denied`になる。ここで`DELETE 0`が返る場合は`REVOKE`が効いていない。

macOSでは`PGSSLROOTCERT`が必要になる（`dot_config/mise/config.mac.toml`が`/etc/ssl/cert.pem`を設定する）。TLS errorが出る場合は`echo $PGSSLROOTCERT`で読めるpathになっているか確認する。

**完了確認:** ownerでschemaが作成され、push userで`agentsview pg status`が成功し、read userの`SELECT`は成功、DMLはpermission deniedになる。

##### 作業6. Artifact Registryへ最初のimageをbuildする

Cloud Buildのdefault build service accountと、Artifact Registry repositoryに付与されたwriter権限をCLIで確認する。**Cloud Build > Settings**はbuild service accountが別serviceの権限を持つかを確認する画面ではなく、repository-level IAMは表示されない。Terraform applyのlogにある`google_artifact_registry_repository_iam_member.cloud_build_writer`の`Refresh complete`／`No changes`は、候補となる両方のservice accountへのwriter bindingが既にstateと実環境に存在することを示す。

```sh
BUILD_SA=$(gcloud builds get-default-service-account \
  --project="$GCP_PROJECT_ID")
printf 'Cloud Build default service account: %s\n' "$BUILD_SA"

gcloud artifacts repositories get-iam-policy agentsview \
  --project="$GCP_PROJECT_ID" \
  --location=us-west2 \
  --flatten='bindings[].members' \
  --filter="bindings.role:roles/artifactregistry.writer AND bindings.members:serviceAccount:${BUILD_SA}" \
  --format='table(bindings.role,bindings.members)'
```

結果にdefault service accountと`roles/artifactregistry.writer`が1行表示されれば付与済みである。Consoleで見る場合は**Artifact Registry > Repositories > agentsview > Permissions**を開く。何も表示されない場合だけ、最新Terraformを通常の`plan`／`apply`で反映し直す。日常運用で長い`-target` applyを繰り返さない。

`terraform.tfvars`に廃止済みの`agentsview_image`が残っている場合は、build前に削除する。これはwriter権限とは無関係だが、Terraformのundeclared variable warningを解消する。

```sh
sed -i.bak '/^[[:space:]]*agentsview_image[[:space:]]*=/d' terraform.tfvars
rm -f terraform.tfvars.bak
```

次に、現在のdirectoryにかかわらずmise taskでimageをbuildする。task wrapperは`build` modeを通常のshell script引数として渡すため、inline `bash -c`の末尾へmodeが連結されない。

```sh
if AGENTSVIEW_IMAGE=$(mise run agentsview:cloudrun:build) &&
  test -n "$AGENTSVIEW_IMAGE"; then
  printf 'AGENTSVIEW_IMAGE=%s\n' "$AGENTSVIEW_IMAGE"
  gcloud artifacts docker images describe "$AGENTSVIEW_IMAGE" \
    --project="$GCP_PROJECT_ID" --format='value(image_summary.digest)'
else
  echo 'Cloud Build failed; Artifact Registryの確認を中止します' >&2
fi

```

interactive shellはcommandが失敗しても次の行を実行し続ける。したがって、代入、`test`、`gcloud artifacts ... describe`を独立したcommandとして貼らない。上記の`if`を使えばbuild失敗時に空の`AGENTSVIEW_IMAGE`を`gcloud`へ渡さない。

tagは`<upstream version>-<commit>`（例: `0.38.1-e310d8af1f32`）になる。commitが変われば別tagになるため、別のcommitのimageで同じURIを上書きすることがない（同一commitでのrebuildは同じtagを作り直す）。build contextに未commitの変更がある場合はtagへ`-dirty`が付き、警告が出る。

Google Cloud Consoleの**Artifact Registry > Repositories > agentsview**でそのtagとdigestが表示されることを確認する。

**完了確認:** 最後のcommandが`sha256:...`を返す。

##### `HealthCheckContainerError`で初回revisionが起動しない場合

このerrorは「containerがPORT=8080でlistenしなかった」という結果だけを示す。`agentsview pg serve`はlistenを開始する**前**に一連のcheckを実行し、どれか1つでも失敗するとprocessがexitする。したがって原因はほぼ常にlisten以前の失敗であり、bind addressやstartup probeのtimeoutではない。

`pg serve`がlistenするまでに通る、失敗するとexitする処理は次の順である。

| 順  | 処理                                  | 失敗時のlog                           |
| --- | ------------------------------------- | ------------------------------------- |
| 1   | configの読み込み（lock取得を伴う）    | `loading config file:`                |
| 2   | `cursor_secret`の生成（未設定時のみ） | `ensuring cursor secret:`             |
| 3   | `auth_token`の生成（未設定時のみ）    | `pg serve: generating auth token:`    |
| 4   | CockroachDBへの接続                   | `pg serve:`（`28P01`／TLS errorなど） |
| 5   | schema互換check                       | `pg serve: schema incompatible:`      |
| 6   | data version互換check                 | `pg serve:`                           |

**最初にrevision logを読む。** 原因はここにしか出ない。

```sh
gcloud run services logs read ryo-agentsview \
  --project="$GCP_PROJECT_ID" \
  --region=us-west2 \
  --limit=100
```

logの最初のerror行に応じて対処する。

- **`schema migration failed: database data version N is newer than this agentsview binary's data version M`** — CockroachDBへpushしたAgentsViewが、Cloud Run imageのAgentsViewより新しい。viewerは古いdata versionのbinaryでは新しいarchiveを開けない。`dot_config/agentsview/Dockerfile`の`FROM`をpush側と同じversionへ上げ、**再buildしてdeployする**（tagは`FROM`のversionから作られるため`AGENTSVIEW_SKIP_BUILD=1`は使えない）。data versionとreleaseの対応は`internal/db/db.go`の`const dataVersion`にある（74 = v0.39.0、79 = v0.40.0、88 = v0.41.0、96 = v0.42.0）。
- **`/api/v1/sessions/sidebar-index`だけが極端に遅い（`--write-timeout`を延ばしても切れる）** — まず`EXPLAIN ANALYZE`で、時間がどこで消えているかを確定させる。**件数やindexの問題とlock待ちは対処が正反対**なので、ここを飛ばさない。

  ```sh
  fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -c "
  EXPLAIN ANALYZE
  SELECT count(*) FROM agentsview.sessions
  WHERE deleted_at IS NULL
    AND COALESCE(ended_at, started_at, created_at) >= now() - INTERVAL '"'"'7 days'"'"';"'
  ```

  出力の`cumulative time spent due to contention`と`sql cpu time`を比べる。

  **contentionがexecution timeのほとんどを占める場合（lock待ち）。** これが実際に起きたcaseである。`sql cpu time: 4ms`／`KV rows decoded: 4,367`に対して`KV contention time: 1m22s`だった。表が小さく全走査自体は一瞬なので、indexを足しても直らない。`sessions`へ書き込みintentを残したまま終わっていないtransactionが原因である。中断した`agentsview pg push`や`pg watch`が典型。

  ```sh
  # 実行中transactionを古い順に見る。startが極端に古いものが原因。
  fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -c "
  SELECT id, session_id, start, application_name, num_stmts
  FROM crdb_internal.cluster_transactions ORDER BY start;"'

  # sessions表で待たされているlockを見る
  fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -c "
  SELECT table_name, txn_id, ts, lock_strength, granted, contended
  FROM crdb_internal.cluster_locks WHERE table_name = '"'"'sessions'"'"' LIMIT 20;"'
  ```

  原因のsessionを止める。まず各PCで`agentsview pg push`／`pg watch`／daemonが残っていないかを確認し、残っていなければCockroachDB側でcancelする。

  ```sh
  fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -c "CANCEL SESSION '"'"'<session_id>'"'"';"'
  ```

  cancel後にもう一度`EXPLAIN ANALYZE`を実行し、`contention`が消えていることを確認する。

  **contentionがほぼ0で、scanに時間がかかっている場合（本当に遅いquery）。** そのときだけindexを検討する。sidebarのORDER BYとdate filterは`COALESCE(ended_at, started_at, created_at)`という式を使うが、AgentsViewが作る`sessions`のindexにこの式を支えるものは無い（`parent_session_id`、`termination_status`、`cwd`、`(project, git_branch)`、`secret_leak_count`だけ）。AgentsViewは自分のindexを`CREATE INDEX IF NOT EXISTS`で作るだけなので、追加したindexが消されることはない。

  ```sh
  fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_OWNER_PG_URL" -X -v ON_ERROR_STOP=1 -c "
  CREATE INDEX IF NOT EXISTS idx_sessions_activity
    ON agentsview.sessions ((COALESCE(ended_at, started_at, created_at)) DESC, id DESC);"'
  ```

  なお`limit`を下げても解決しない。`limit=500`はfrontendの`SESSION_PAGE_SIZE`定数（`frontend/src/lib/stores/sessions.svelte.ts`）でimageにcompile済みで設定から変えられず、かつ`GetSidebarSessionIndex`は`limit > 0`だと`WITH RECURSIVE`のpaging経路に入り、その中の`COUNT(*)`はlimitと無関係に全体を走査する（`internal/postgres/sessions.go`）。

  どちらでもない場合はCockroachDB Cloud Consoleの**Metrics > Request Units**を見る。Basic planはburst RUを使い切ると強くthrottleされる。

- **画面に`request timed out`が出る／logに`status 503`と`latency 30.0秒`が並ぶ** — Cloud Runではなく**AgentsView自身のwrite timeout**である。既定は30秒で、超えると`http.TimeoutHandler`が503と`{"error":"request timed out"}`を返す（`internal/server/middleware.go`）。dashboardはanalytics APIを同時に複数叩くため、`maxScale: 1`／1 CPUの上でCockroachDBへの集計が重なると30秒に収まらない。`cloudrun-service.yaml`で`--write-timeout`を延ばし、Cloud Run側の`timeoutSeconds`をそれより長くする（先に切れるとCloud Runが504を返し、appのJSONが届かない）。延ばしても解消しない場合はCPUを2にするか、期間を短くして切り分ける。

- **`locking config: open /data/config.toml.lock: read-only file system`** — `AGENTSVIEW_DATA_DIR`（image既定は`/data`）へSecret Managerのvolumeを直接mountすると起きる。AgentsViewはconfigを読む前に必ず同じdirectoryへlock fileを作るため、data dirがread-onlyだと config.toml の内容以前に落ちる。secretは`/etc/agentsview`へmountし、起動時に`$AGENTSVIEW_DATA_DIR`へcopyする（`cloudrun-service.yaml`の`command`）。data dirにsecret volumeを重ねてはならない。
- **`install: skipping file ... as it was replaced while being copied`** — `cp`／`install`はコピー前後でsourceのmetadataを比較し、動いていれば中断する。Secret ManagerのvolumeはFUSEベースでmetadataが安定しないため誤検知する。この検査を持たない`cat`でdata dirへ書き出す（`cloudrun-service.yaml`の`command`）。
- **`schema incompatible` / `sessions table missing required columns`** — CockroachDB側に`agentsview` schemaのtableがまだない。作業9の最初の`push`が未実行のまま作業8をdeployするとこうなる。`pg serve`はread-only roleで接続するためschema migrationを自分では実行できず、compatibility checkに落ちてexitする。先に作業9の`agentsview:cockroach:push`を済ませてから再deployする。
- **`28P01` / `password authentication failed`** — `agentsview-pg-url` secretのpasswordが誤っている。CockroachDB Cloud consoleでread-only roleのpasswordを再発行し、`agentsview:cloudrun:secrets`で新versionを登録してから再deployする。
- **TLS / certificate error** — imageは`ca-certificates`入りのdebian-slimなので、通常はCockroachDB Cloudのcertを検証できる。出る場合はDB URLのhostとsslmodeを確認する。

bind addressは原因ではない。upstream imageの`CMD`は`--host 0.0.0.0 --no-browser`であり、entrypointは`agentsview pg serve "$@"`としてこれを渡す。`cloudrun-service.yaml`の`args`はこのCMDを明示的に固定しているだけで、listen先を変えるものではない。同じimageはFlyでも同じ引数で動いていた。

修正後は成功済みbuildと同じimageを明示して再deployする。

```sh
git -C ~/dotfiles pull
chezmoi apply ~/.config/agentsview
export AGENTSVIEW_IMAGE='us-west2-docker.pkg.dev/agentsview/agentsview/agentsview:0.38.1-bac4d72dc567'
AGENTSVIEW_SKIP_BUILD=1 mise run agentsview:cloudrun:deploy
```

repository root以外から実行すると、taskはsource treeではなくapply済みの`~/.config/agentsview`のmanifestを使う。`chezmoi apply`を忘れると古いmanifestがdeployされるため、`build`／`deploy`／`verify`／`render`／`diff`はchezmoi sourceとの差分があると停止する。`clrnd`のdiffに期待した変更が出ていない場合は、まずapply漏れを疑う。

`AGENTSVIEW_SKIP_BUILD=1`だけを指定してimageを省略してはいけない。taskは現在のdotfiles commitから新しいtagを組み立てるため、そのtagのimageがまだbuildされていないとverifyで停止する。

**完了確認:** revisionがReadyになり、`mise run agentsview:cloudrun:status`が最新revisionに100% trafficを示す。

##### 作業7. Secret Managerへ最初のsecret versionを登録する

config.tomlの`public_url`にはCloud Runの**deterministic URL**（`https://<service>-<project number>.<region>.run.app`）を書く。この形のURLはservice名・project number・regionだけで決まるため、serviceを作る前から確定している。placeholderを入れて後から差し替える必要はない。

```sh
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
mise run agentsview:cloudrun:url    # 書き込まれるpublic_urlを先に確認する
fnox exec -- mise run agentsview:cloudrun:secrets
```

Google Cloud Consoleの**Security > Secret Manager**で両secretを開き、Enabledなversionが1つあることを確認する。値そのものを表示する必要はない。deploy時にscriptが最新のENABLED versionを引いてnumeric versionとしてrevisionへ焼き込むため、version番号を手で控える必要はない。

**完了確認:** 両secretにEnabledなversionが1つある。

```sh
for secret in agentsview-pg-url agentsview-config-toml; do
  gcloud secrets versions list "$secret" --project="$GCP_PROJECT_ID" \
    --filter='state=ENABLED' --format='value(name)' | head -1
done
```

##### 作業8. clrndでCloud Run serviceを作り、Terraformでinvoker IAMを付ける

> **前提:**
>
> - `pg serve`は起動時にschema互換checkを行い、`sessions` tableが無いとlistenする前にexitする。read roleではmigrationを実行できないため、作業5の権限設定と`agentsview pg status`でtableが作られていることを先に確認する。まだ無い場合は作業9の`agentsview:cockroach:push`を先に済ませる。
> - **Cloud Run imageのAgentsView versionは、CockroachDBへpushする側のversionと揃える。** viewerは自分より新しいdata versionのarchiveを開けず、read roleではmigrationもできないため起動に失敗する。push側を上げたら`dot_config/agentsview/Dockerfile`の`FROM`も上げて再buildする。現在のDB側のdata versionは次で確認できる。
>
> ```sh
> agentsview --version   # push側のbinary
> ```

Cloud Run ServiceはTerraformではなくclrndが作る。まずmanifestとその参照先を検証する。`verify`はschemaをlocalで検証したうえで、runtime service account、secretとそのversion、Artifact Registry imageの実在をAPIで確認する。

```sh
mise run agentsview:cloudrun:verify
mise run agentsview:cloudrun:diff     # 初回はすべてが追加として表示される
mise run agentsview:cloudrun:deploy
```

image URIは作業6と同じ規則でcommitから組み立てられるため、`AGENTSVIEW_IMAGE`を手で設定する必要はない。digestなど別のURIをdeployする場合だけ明示する。

`deploy`はdiffを表示して確認を求め、適用後はrevisionがReadyになるまで待つ。rollout失敗時はnon-zeroで終了するため、失敗に気づかず次へ進むことはない。

clrndが作るserviceは**private**である。公開はTerraformのinvoker bindingで行う。serviceが存在した状態で通常applyを実行する。

```sh
fnox exec -- terraform -chdir=terraform/agentsview plan -input=false -out=tfplan
fnox exec -- terraform -chdir=terraform/agentsview show tfplan
fnox exec -- terraform -chdir=terraform/agentsview apply tfplan
```

作業7でconfig.tomlに書いたdeterministic URLが、いま作ったserviceのURLと一致していることを確認する。`--check`はliveなserviceが報告するURLと突き合わせ、食い違う場合だけstderrへ警告する。**この確認は初回だけでよい。** URLはserviceに紐づく値で、`clrnd deploy`が作るのはその下のrevisionなので、deployを繰り返してもURLは変わらない。変わるのはservice名・region・projectを変えたときだけである。

```sh
export AGENTSVIEW_CLOUD_RUN_URL=$(mise run --quiet agentsview:cloudrun:url -- --check)
```

Google Cloud Consoleの**Cloud Run > ryo-agentsview**で、region、1 CPU、512 MiB、min 0、max 1、runtime service account、Secret Manager参照を確認する。**Revisions**で最新revisionが100% trafficになっていることも確認する。同じ内容は`mise run agentsview:cloudrun:status`でも確認できる。

**完了確認:** 次がHTTPS URLを返し、未認証APIが401を返す。

```sh
mise run agentsview:cloudrun:status
curl -i "${AGENTSVIEW_CLOUD_RUN_URL}/api/v1/sessions"
```

##### 作業9. 小規模projectでpushとCloud Run検証を行う

各PCのlocal SQLite archiveがsource of truthなので、CockroachDBへは`agentsview pg push`で入れ直す。

まず対象projectを決める。`AGENTSVIEW_MIGRATION_PROJECTS`にはGoogle Cloud等のproject名ではなく、`agentsview projects --format json`に表示される既存のAgentsView projectから、session数の少ないものを1つ指定する。

```sh
agentsview projects --format json | jq -r '.[].name'
```

全PCの`agentsview pg push`、`pg watch`、cron／launchd／systemd timerを一時停止する。Atuinは別systemなので停止しない。停止確認後だけ次を実行する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<agentsview projectsで確認した実在名>'
fnox exec -- mise run agentsview:cockroach:push -- --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
fnox exec -- mise run agentsview:cockroach:status
```

最初の`push`がCockroachDBの`agentsview` schemaにtableを作る。push userには`CREATE`があるため、この経路でだけschemaが作られる。read roleで動くCloud Run viewerは自分でschemaを作れないので、**viewerより先にpushを済ませる**。

`push`が`Pushing to PostgreSQL via the local daemon...`と表示するのは正常である。local daemonがSQLite archiveを保持しているため、CLIはpushをdaemonへ委譲する。接続先URLはCLI側で解決してdaemonへ渡すので、CockroachDBへ書かれる。daemonを介さず直接書きたい場合だけ`agentsview daemon stop`のうえ`AGENTSVIEW_NO_DAEMON=1`を使う。

認証と画面を確認する。

```sh
curl -i "${AGENTSVIEW_CLOUD_RUN_URL}/api/v1/sessions" # 401を期待
fnox exec -- sh -c 'curl -fsS \
  -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$AGENTSVIEW_CLOUD_RUN_URL"'/api/v1/sessions" >/dev/null'
```

UIではCloud Runの**Logs**または**Logging > Logs Explorer**を開き、resource typeをCloud Run Revision、service nameを`ryo-agentsview`に絞る。startup error、CockroachDB接続error、secret値、`token=`付きURLが記録されていないことを確認する。CockroachDB Consoleのcluster Metrics／Usageでstorage、RU、connection数を記録する。

**完了確認:** `agentsview:cockroach:status`が対象projectのsessionを報告し、認証済みAPI、session一覧、detail、analytics、usageが表示され、Cloud RunとCockroachDBにerrorがない。

##### 作業10. 全projectへ広げて運用を始める

1. 全PCのpush／watch／timerを停止し、停止した端末一覧とUTC時刻を記録する。
2. 各PCで残りの全projectを`agentsview:cockroach:push`する（`--projects`を付けなければ全project）。
3. `agentsview:cockroach:status`とCloud Run viewerで、想定するsessionが揃っていることを確認する。
4. 各PCの通常taskを`agentsview:cockroach:push`へ切り替え、小さいprojectから再開する。
5. Cloud Runを再度smoke testする。
6. 数日はCloud Run error、CockroachDBのRU／storage、backupを毎日確認する。

```sh
fnox exec -- mise run agentsview:cockroach:push
fnox exec -- mise run agentsview:cockroach:status
fnox exec -- mise run agentsview:pg:remote-local:dump
```

**完了確認:** 全PCがCockroachDBへpushし、Cloud Run viewerとbackup／restoreが成功する。

### AgentsView appの実行基盤はどれを選ぶか

調査日: **2026-09-02**

#### 結論

この用途では、**Cloud Runを継続するのが第一候補**。Fly.ioよりログの検索・絞り込み・保持が扱いやすく、現在の実装をそのまま利用できる。個人用AgentsViewは常時接続を必要とせず、閲覧時だけ起動できるため、Cloud Runのscale-to-zeroと相性がよい。

「管理画面の分かりやすさ」を最優先してGoogle Cloud自体を避けたいなら、**Northflank Developer Sandboxを第二候補としてPoC**する。ただしDeveloper Sandboxは本番SLAを期待する基盤ではなく、無料枠やresource planの変更リスクがCloud Runより高い。単純なスペック表だけでNorthflankへ即移行せず、cold start、ログ保持期間、CockroachDBへのlatencyを実測してから決める。

#### 比較表

無料枠は予告なく変わる。契約・移行直前に各公式Pricingを再確認する。ここでいう「スペック」は無料quotaまたは選択可能resourceの上限であり、専有CPU性能を保証しない。

|  順位 | 基盤                                                                                            | 無料computeの目安                                                                  | ログの使いやすさ                                                                            | AgentsViewとの相性                                                          | 判定                    |
| ----: | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ----------------------- |
| **1** | [Google Cloud Run](https://cloud.google.com/run/pricing)                                        | 月180,000 vCPU秒、360,000 GiB秒、200万request。現在は1 vCPU／512 MiB、min 0、max 1 | Cloud Run画面、Logs Explorer、CLI tail／read。構造化JSON、severity、request traceで検索可能 | 既存image／Secret Manager／deploy taskを実装済み。scale-to-zero可能         | **採用**                |
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
5. **既存実装を再利用できる**: build、Secret Manager mount、read-only CockroachDB URL、min 0／max 1、deploy taskが既にこのrepositoryにある。別PaaSへ移るとsecret、domain、health check、logging、rollbackをもう一度検証する必要がある。

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

### 0. 変更前の安全確認

1. 各PCのlocal SQLite archiveがsource of truthである。CockroachDBはそこからの派生なので、まずlocal archiveが健全であることを確認する。

```sh
agentsview projects --format json | jq -r '.[] | "\(.name)\t\(.session_count // "?")"'
```

2. 既にCockroachDBを使っている場合は、現在の件数を控えておく。作業後の比較対象になる。

```sh
fnox exec -- mise run agentsview:cockroach:status
```

3. local PostgreSQLへ統合backupを作れる状態にしておく。CockroachDBとlocal archiveの両方をまとめたdumpが手元に残る。

```sh
fnox exec -- mise run agentsview:pg:remote-local:dump
```

4. backupを空の検証PostgreSQLへrestoreできることを確認する。backup fileを作っただけでは合格にしない。

### 1. CockroachDBの権限設計を決める

Basic cluster、database、owner／push／read userは次節のTerraformで作成する。Terraformは10 GiB storage／5,000万RUのusage limitも設定し、意図しない有料利用を防ぐ。passwordはuserごとに異なるrandom valueを用意する。

CockroachDB Terraform providerはdatabase内のschema／table権限を管理しないため、AgentsViewのschema bootstrap後に次だけSQL consoleまたはowner接続で実行する。CockroachDB versionによって`ALL TABLES IN SCHEMA`／default privilegeの対応が異なる場合は、Consoleが示す現行syntaxに合わせる。

```sql
REVOKE admin FROM agentsview_push, agentsview_read;
GRANT USAGE ON SCHEMA agentsview TO agentsview_read;
GRANT CREATE, USAGE ON SCHEMA agentsview TO agentsview_push;
GRANT SELECT ON ALL TABLES IN SCHEMA agentsview TO agentsview_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA agentsview TO agentsview_push;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA agentsview TO agentsview_push;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT ON TABLES TO agentsview_read;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO agentsview_push;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_owner IN SCHEMA agentsview
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO agentsview_push;
ALTER DEFAULT PRIVILEGES FOR ROLE agentsview_push IN SCHEMA agentsview
  GRANT SELECT ON TABLES TO agentsview_read;
```

CockroachDB CloudがConsole／APIで作成するSQL userは初期状態で`admin` roleを持つため、上記の`REVOKE`は省略しない。`GRANT`は権限を追加するだけで、`admin`から継承した全権限を縮小しない。実際の適用とread-only検証の手順は作業5に記載している。

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

#### 2.0 Terraform resourceの意味

現在のTerraformは「永続的な基盤」と「Cloud Runへのapp deploy」の両方を管理している。各resourceの役割は次のとおり。

| Terraform resource                                      | コード上の主要設定                              | 作成されるもの／必要な理由                                                                                                                                                                                             |
| ------------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `google_project_service.required`                       | `gcp_apis.tf`のAPI名setを`for_each`             | Cloud Run、Artifact Registry、Cloud Build、Secret Manager、IAM、STS等のGoogle Cloud APIをprojectで有効化する。APIを使う前提条件であり、app revisionではない                                                            |
| `data.google_project.current`                           | `gcp_project_id`からprojectを参照               | project numberを取得し、Cloud Buildで使われ得るGoogle管理service account名を組み立てる。resourceは新規作成しない                                                                                                       |
| `google_artifact_registry_repository.agentsview`        | `us-west2`、Docker format                       | AgentsView container imageを保存するrepository。ECR repositoryに相当する。cleanup policyのKEEPはDELETEより優先されるため、残るのは「直近10 version **または** 30日以内」のいずれかに当てはまるもの（無料枠0.5 GB対策） |
| `google_artifact_registry_repository_iam_member.*`      | runtime=`reader`、Cloud Build／deploy=`writer`  | runtimeはimage pullだけ、build／deploy主体はpushできるよう最小権限を分離する                                                                                                                                           |
| `google_service_account.runtime`                        | `agentsview-runtime`                            | Cloud Run containerが実行時に使うidentity。Secret Managerを読むがdeployはしない。ECS task roleに近い                                                                                                                   |
| `google_secret_manager_secret.pg_url`                   | secret containerのみ                            | CockroachDB read-only URLの入れ物。値／versionはTerraformへ入れず別taskで追加する                                                                                                                                      |
| `google_secret_manager_secret.config`                   | secret containerのみ                            | `/etc/agentsview/config.toml`としてmountするAgentsView configの入れ物                                                                                                                                                  |
| `google_secret_manager_secret_iam_member.runtime_*`     | `secretAccessor`                                | runtimeだけがDB URL／configを読めるようにする                                                                                                                                                                          |
| `cockroach_cluster.agentsview`                          | GCP、Basic、`us-west2`、10 GiB／5,000万RU limit | AgentsView用CockroachDB cluster本体。persistent dataを持つためdelete protectionを有効にする                                                                                                                            |
| `cockroach_database.agentsview`                         | database名`agentsview`                          | app schemaを格納するlogical database                                                                                                                                                                                   |
| `cockroach_sql_user.owner`                              | owner password                                  | schema bootstrap／migration専用user                                                                                                                                                                                    |
| `cockroach_sql_user.push`                               | push password                                   | 各PCからsessionを送るuser。app viewerとは分離する                                                                                                                                                                      |
| `cockroach_sql_user.read`                               | read password                                   | Cloud Run viewer用user。後続SQLでSELECTだけを付与する                                                                                                                                                                  |
| `google_cloud_run_v2_service_iam_member.public`         | `allUsers` + `roles/run.invoker`                | Cloud Run URLへの未認証到達を許可する。AgentsView自身のbearer認証は別途維持する。clrndはIAMを扱わないため、この1件だけCloud Run側に残す                                                                                |
| `google_service_account.deploy`                         | `agentsview-deploy`                             | GitHub ActionsがCloud Runへdeployするときのidentity。key JSONは作らず、OIDC tokenの交換でしか名乗れない                                                                                                                |
| `google_iam_workload_identity_pool.github`              | pool `github-actions`                           | GitHubのOIDC tokenを受け入れる入口                                                                                                                                                                                     |
| `google_iam_workload_identity_pool_provider.github`     | issuer、attribute mapping／condition            | `assertion.repository`と`assertion.ref`で、指定repositoryの指定branchのworkflowだけにtoken交換を許す                                                                                                                   |
| `google_service_account_iam_member.deploy_*`            | `workloadIdentityUser`、`serviceAccountUser`    | 前者がGitHub側principalSetへdeploy SAの借用を許し、後者がCloud Runの要求するruntime SAへの`actAs`を与える                                                                                                              |
| `google_project_iam_member.deploy_*`                    | `run.developer`、`cloudbuild.builds.editor`     | clrndがserviceを更新し、`gcloud builds submit`がimageをbuildするための最小権限。IAM policyは触れない                                                                                                                   |
| `google_storage_bucket_iam_member.deploy_build_staging` | `<project>_cloudbuild`に`storage.admin`         | `gcloud builds submit`がbuild contextを置くbucketだけに限定する。projectレベルのstorage権限を与えるとTerraform state bucketまで読めてしまう                                                                            |
| `google_secret_manager_secret_iam_member.deploy_*`      | `secretmanager.viewer`（2 secret）              | revisionへ焼き込むversion番号を引くためのmetadata権限。値そのものは読めない                                                                                                                                            |

**deploy service accountとWorkload Identity連携はGitHub Actions専用である。** operatorが手元から`build`／`deploy`／secret登録を実行するときは、従来どおり自分の認証情報（`gcloud auth login`）を使う。CIのidentityへは値を読める権限（`secretAccessor`）も、versionを追加する権限（`secretVersionAdder`）も与えていない。secretの登録は手元の`agentsview:cloudrun:secrets`だけが行う。

**Cloud Run Service本体(`google_cloud_run_v2_service.agentsview`)はこの表にない。** 2.0.2のとおりclrndが所有するため、Terraformコードから削除した。表に残る`google_cloud_run_v2_service_iam_member.public`だけはCloud Run resourceを参照せず、service名と`local.region`を直接指定するので、Terraform stateはCloud Run Serviceに依存しない。

`variables.tf`はproject IDとCockroachDB passwordというoperator入力だけを宣言する。Cloud Run service名はmanifest・`clrnd.yml`・Terraformの3箇所で一致している必要があるため、入力変数ではなく`local.cloud_run_service_name`に固定している（regionと同じ扱い）。image URIとSecret Managerのversionはclrnd manifest側へ移したため、`agentsview_image`／`pg_url_secret_version`／`config_secret_version`は廃止した。`sensitive = true`はCLI表示を伏せる指定であり、CockroachDB SQL user passwordをstateから除外する指定ではない。`locals.tf`は変数にしない値を一箇所に固定する。全regional resourceで共有する`us-west2`、service名、project numberから組み立てるdeterministic URL（`local.cloud_run_url`）、そしてWorkload Identity Federationのattribute conditionが見る`github_repository`／`github_deploy_ref`である。後者を入力変数にすると、別のrepositoryやbranchのworkflowがdeploy service accountを名乗れる設定を外から渡せてしまう。`outputs.tf`は後続commandが必要とするhost、service account名、Cloud Run service名／region／URL、GitHub Actions secretへ入れる2つの値を公開する。稼働中のrevisionやtraffic splitはTerraformではなく`clrnd status`から取る。

#### 2.0.1 ECS + ecspressoに相当するCloud Runの分離

Cloud Runにはoperatorが作成・維持するECS cluster相当resourceがない。Google管理のregional control plane上に**Service**を作成し、templateを更新するたびにimmutableな**Revision**が作られる。

| AWS                        | Cloud Runで近いもの                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------- |
| ECS cluster                | 直接の相当物なし。project、region、API有効化が実行基盤の境界                           |
| ECR repository             | Artifact Registry repository                                                           |
| task role／execution role  | Cloud Run runtime service accountとdeploy service account                              |
| task definition            | Cloud Run Service内のrevision template                                                 |
| ECS Service                | Cloud Run Service                                                                      |
| ALB／target group          | Cloud Run管理のHTTPS endpointとtraffic split                                           |
| ecspresso deploy／rollback | `clrnd deploy`／`clrnd rollback`、または`gcloud run services replace`／traffic command |

したがって採用した分離は、**TerraformがAPI、Artifact Registry、runtime service account、Secret Manager、CockroachDBを管理し、clrndがCloud Run Service／Revision／trafficを管理する**形である。Cloud Run Serviceを空の「cluster」としてTerraformで先に作り、後から別toolが同じService templateを管理する構成にはしない。同じresourceをTerraformとclrndの両方が所有すると、次回`terraform apply`がclrndのdeployを差し戻し、今回のようなtaint／replacement競合を起こす。

#### 2.0.2 `clrnd`によるdeploy分離（採用済み）

[`masasuzu/clrnd`](https://github.com/masasuzu/clrnd)をv0.5.0でpinして採用し、Cloud Run Serviceのownershipをclrndへ移した。TerraformコードからCloud Run Service resourceを削除済みで、**同じresourceを2つのtoolが所有する状態は作らない**。

| 所有者    | 対象                                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Terraform | Google Cloud API有効化、Artifact Registry、runtime service account、Secret Manager container／IAM、CockroachDB、Cloud Run invoker IAM |
| clrnd     | Cloud Run Service定義（image、CPU／memory、concurrency、timeout、scaling、環境変数、Secret Manager参照）、Revision、traffic、rollback |

ecspressoとの対応は`verify`／`diff`／`deploy`／`rollback`がほぼそのまま対応する。deploy後はrevisionがReadyになるまで待ち、rollout失敗時はnon-zeroで終了するのでCIでも使える。

mise taskは次を追加した。いずれもrepository rootでも、chezmoi適用後の`~/.config/agentsview`だけがある環境でも動作する。

| task                            | 内容                                                                             |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `agentsview:cloudrun:build`     | commitでtagを固定してArtifact Registryへimageをbuild                             |
| `agentsview:cloudrun:verify`    | manifestのschema検証と、service account／secret version／imageの実在確認         |
| `agentsview:cloudrun:render`    | templateを展開したmanifestを表示（APIへ接続しない）                              |
| `agentsview:cloudrun:diff`      | live serviceとmanifestの差分                                                     |
| `agentsview:cloudrun:deploy`    | build → verify → deploy → rollout待ち                                            |
| `agentsview:cloudrun:status`    | Ready状態、traffic split、URL                                                    |
| `agentsview:cloudrun:revisions` | revision一覧とtraffic share                                                      |
| `agentsview:cloudrun:refresh`   | 定義を変えずに新revisionを作る（containerの再起動）                              |
| `agentsview:cloudrun:rollback`  | 直前のrevisionへtrafficを戻す                                                    |
| `agentsview:cloudrun:url`       | deterministic URLを表示（serviceが無くても動く。`-- --check`でliveと突き合わせ） |

共通処理（project／region／service名の解決、deterministic URLの組み立て、image URIの組み立て、secret versionのpin、Cloud Build、clrnd実行）は`dot_config/agentsview/scripts/cloudrun.sh`が持つ。各mise taskはscriptのpathを解決して第1引数にmodeを渡すだけの薄いwrapperで、設定の解決は1箇所にしかない。GitHub Actionsも同じscriptを直接呼ぶので、CIと手元でdeploy経路が分岐しない。

各taskは`shell = "bash -c"`を指定しているため、`mise run <task> -- <args>`の`<args>`はscriptの`"$@"`へそのまま届く。wrapperはそれを`exec bash "$script" <mode> "$@"`で下へ渡す。

```sh
mise run agentsview:cloudrun:rollback -- --revision ryo-agentsview-00006-def
mise run agentsview:cloudrun:url -- --check
```

captureする場合は`mise run --quiet`を使う。miseがtask名などの付随出力を混ぜないようにするためである。

採用にあたって前提にした制約は次のとおり。

- **IAMはclrnd管理外。** `allUsers`のinvoker bindingはTerraformに残す。clrndが作るserviceは常にprivateなので、初回は「clrnd deployでserviceを作る → Terraform applyでinvoker bindingを付ける」の順序になる。
- **manifestはGo templateであり、実行可能な入力として扱う。** 任意の環境変数を読めるため、fork PRのmanifestをproduction credentialでrender／deployしない。今回のmanifestは`must_env`で`GCP_RUNTIME_SERVICE_ACCOUNT`と`AGENTSVIEW_IMAGE`だけを読み、secret値は展開せずSecret Manager参照だけを書く。
- **`diff`はserver defaultの解決にdry-run updateを使うため、read-only権限では動かない。** read-only credentialで確認する場合だけ`--no-server-defaults`を付ける。
- **secret versionはnumericへpinする。** Cloud Runはsecret参照をinstance起動時に解決するため、`latest`のままだと同じrevisionのinstance同士が別の値を読み、rollbackしても当時の値を再現できない。mise taskはmanifestをrenderするmode（`verify`／`render`／`diff`／`deploy`）でだけ最新のENABLED versionをSecret Managerから引き、その番号をrevisionへ焼き込む。古いversionを意図的に使う場合は`AGENTSVIEW_PG_URL_SECRET_VERSION`／`AGENTSVIEW_CONFIG_SECRET_VERSION`を明示する。**新しいsecret versionを反映するのは`deploy`であり、`refresh`ではない**（`refresh`はliveの定義をそのまま再適用するため、pinされた古い番号を持ち回る）。
- **image tagはcommitで固定する。** `gcloud builds submit --tag`は同じtagを上書きするため、`agentsview:0.38.1`のような可変tagのままだと、同じURIが時期によって別のartifactを指し、CIが検証したimageと手元deployのimageがずれ得る。taskは`<upstream version>-<commit>`をtagにし、CIでは`GITHUB_SHA`を使う。digestを直接指定する場合は`AGENTSVIEW_IMAGE`で上書きする。
- **v0系のthird-party tool。** version pinを必ず維持し、bumpするときは`verify`→`diff`→`deploy`→`rollback`をrehearsalしてから上げる。

#### 2.0.3 clrnd manifestの各設定

`dot_config/agentsview/cloudrun-service.yaml`の設定は、以前Terraformの`google_cloud_run_v2_service`が持っていた値と1対1で対応する。

| manifestの位置                                                          | 値                                                                         | 意味／旧Terraform属性                                                                            |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `metadata.name`                                                         | `ryo-agentsview`                                                           | service名。`clrnd.yml`の`service`とTerraformの`local.cloud_run_service_name`に一致させる         |
| `metadata.annotations."run.googleapis.com/ingress"`                     | `all`                                                                      | 旧`ingress = "INGRESS_TRAFFIC_ALL"`                                                              |
| `spec.template.metadata.annotations."autoscaling.knative.dev/minScale"` | `0`                                                                        | 旧`scaling.min_instance_count`。idle時は0まで縮む                                                |
| 同`maxScale`                                                            | `1`                                                                        | 旧`scaling.max_instance_count`。無料枠を超える暴走を防ぐ                                         |
| 同`run.googleapis.com/cpu-throttling`                                   | `true`                                                                     | 旧`resources.cpu_idle = true`                                                                    |
| 同`run.googleapis.com/startup-cpu-boost`                                | `true`                                                                     | 旧`resources.startup_cpu_boost = true`                                                           |
| `spec.template.spec.serviceAccountName`                                 | `{{ must_env "GCP_RUNTIME_SERVICE_ACCOUNT" }}`                             | Terraform outputのruntime service account。deploy権限は持たない                                  |
| `spec.template.spec.containerConcurrency`                               | `20`                                                                       | 旧`max_instance_request_concurrency`                                                             |
| `spec.template.spec.timeoutSeconds`                                     | `60`                                                                       | 旧`timeout = "60s"`                                                                              |
| `containers[].image`                                                    | `{{ must_env "AGENTSVIEW_IMAGE" }}`                                        | 旧`var.agentsview_image`。既定値は`<upstream version>-<commit>`（例`0.38.1-e310d8af1f32`）       |
| `containers[].ports`                                                    | `http1` / `8080`                                                           | 旧`ports.container_port`                                                                         |
| `containers[].resources.limits`                                         | `cpu: "1"` / `memory: 512Mi`                                               | 旧`resources.limits`                                                                             |
| `containers[].env`                                                      | `PG_SERVE`／`AGENTSVIEW_DISABLE_UPDATE_CHECK`／`AGENTSVIEW_PG_SCHEMA`      | 旧`env`ブロックと同じ非secret値                                                                  |
| `containers[].env[].valueFrom.secretKeyRef`                             | `agentsview-pg-url` / `{{ must_env "AGENTSVIEW_PG_URL_SECRET_VERSION" }}`  | 旧`value_source.secret_key_ref` + `var.pg_url_secret_version`。read-only CockroachDB URL         |
| `volumes[].secret`                                                      | `agentsview-config-toml`（version pin付き）→ `/etc/agentsview/config.toml` | 旧`volumes.secret` + `volume_mounts` + `var.config_secret_version`                               |
| `spec.traffic`                                                          | `latestRevision: true` / 100%                                              | 最新revisionへ100%。`clrnd rollback`はここをrevision名へpinし、`clrnd traffic --to-latest`で戻す |

manifestはGo templateとして必ずrenderされるため、上記2箇所以外に`{`を2つ並べた表記を書かない。書く必要がある場合はclrnd READMEのescape記法を使う。

#### 2.0.4 既存Terraform stateからownershipを移す

すでに`terraform apply`でCloud Run Serviceを作った環境（今回のbootstrap中の状態を含む）では、コードから削除するだけでは不十分である。stateにresourceが残っているため、次のplanがserviceを**destroy**しようとする。さらに旧stateの`deletion_protection = true`が残っている場合は`cannot destroy service without setting deletion_protection=false`で停止する。

apply前に、stateからownershipだけを外す。実serviceは削除されない。

```sh
# 1. stateに残っているか確認する
fnox exec -- terraform -chdir=terraform/agentsview state list | rg google_cloud_run_v2_service

# 2. taintが残っている場合は先に解除する（destroy計画のまま次へ進まない）
fnox exec -- terraform -chdir=terraform/agentsview untaint google_cloud_run_v2_service.agentsview || true

# 3. serviceとinvoker bindingをstateから外す（Google Cloud上のresourceは残る）
fnox exec -- terraform -chdir=terraform/agentsview state rm google_cloud_run_v2_service.agentsview
fnox exec -- terraform -chdir=terraform/agentsview state rm google_cloud_run_v2_service_iam_member.public || true

# 4. 実serviceが残っていることを確認する
gcloud run services describe ryo-agentsview \
  --project="$GCP_PROJECT_ID" --region=us-west2 --format='value(status.url)'
```

invoker bindingも一度外すのは、resource addressは同じでも参照元がCloud Run resourceからservice名へ変わり、再importした方が単純なためである。planに`google_cloud_run_v2_service_iam_member.public`が`+ create`と出ている場合はstateに無いので、手順3の2つ目は`does not exist`で終わる（`|| true`で流す）。手順3のあと、planに`google_cloud_run_v2_service_iam_member.public`の作成だけが出ることを確認してapplyする（既存bindingは同じ内容で再作成されるため、公開状態は途切れない）。

移行後の確認:

```sh
# Terraform側に残るCloud Run関連はinvoker bindingだけ
fnox exec -- terraform -chdir=terraform/agentsview plan -input=false | rg google_cloud_run

# clrnd側が差分を持たない
mise run agentsview:cloudrun:diff
```

`clrnd diff`が空になれば、live serviceとmanifestが一致している。差分が出る場合は、manifestを実状に合わせるか（`clrnd init`で現行定義を書き出して比較する）、意図した変更としてdeployする。

CockroachDB provider v1.22の`cockroach_sql_user`は`sensitive`な`password`を受け取るが、Terraformのwrite-only `password_wo`／`password_wo_version`には対応していない。そのため3つのSQL user passwordはplan出力では伏せられる一方、Terraform stateには保存される。GCS state bucketへのIAMをoperatorだけに制限し、stateをdownload／commitせず、Object VersioningとPublic Access Preventionを維持する。Cockroach Cloud API keyはproviderが`COCKROACH_API_KEY`から読み、tfvarsへ書かない。

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

stateにはCockroachDB SQL user password、resource ID、構成情報が入る。public access prevention、versioning、最小権限IAMを設定し、state fileをdownload／commitしない。

#### 2.2 Terraformを初期化

```sh
cd terraform/agentsview
cp terraform.tfvars.example terraform.tfvars
# project、region、最初にbuildするimage URIを編集する。

fnox exec -- terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config='prefix=agentsview'
fnox exec -- terraform fmt -check -recursive
fnox exec -- terraform validate
```

CockroachDB Cloudでorganization scopeの`Cluster Creator`を持つTerraform用service accountから`CCDB1_...` API Secret keyを発行し、SQL user用に別々のrandom passwordを用意する。shell historyへ直接値を書かず、fnox等からexportする。

```sh
chezmoi apply ~/.config/fnox/config.toml
fnox get COCKROACH_API_KEY >/dev/null
fnox exec -- terraform version
```

#### 2.3 bootstrap apply

Cloud Run Serviceはclrndが作るため、Terraformの`google_cloud_run_v2_service_iam_member.public`はserviceが存在するまでapplyできない。初回はそれ以外のresourceをすべてtarget applyする。

target一覧は作業4に置いてある。2箇所で別々に管理すると片方に不足が出るため、ここでは繰り返さない。

続いて最初のimageをbuildする。

```sh
cd ../..
mise run agentsview:cloudrun:build
```

続いてCockroachDBのread-only URLとAgentsView configをSecret Managerへ登録する。config.tomlの`public_url`にはdeterministic URLが入るため、serviceが未作成でもここで確定する。

```sh
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
mise run agentsview:cloudrun:url
fnox exec -- mise run agentsview:cloudrun:secrets
```

次にrepository rootでclrndからCloud Run Serviceを作る。Terraformはこの時点でServiceを作らない。

```sh
mise run agentsview:cloudrun:verify
mise run agentsview:cloudrun:deploy
```

Serviceができたら`terraform/agentsview`へ戻り、残りのresource（`allUsers`のinvoker bindingを含む）をapplyする。secret versionはclrndがdeploy時に解決してrevisionへ焼き込むため、Terraform変数として渡す必要はない。

```sh
cd terraform/agentsview
fnox exec -- terraform plan -input=false -out=tfplan
fnox exec -- terraform apply tfplan
```

planで`cockroach_cluster`が`plan = "BASIC"`であること、`google_cloud_run_v2_service_iam_member.public`だけがCloud Run関連の変更であることを確認する。Cloud Runのmin 0／max 1、1 vCPU／512 MiBは`mise run agentsview:cloudrun:diff`と`clrnd status`で確認する。最後に`mise run --quiet agentsview:cloudrun:url -- --check`で、config.tomlへ書いたdeterministic URLがliveなserviceのURLと一致していることを確認する。

#### 2.4 deploy方法を確認する

初回構築とsecret version追加は手元で行い、通常のapp deployはrepository rootから次を実行する。Terraformは基盤変更のときだけ実行する。

```sh
mise run agentsview:cloudrun:diff     # 適用前に差分を読む
mise run agentsview:cloudrun:deploy   # build → verify → deploy → rollout待ち
mise run agentsview:cloudrun:status
```

rollbackとtraffic操作もclrnd側で行う。`rollback`はtemplateを変えずtrafficだけを戻すため、新revisionは作られない。

```sh
mise run agentsview:cloudrun:revisions
mise run agentsview:cloudrun:rollback              # 直前のrevisionへ戻す
mise run agentsview:cloudrun:rollback -- --revision ryo-agentsview-00006-def
```

mainへmergeしたときのdeployは`.github/workflows/deploy-agentsview.yaml`が行う。手元の操作と同じ`dot_config/agentsview/scripts/cloudrun.sh deploy`を`--auto-approve`付きで実行するだけなので、CIと手元でdeploy経路は分岐しない。image tagはGitHub Actionsが渡す`GITHUB_SHA`から組み立てられるため、workflow側でimage URIを組み立てる必要もない。設定は[GitHub ActionsからのCloud Run deploy](#github-actionsからのcloud-run-deploy)にまとめてある。

secret versionの解決だけ注意する。scriptは既定で最新のENABLED versionをSecret Managerから引くが、それには`secretmanager.versions.list`が要る。Terraformはdeploy service accountへ2つのsecretに限って`roles/secretmanager.viewer`（metadataのみ。値は読めない）を与えているので、CIでも引ける。この権限を持たないidentityで動かす場合は、secret登録stepが返したversion番号を`AGENTSVIEW_PG_URL_SECRET_VERSION`／`AGENTSVIEW_CONFIG_SECRET_VERSION`としてdeploy stepへ渡す。権限不足のまま実行した場合、scriptはgcloudのerrorに続けてこの2択を表示して停止する。

### 3. CockroachDB schemaをbootstrapしてlocalからpush

**方針: local archiveからpushして作る。** AgentsViewのlocal SQLite archiveが各PCのsource of truthであり、CockroachDBはそこからの派生である。したがって他のDBからdump／restoreするのではなく、各PCから`agentsview pg push`で入れ直す。

#### 3.1 小さいprojectでbootstrap

`AGENTSVIEW_MIGRATION_PROJECTS`には、Google Cloud等のproject名ではなく`agentsview projects --format json`に表示される既存のAgentsView projectから、最初に試すsession数の少ないものを1つ指定する。任意の`small-project`という名前を新規作成する意味ではない。候補一覧と選び方は作業5の手順を参照する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<agentsview projectsで確認した実在名>'
fnox exec -- mise run agentsview:cockroach:push -- --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
```

最初の`push`が次を行う。

1. `agentsview` schemaとtableをCockroachDBに作成する（push userの`CREATE`が必要）。
2. 指定projectのsessionをlocal archiveからCockroachDBへ書き込む。
3. data versionを記録する。以降のviewer imageはこのversion以上でなければ起動しない。

`--no-vectors`はtaskが常に付ける。CockroachDBはpgvectorを持たないため、vectorは押し込まない。

#### 3.2 pushがdaemon経由になることについて

`push`は`Pushing to PostgreSQL via the local daemon...`と表示する。これは異常ではない。local daemon（背景で動くAgentsView server）がSQLite archiveを排他的に保持しているため、CLIは自分で書かずdaemonへ`POST /api/v1/push/pg`で委譲し、進捗をstreamで受け取る。

接続先はCLI側で解決してrequest bodyでdaemonへ渡すため、`AGENTSVIEW_PG_URL`に指定したCockroachDBへ書かれる。daemonが別のDBへ書くことはない。

daemonを介さず直接書きたい場合だけ次を使う。

```sh
agentsview daemon stop
AGENTSVIEW_NO_DAEMON=1 fnox exec -- mise run agentsview:cockroach:push -- --projects '<project>'
```

#### 3.3 内容を照合

```sh
fnox exec -- mise run agentsview:cockroach:status
```

CockroachDB側の件数はowner／read接続で直接確認できる。

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

比較対象はlocal archiveである。`agentsview projects --format json`のsession数と、Cloud Run viewerに表示される件数が一致することを確認する。

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

差分pushは各PCからCockroachDBのTLS endpointへ直接送る。proxyは介さない。

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

`agentsview:cockroach:push` taskは常に`--no-vectors`を追加し、CockroachDBに送る対象をsession contentへ限定する。AgentsViewはDB vendorだけを見てvector phaseを自動停止しないため、taskを介さず直接実行するときも`--no-vectors`または`push_vectors=false`を必ず指定する。incremental watermarkは接続target／project filterごとにlocal保存される。初回CockroachDB pushは必ず小さいprojectで確認してから広げる。

#### 「pull」の代わりに何を使うか

| 目的                                      | 方法                                                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 別PCから同じsessionを閲覧する             | localへpullせず、Cloud Runのread-only viewerでCockroachDBを読む                                                           |
| 新しいPCのlocal AgentsViewへsessionを戻す | AgentsViewの`pg pull`ではできない。元のagent session directoryのbackup／同期機能で復元してから再indexする                 |
| CockroachDB障害に備える                   | `agentsview:pg:remote-local:dump`でdataをlocal PostgreSQLへmergeし、custom-format backupを作る。自動replicaとはみなさない |
| PostgreSQLへrollbackする                  | write停止後にschema／型を変換したexport/importをrehearsalする。CockroachDBのdumpをPostgreSQLへ無検証restoreしない         |
| localでSQL分析する                        | read-only SQL clientでCockroachDBへ直接接続するか、分析用exportを別DBへimportする。本番との双方向同期はしない             |

CockroachDBとPostgreSQLは同じwire protocolを話すが、DDL、sequence、権限、型、transaction semanticsは完全互換ではない。そのためCockroachDBのschema dumpをPostgreSQLへそのままrestoreする設計は採用しない。このrepositoryの`agentsview:pg:remote-local:dump`はdata-only／column INSERTとしてexportし、現在のAgentsViewがlocal PostgreSQLへ作ったschemaに不足rowだけをtransaction内でmergeする。

#### local PostgreSQLの位置づけ

local PostgreSQL（`dot_config/agentsview/compose.yaml`）はCockroachDBの自動pull先ではない。日常運用は、各PCのsession sourceからCockroachDBへ直接pushし、Cloud Runからreadする。

local PostgreSQLを使うのはbackupのときだけである。`agentsview:pg:remote-local:dump`が、このmachineのlocal push、CockroachDBからのdata export、local merge、sequence補正、custom-format dumpを順に行う。

```sh
# CockroachDB data + このmachineのsessionを統合したlocal PostgreSQL dump
fnox exec -- mise run agentsview:pg:remote-local:dump

# remoteへ接続せず、現在のlocal PostgreSQLだけをdump
mise run agentsview:pg:local:dump
```

CockroachDB側にだけ存在するrowはlocalへ追加するが、同じprimary keyがlocalにある場合は`ON CONFLICT DO NOTHING`でlocalを維持する。このdumpは完全な双方向同期やreplicaではなく、閲覧・disaster recovery用の統合snapshotである。importはtransaction内で行い、schema／型が合わなければ全体をrollbackする。

### 5. Cloud Run secretとserviceを作成

config.tomlの`public_url`はCloud Runのdeterministic URLへ固定する。serviceを作る前から確定しているので、URL待ちのplaceholderは要らない。ServiceはclrndがKnative manifestから作る。

```sh
export GCP_PROJECT_ID='<project-id>'
export GCP_REGION='us-west2'
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

mise run agentsview:cloudrun:url        # public_urlに入る値
fnox exec -- mise run agentsview:cloudrun:secrets
mise run agentsview:cloudrun:deploy
```

clrndが作るserviceはprivateなので、Terraformで`allUsers`のinvoker bindingを付ける（2回目以降は差分なし）。

```sh
fnox exec -- terraform -chdir=terraform/agentsview apply
```

serviceが出来たら、config.tomlに書いたURLがliveなserviceのURLと一致することを**一度だけ**確認する。URLはserviceに紐づく値なので、以後deployを繰り返しても変わらない。

```sh
export AGENTSVIEW_CLOUD_RUN_URL=$(mise run --quiet agentsview:cloudrun:url -- --check)
```

Cloud Runでは次のようにsecretを注入する。どちらもmanifestには参照だけを書き、値はSecret Managerに残る。

- `AGENTSVIEW_PG_URL`: `agentsview-pg-url`のnumeric versionを環境変数として参照
- `/etc/agentsview/config.toml`: `agentsview-config-toml`のnumeric versionをread-only secret volumeとしてmountし、起動時に`$AGENTSVIEW_DATA_DIR`へcopyする（data dirは書き込み可能でなければならない）

versionは`latest`ではなく番号で固定する。Cloud Runはsecret参照をinstance起動時に解決するため、`latest`では同じrevisionのinstance同士が別の値を読み、rollbackしても当時の値を再現できない。deploy scriptが最新のENABLED versionを引いてrevisionへ焼き込むので、**新versionを追加しただけでは動作中のrevisionは切り替わらない。** 反映するのは`deploy`であり、`refresh`（liveの定義をそのまま再適用する）ではない。

Terraformのinvoker bindingはCloud Run URLへの到達だけを許可する。AgentsView自身の`require_auth=true`とbearer tokenは維持する。

### 6. Cloud Runを検証

```sh
mise run agentsview:cloudrun:status

url=$(mise run --quiet agentsview:cloudrun:url -- --check)

curl -i "$url/api/v1/sessions"                    # 401を期待
fnox exec -- sh -c 'curl -fsS -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$url"'/api/v1/sessions" >/dev/null'
curl -I "$url"                                    # UI応答を確認
```

`clrnd status`はReady条件、latest ready revision、traffic split、URLを表示する。`mise run agentsview:cloudrun:diff`が空であれば、live serviceとmanifestが一致している。

Google Cloud Consoleで次も確認する。

- `min instances = 0`、`max instances = 1`
- memory 512 MiB、CPU 1、request-based billing
- runtime service accountが`agentsview-runtime`
- secretの値がlogへ出ていない
- CockroachDB RU、storage、connection数が無料枠内

## 無料枠の内訳と使い切ったときの調べ方

調査日: **2026-09-08**。無料枠は予告なく変わるので、判断の前に各公式Pricingを開き直す。

### Cloud Run本体

[Cloud Run pricing](https://cloud.google.com/run/pricing)のrequest-based billingに対する月次無料枠は次の3本である。**billing accountごと**の枠で、同じbilling accountに紐づく全projectの使用量を合算し、毎月resetされる。instance-based billingを選ぶとこの枠は当たらない。

| 項目      | 月次無料枠     |
| --------- | -------------- |
| vCPU      | 180,000 vCPU秒 |
| memory    | 360,000 GiB秒  |
| request数 | 200万request   |

現在のmanifestは1 vCPU／512 MiB（`cloudrun-service.yaml`の`resources.limits`）なので、この3本を実時間へ直すと**vCPUが最初に尽きる**。

- vCPU: 180,000 ÷ 1 vCPU = **50時間／月**のcontainer稼働
- memory: 360,000 ÷ 0.5 GiB = 200時間／月
- request: 個人viewerでは200万requestに届かない

つまり実質的な上限は「containerが動いている合計時間が50時間／月」である。memoryを1 GiBへ上げるとmemory側が100時間へ縮むが、依然としてvCPUが先に尽きる。逆にCPUを0.5へ落とせばvCPU側は100時間まで伸びる（cold startは遅くなる）。

枠を減らさないための設定はすでに入っている。

- `autoscaling.knative.dev/minScale: "0"` — idle時にinstanceを0にする。`min > 0`にすると無通信でも課金対象になる
- `run.googleapis.com/cpu-throttling: "true"` — request処理中とstartup中だけCPUを使う（request-based billing）
- `autoscaling.knative.dev/maxScale: "1"` — crawlerに叩かれてもinstanceが増えない

### Cloud Run以外の枠

Cloud Runの無料枠が覆うのはcompute（vCPU秒／GiB秒）とrequest数だけである。**networking egressと、buildや保管に使う周辺serviceは別枠**で、この構成ではそちらが先に尽きることがある。

| service                                                                 | 無料枠の目安                                       | この構成での消費源                                                                    |
| ----------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------- |
| [Artifact Registry](https://cloud.google.com/artifact-registry/pricing) | storage 0.5 GB／月                                 | deployごとに新しいimage tagが増える。**数世代で超えやすい**                           |
| [Cloud Build](https://cloud.google.com/build/pricing)                   | 2,500 build分／月（既定poolのe2-standard-2）       | `gcloud builds submit`。1回のmirror buildは短い                                       |
| [Secret Manager](https://cloud.google.com/secret-manager/pricing)       | active secret version 6件／月、access操作 10,000件 | `agentsview:cloudrun:secrets`のたびにversionが1つずつ増え、無効化しない限り残り続ける |
| [Cloud Logging](https://cloud.google.com/logging/pricing)               | 50 GiB／project／月                                | revisionのstdout／stderr。個人利用では通常余裕がある                                  |
| [Cloud Run networking](https://cloud.google.com/run/pricing)            | compute枠とは別                                    | CockroachDB Cloudへのegress                                                           |

Artifact Registryはこの中でいちばん詰まりやすい。image tagがcommitごとに変わり、GitHub Actionsがmergeのたびにdeployするようになってさらに増えるため、Terraformでcleanup policyを入れてある（`gcp_artifact_registry.tf`）。残るのは**直近10 versionまたは30日以内、のいずれかに当てはまるもの**で、10ちょうどには絞られない。Dockerfileがupstream imageのmirror（`FROM`1行）なので、同じupstream versionを何度buildしてもlayerは共有され、storageが実際に増えるのはupstream versionが上がったときだけである。min 0でscale-to-zeroする構成ではcold startのたびにimageをpullし直すため、直近10世代は必ず残して稼働中・rollback先のrevisionが参照するimageを消さないようにしている。

Secret Managerのversionは自動では消えない。rotationを重ねると6件の枠を超えるので、rollback先として要らなくなった古いversionは手で無効化・破棄する。**動作中のrevisionが参照しているversionは消さない**（revisionはinstance起動時に番号で解決するため、消すとinstanceが起動できなくなる）。

```sh
# 参照中のversionを先に確認する
mise run agentsview:cloudrun:render | rg 'agentsview-(pg-url|config-toml)' -A2

gcloud secrets versions list agentsview-config-toml --project="$GCP_PROJECT_ID"
gcloud secrets versions destroy <古い番号> --secret=agentsview-config-toml --project="$GCP_PROJECT_ID"
```

### 使い切ったときにどこで確認するか

無料枠の残量を直接表示するUIは無い。**Billingのreportで、無料枠適用後の課金額がどのSKUに出ているか**を見るのが最短である。

1. Google Cloud Consoleの**Billing > Reports**を開く。
2. Group byを**SKU**にし、projectをAgentsViewのものへ絞る。
3. 期間を当月にして、金額が乗っているSKUを見る。`Cloud Run CPU Allocation Time`／`Memory Allocation Time`なら50時間を超えており、`Artifact Registry Storage`ならimageの積み上がりである。

Cloud Run側の実消費は、Cloud Monitoringの`run.googleapis.com/container/billable_instance_time`でも追える。Cloud Run画面の**Metrics**タブから同じ値を見られる。

50時間／月を超えているなら、原因は「instanceが動きっぱなしになる何か」である。次を順に確認する。

- `min-scale`が0のままか（`mise run agentsview:cloudrun:diff`で差分が出ないか）
- 未認証のcrawlerがURLを叩いていないか。Cloud Run画面のRequest countとLogs Explorerの`httpRequest.userAgent`で見る
- uptime check、health check、監視botなど、定期的にHTTPを投げるものを自分で足していないか
- `--write-timeout 100s`に張り付くほど重いanalytics queryが繰り返されていないか（1 requestあたりのCPU秒が伸びる）

課金を止める仕組みはbudget alertには無い（alertは通知だけで、自動停止はしない）。止めるならinvoker bindingを外して到達できないようにするか、`clrnd delete`でserviceごと消す。deterministic URLはservice名・project number・regionから決まるので、消して作り直しても同じURLへ戻る。

## 運用: インフラ設定を変更したあとの適用手順

**Cloud Runへのdeployだけがmerge時に自動で走る。Terraformは自動適用しない。** mainへのmergeでCloud Run関連fileに差分があると`.github/workflows/deploy-agentsview.yaml`がbuild → deployを実行する。それ以外（Terraform、tool version、mise task）は従来どおりoperatorが手で適用する。

適用は変更したfileによって経路が違う。まず次で判断する。

| 変更したfile                                  | 適用に必要なこと                                                                                          |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `dot_config/agentsview/cloudrun-service.yaml` | **merge時にActionsがdeployする。** 手元で先に出したい場合は`chezmoi apply` → `agentsview:cloudrun:deploy` |
| `dot_config/agentsview/Dockerfile`            | 同上。image tagが変わるため再buildが要る（手元でやる場合は`AGENTSVIEW_SKIP_BUILD`を使えない）             |
| `dot_config/agentsview/clrnd.yml`             | merge時にActionsがdeployする。手元で使うには`chezmoi apply`も要る                                         |
| `dot_config/agentsview/scripts/cloudrun.sh`   | 同上                                                                                                      |
| `dot_config/mise/tasks/agentsview.toml`       | `chezmoi apply` のみ（deployは走らない）                                                                  |
| `terraform/agentsview/*.tf`                   | `terraform plan` → 内容確認 → `terraform apply`（**自動適用しない**）                                     |
| `dot_config/mise/config.toml`（tool version） | `chezmoi apply` → `mise install`                                                                          |

手元からのdeployとActionsからのdeployは同じ`cloudrun.sh deploy`を呼ぶので、どちらで出しても結果は同じrevisionになる。緊急時に手元から先に出しても、後続のmergeで同じ内容が再deployされるだけである（差分が無ければclrndは新revisionを作らない）。

### GitHub ActionsからのCloud Run deploy

`.github/workflows/deploy-agentsview.yaml`は、mainへのpushで次のいずれかに差分があるときだけ動く。`workflow_dispatch`で手動起動もできる。

- `dot_config/agentsview/Dockerfile`（AgentsViewのversion）
- `dot_config/agentsview/cloudrun-service.yaml`
- `dot_config/agentsview/clrnd.yml`
- `dot_config/agentsview/scripts/cloudrun.sh`
- workflow自身

Dockerfileが対象に入っているため、**RenovateのAgentsView version bump PRをmergeすると、そのままCloud Runまで反映される。**

認証はservice account keyではなくGitHub OIDC ＋ Workload Identity Federationで行う。repositoryに置く3つのActions secretはいずれも鍵ではなく、識別子である。

| secret                           | 値                                                                |
| -------------------------------- | ----------------------------------------------------------------- |
| `GCP_PROJECT_ID`                 | Google Cloud project ID                                           |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `terraform output -raw github_actions_workload_identity_provider` |
| `GCP_DEPLOY_SERVICE_ACCOUNT`     | `terraform output -raw github_actions_deploy_service_account`     |

初回設定の手順は次のとおり。

```sh
# 1. WIFとdeploy service accountを作る
fnox exec -- terraform -chdir=terraform/agentsview plan -input=false -out=tfplan
fnox exec -- terraform -chdir=terraform/agentsview show tfplan
fnox exec -- terraform -chdir=terraform/agentsview apply tfplan

# 2. workflowへ渡す値を取り出す
terraform -chdir=terraform/agentsview output -raw github_actions_workload_identity_provider
terraform -chdir=terraform/agentsview output -raw github_actions_deploy_service_account

# 3. production environmentのsecretとして登録する
gh secret set GCP_PROJECT_ID --env production
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --env production
gh secret set GCP_DEPLOY_SERVICE_ACCOUNT --env production

# 4. workflow_dispatchで一度流して確認する
gh workflow run deploy-agentsview.yaml
```

> [!IMPORTANT]
> `gcp_storage.tf`の`google_storage_bucket.build_staging`は、`gcloud builds submit`がbuild contextを置く`<project-id>_cloudbuild` bucketをTerraformの管理下に置く。**このbucketが既にある場合（手元で一度でも`agentsview:cloudrun:build`を実行していれば作られている）、applyの前にimportする。** import せずにapplyすると409（already exists）で止まる。
>
> ```sh
> cd terraform/agentsview
> fnox exec -- terraform import google_storage_bucket.build_staging \
>   "${GCP_PROJECT_ID}/${GCP_PROJECT_ID}_cloudbuild"
> fnox exec -- terraform plan -input=false
> ```
>
> import後のplanが**置き換え（destroy → create）**を出す場合は、`location`が実際のbucketと違っている。そのままapplyするとbucketが消えるので、実値へ合わせてからapplyする。
>
> ```sh
> gcloud storage buckets describe "gs://${GCP_PROJECT_ID}_cloudbuild" --format='value(location)'
> ```
>
> bucketがまだ無い（新規project）場合はimportは不要で、そのままapplyすれば作られる。

deploy identityに与えているのは、Cloud Runの更新（`roles/run.developer`）、buildの投入（`roles/cloudbuild.builds.editor`）、runtime service accountへの`actAs`、build staging bucket、Artifact Registryのread、2つのsecretのmetadata読みだけである。**secretの値は読めず、versionも追加できない。** secret rotationは従来どおり手元の`agentsview:cloudrun:secrets`で行う。

`actAs`はruntime service accountの1件に絞ってあり、Cloud Build側のservice accountには付けていない。buildを走らせるidentityはprojectの作成時期で変わり（旧`<num>@cloudbuild.gserviceaccount.com`かCompute Engine既定の`<num>-compute@developer.gserviceaccount.com`）、存在しない方へ`google_service_account_iam_member`を書くとapplyが404で落ちるためである。実際に不足していた場合だけ下の1行を足す運用にしている。

token交換はrepositoryとbranchの両方で絞っている（`terraform/agentsview/gcp_iam.tf`の`attribute_condition`）。forkやpull requestからのworkflowはaccess tokenを取得できない。別branchから試したい場合は`locals.tf`の`github_deploy_ref`を一時的に変えてapplyし、確認後にmainへ戻す。

buildがCloud Build service accountの`actAs`不足で落ちる場合（projectの作成時期によってbuildを走らせるidentityが変わる）、errorが名指ししたservice accountへ次を足す。

```sh
gcloud iam service-accounts add-iam-policy-binding <error-that-named-this-sa> \
  --project="$GCP_PROJECT_ID" \
  --member="serviceAccount:$(terraform -chdir=terraform/agentsview output -raw github_actions_deploy_service_account)" \
  --role=roles/iam.serviceAccountUser
```

自動deployを止めたいときはGitHubのUIでworkflowをdisableする。Google Cloud側の権限を落とすなら`terraform destroy -target=google_service_account.deploy`ではなく、`gcp_iam.tf`のGitHub Actions分をまとめて消してapplyする（poolとproviderは論理削除されるまで同じIDで作り直せない点に注意する）。

### 手順1. mainを取り込み、applyする

Cloud Run関連のfileは`~/.config/agentsview`へchezmoiが配置したものが使われる。**source treeを更新しただけでは反映されない。**

```sh
git -C ~/dotfiles switch main
git -C ~/dotfiles pull
chezmoi apply
```

`chezmoi apply`を忘れると古いmanifestがそのままdeployされる。`build`／`deploy`／`verify`／`render`／`diff`はchezmoi sourceとの差分があると停止するので気づけるが、`chezmoi status`で先に確認しておくとよい。

```sh
chezmoi status ~/.config/agentsview   # 何も出なければ最新
```

### 手順2. Terraformの変更を適用する

Terraformの変更が無いPRなら飛ばしてよい。

```sh
fnox exec -- terraform -chdir=terraform/agentsview plan -input=false -out=tfplan
fnox exec -- terraform -chdir=terraform/agentsview show tfplan
fnox exec -- terraform -chdir=terraform/agentsview apply tfplan
```

**planに`destroy`が含まれていたら、その1件ずつを説明できるまでapplyしない。** とくにCloud Run serviceがdestroy対象に出た場合は、clrndが所有するserviceをTerraformが消そうとしている（2.0.4の状態移譲が未実施）。そのままapplyしてはいけない。

`tftui`を使うとplanの中身をtree表示で追える。

```sh
fnox exec -- tftui
```

### 手順3. Cloud Runの変更を適用する

manifestやDockerfileを変えた場合だけ実行する。まず差分を確認する。

```sh
mise run agentsview:cloudrun:diff
```

出た差分が意図したものだけであることを確認してからdeployする。

```sh
# manifestだけを変えた場合（imageは変わらないのでbuildを省ける）
AGENTSVIEW_SKIP_BUILD=1 mise run agentsview:cloudrun:deploy

# Dockerfile（AgentsViewのversion）を変えた場合はbuildから
unset AGENTSVIEW_IMAGE
mise run agentsview:cloudrun:deploy
```

`AGENTSVIEW_IMAGE`を過去にexportしたshellをそのまま使うと、古いimageが固定されたままdeployされる。Dockerfileを変えたときは必ず`unset`する。

`deploy`は差分を表示して確認を求め、新revisionがReadyになるまで待ち、rollout失敗時はnon-zeroで終了する。

### 手順4. 適用結果を確認する

```sh
mise run agentsview:cloudrun:status                    # 最新revisionが100% traffic
mise run agentsview:cloudrun:diff                      # 差分が無いこと
curl -i "$(mise run agentsview:cloudrun:status | rg -o 'https://\S+' | head -1)/api/v1/sessions"  # 401
```

失敗した場合は作業6のtroubleshootingへ戻る。revisionが起動しない原因はrevision logにしか出ない。

### 適用順序に依存関係がある場合

Terraformとmanifestの両方を変えたPRでは、**権限を足す変更はTerraformが先、権限を外す変更はCloud Runが先**である。runtime service accountに新しいsecretへのaccessorを足してからそのsecretを参照するmanifestをdeployしないと、revisionは起動時にsecretを解決できずに失敗する。逆に参照をやめる場合は、先にmanifestから外してからIAMを削る。

### Cloud Run revisionを戻す

manifestやimageの変更で問題が出た場合、DBには触れずCloud Run側だけを前のrevisionへ戻せる。trafficの向き先が変わるだけで、新しいrevisionは作られない。

Cloud Run側のapp revisionだけを戻す場合は、DB移行のrollbackとは切り離してclrndで行う。trafficだけが変わり、新revisionは作られない。

```sh
mise run agentsview:cloudrun:revisions
mise run agentsview:cloudrun:rollback                       # 直前のrevisionへ
mise run agentsview:cloudrun:rollback -- --revision <name>  # revisionを指定する
```

rollback後はtrafficがrevision名にpinされる。最新revisionを追う状態へ戻すまで`refresh`は動かない（新revisionがtrafficを受け取れないため）。戻すには次を実行する。

```sh
mise run agentsview:cloudrun:clrnd -- traffic --to-latest
```

### 複数PCで運用している場合

Cloud Runへのdeployはどれか1台から行えばよい（serviceはGoogle Cloud上に1つしかない）。ただし`chezmoi apply`と`mise install`は各PCで必要である。各PCから`agentsview:cockroach:push`する構成のため、tool versionがPC間でずれるとpushするdata versionもずれる。

---
