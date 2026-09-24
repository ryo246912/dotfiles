# agentsview pg-sync

複数端末のセッション情報をCockroachDB Cloudに集約し、Cloud Run上のread-only Web UIで参照する構成。

## Cloud Run／CockroachDBへの移行手順

対象構成:

- AgentsView app: Google Cloud Run
- AgentsView DB: CockroachDB Cloud Basic

AgentsViewのsource of truthは各PCのlocal SQLite archiveであり、CockroachDBはそこからの派生である。Atuinのdatabase／role／appには触れない。

### ゼロから構築する場合の全体手順

#### A. 完了条件と作業順序

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

Google Cloudへloginする。

```sh
gcloud auth login
gcloud auth application-default login
```

**完了確認:** Google Cloud Consoleでprojectとbudgetが見え、CockroachDB service accountにorganization scopeの`Cluster Creator`が表示され、その`CCDB1_...` secretがsecret storeに保存され、上記の`gcloud auth login`と`gcloud auth application-default login`がどちらもerrorなく完了している。

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
export GCP_PROJECT_ID='agentsview'
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

**完了確認:** 次は値を表示せず、すべて`set`を返す。

```sh
fnox exec -- sh -c '
  for name in AGENTSVIEW_AUTH_TOKEN AGENTSVIEW_CURSOR_SECRET; do
    eval "test -n \"\${$name:-}\"" && echo "$name=set" || exit 1
  done
'
```

##### 作業3〜4. GCP／CockroachDBの基盤をinfraリポジトリでprovisionする

**Google Cloud API有効化、Artifact Registry、runtime service account、Secret Managerのsecret container、CockroachDB Cloud Basic cluster／database／owner・push・read SQL user、Cloud Run invoker IAMのTerraformコードは[`ryo246912/infra`](https://github.com/ryo246912/infra)リポジトリへ移行した。** このdotfilesリポジトリに`terraform/agentsview`は存在しない。state bucketの作成、`terraform init`／`plan`／`apply`、state lockの扱いはすべてinfraリポジトリのrunbookに従う。

初回provisioningの手順（state bucket作成、CockroachDB service account／API keyの発行を反映したtfvars作成、target applyでの基盤構築）もinfraリポジトリ側に移った。作業2で用意したpassword（`TF_VAR_cockroach_owner_password`等）とCockroachDB API keyは、Bitwarden Secrets Manager上で引き続きこのdotfilesリポジトリと同じprojectから読めるようにしておく。

**完了確認:** infraリポジトリのapplyが完了し、CockroachDB Consoleの**Clusters**で`agentsview` clusterが`Basic`としてReadyになり、**SQL Users**にowner／push／readが表示され、Google Cloud ConsoleでArtifact Registry repository・2つのSecret Manager secret container・runtime service accountが作成されている。cluster ID、database名、SQL hostはinfraリポジトリのTerraform outputまたは各Consoleから取得する。

##### 作業5. CockroachDB接続URL、schema、最小権限を作る

infraリポジトリのTerraform outputでhostとdatabaseを確認する（`terraform output -raw cockroach_sql_host` / `cockroach_database`）。passwordはfnoxの子processだけへ渡すため、現在のshellへ`export`しない。

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

このcommandもSQLSTATE `28P01`になる場合、infraリポジトリのTerraformがSQL userへ設定した`TF_VAR_cockroach_owner_password`と、後から手作業で作った`AGENTSVIEW_COCKROACH_OWNER_PG_URL`内のpasswordが一致していない。特に、SQL user作成後にBitwardenの`TF_VAR_cockroach_owner_password`だけを更新した場合や、URLへ別userのpasswordを貼った場合に発生する。

5. 上記`psql`を再実行し、`current_user`が`agentsview_owner`になることを確認してから`agentsview pg push`へ進む。

CockroachDB Console等でpasswordを別途変更していない前提で、infraリポジトリ側のplanが`No changes`なのにURLだけが28P01になる場合、URL secretだけが誤っている可能性が高い。`TF_VAR_cockroach_owner_password`と同じ値で`AGENTSVIEW_COCKROACH_OWNER_PG_URL`を作り直し、Terraform applyは行わず`psql`を再試行する。Consoleで変更した履歴がある場合は、planの有無にかかわらず上記rotationを実施してinfraリポジトリのTerraformをsource of truthへ戻す。

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

Cloud Buildのdefault build service accountと、Artifact Registry repositoryに付与されたwriter権限をCLIで確認する。**Cloud Build > Settings**はbuild service accountが別serviceの権限を持つかを確認する画面ではなく、repository-level IAMは表示されない。infraリポジトリのTerraform applyのlogにある`google_artifact_registry_repository_iam_member.cloud_build_writer`の`Refresh complete`／`No changes`は、候補となる両方のservice accountへのwriter bindingが既にstateと実環境に存在することを示す。

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

結果にdefault service accountと`roles/artifactregistry.writer`が1行表示されれば付与済みである。Consoleで見る場合は**Artifact Registry > Repositories > agentsview > Permissions**を開く。何も表示されない場合だけ、infraリポジトリ側の最新Terraformを通常の`plan`／`apply`で反映し直す。

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

- **`locking config: open /data/config.toml.lock: read-only file system`** — `AGENTSVIEW_DATA_DIR`（image既定は`/data`）へSecret Managerのvolumeを直接mountすると起きる。AgentsViewはconfigを読む前に必ず同じdirectoryへlock fileを作るため、data dirがread-onlyだと config.toml の内容以前に落ちる。secretは`/etc/agentsview`へmountし、起動時に`$AGENTSVIEW_DATA_DIR`へcopyする（`cloudrun-service.yaml`の`command`）。data dirにsecret volumeを重ねてはならない。
- **`install: skipping file ... as it was replaced while being copied`** — `cp`／`install`はコピー前後でsourceのmetadataを比較し、動いていれば中断する。Secret ManagerのvolumeはFUSEベースでmetadataが安定しないため誤検知する。この検査を持たない`cat`でdata dirへ書き出す（`cloudrun-service.yaml`の`command`）。
- **`schema incompatible` / `sessions table missing required columns`** — CockroachDB側に`agentsview` schemaのtableがまだない。作業9の最初の`push`が未実行のまま作業8をdeployするとこうなる。`pg serve`はread-only roleで接続するためschema migrationを自分では実行できず、compatibility checkに落ちてexitする。先に作業9の`agentsview:cockroach:push:remote`を済ませてから再deployする。
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

Cloud Run URLはまだ存在しないため、初回configだけplaceholderを使う。URL確定後の作業8で必ず置き換える。

```sh
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
export AGENTSVIEW_CLOUD_RUN_URL='https://invalid.example'
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
> - `pg serve`は起動時にschema互換checkを行い、`sessions` tableが無いとlistenする前にexitする。read roleではmigrationを実行できないため、作業5の権限設定と`agentsview pg status`でtableが作られていることを先に確認する。まだ無い場合は作業9の`agentsview:cockroach:push:remote`を先に済ませる。
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

clrndが作るserviceは**private**である。公開はinfraリポジトリが管理するTerraformのinvoker bindingで行う。serviceが存在した状態で、infraリポジトリ側の該当moduleに対して通常のplan／applyを実行する。

Cloud Run URLを取得し、placeholder configを実URLへ置き換えて新revisionを作る。revisionにはsecretのnumeric versionが焼き込まれているため、新versionを追加しただけでは切り替わらない。`deploy`が新しいversion番号でmanifestをrenderし、新revisionを作る（imageは変わらないので`AGENTSVIEW_SKIP_BUILD=1`でbuildを省く）。

```sh
export AGENTSVIEW_CLOUD_RUN_URL=$(gcloud run services describe ryo-agentsview \
  --project="$GCP_PROJECT_ID" --region="$GCP_REGION" --format='value(status.url)')
fnox exec -- mise run agentsview:cloudrun:secrets
AGENTSVIEW_SKIP_BUILD=1 mise run agentsview:cloudrun:deploy
```

Google Cloud Consoleの**Cloud Run > ryo-agentsview**で、region、1 CPU、512 MiB、min 0、max 2、runtime service account、Secret Manager参照を確認する。**Revisions**で最新revisionが100% trafficになっていることも確認する。同じ内容は`mise run agentsview:cloudrun:status`でも確認できる。

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
fnox exec -- mise run agentsview:cockroach:push:remote -- --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'
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

**完了確認:** 上の`fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'`が対象projectのsessionを報告し、認証済みAPI、session一覧、detail、analytics、usageが表示され、Cloud RunとCockroachDBにerrorがない。

##### 作業10. 全projectへ広げて運用を始める

1. 全PCのpush／watch／timerを停止し、停止した端末一覧とUTC時刻を記録する。
2. 各PCで残りの全projectを`agentsview:cockroach:push:remote`する（`--projects`を付けなければ全project）。
3. remoteの`fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'`とCloud Run viewerで、想定するsessionが揃っていることを確認する（`agentsview:cockroach:status`はlocal containerを見るtaskなので、ここでは使わない）。
4. 各PCの通常taskを`agentsview:cockroach:push:remote`へ切り替え、小さいprojectから再開する。
5. Cloud Runを再度smoke testする。
6. 数日はCloud Run error、CockroachDBのRU／storage、backupを毎日確認する。

```sh
fnox exec -- mise run agentsview:cockroach:push:remote
fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'
fnox exec -- mise run agentsview:cockroach:merge
mise run agentsview:cockroach:dump:local
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

### 0. 変更前の安全確認

1. 各PCのlocal SQLite archiveがsource of truthである。CockroachDBはそこからの派生なので、まずlocal archiveが健全であることを確認する。

```sh
agentsview projects --format json | jq -r '.[] | "\(.name)\t\(.session_count // "?")"'
```

2. 既にCockroachDBを使っている場合は、現在の件数を控えておく。作業後の比較対象になる。

```sh
fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'
```

3. local CockroachDBへ統合backupを作れる状態にしておく。CockroachDBとlocal archiveの両方をまとめたdumpが手元に残る。

```sh
fnox exec -- mise run agentsview:cockroach:merge
mise run agentsview:cockroach:dump:local
```

4. そのbackupをlocal CockroachDBへrestoreできることを確認する。backup fileを作っただけでは合格にしない。

```sh
bash ~/.config/agentsview/scripts/localdb.sh restore
```

### 1. CockroachDBの権限設計を決める

Basic cluster、database、owner／push／read userは[`ryo246912/infra`](https://github.com/ryo246912/infra)リポジトリのTerraformで作成する。Terraformは10 GiB storage／5,000万RUのusage limitも設定し、意図しない有料利用を防ぐ。passwordはuserごとに異なるrandom valueを用意する。

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

### 2. Google Cloud／CockroachDBの基盤とCloud Runのdeploy分離

**基盤のTerraformコードは[`ryo246912/infra`](https://github.com/ryo246912/infra)リポジトリに存在する。** このdotfilesリポジトリからはterraformを実行しない。infraリポジトリのTerraformは次を一括管理する。

- Google Cloud API有効化、Artifact Registry repository
- Cloud Run runtime service account
- Secret Managerのsecret containerとruntime IAM（secret value／versionはstateへ保存しない）
- Cloud Run invoker IAM（`allUsers`向けpublic invoker binding。Service本体はclrndが所有し、Terraformは管理しない）
- CockroachDB Cloud Basic cluster、database、owner／push／read SQL user

このdotfilesリポジトリが引き続き担当するのは、CockroachDBへのdata同期（3節・4節）と、clrndによるCloud Run app deploy（このあと）だけである。基盤のprovisioning・変更手順はinfraリポジトリのrunbookを参照する。

#### 2.0 Terraform resourceの意味

infraリポジトリのTerraformは「永続的な基盤」を管理し、Cloud Run自体のapp deployは管理しない（deployはclrndが行う）。各resourceの役割は次のとおり。

| Terraform resource                                  | コード上の主要設定                              | 作成されるもの／必要な理由                                                                                                                                  |
| --------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `google_project_service.required`                   | `gcp_apis.tf`のAPI名setを`for_each`             | Cloud Run、Artifact Registry、Cloud Build、Secret Manager、IAM、STS等のGoogle Cloud APIをprojectで有効化する。APIを使う前提条件であり、app revisionではない |
| `data.google_project.current`                       | `gcp_project_id`からprojectを参照               | project numberを取得し、Cloud Buildで使われ得るGoogle管理service account名を組み立てる。resourceは新規作成しない                                            |
| `google_artifact_registry_repository.agentsview`    | `us-west2`、Docker format                       | AgentsView container imageを保存するrepository。ECR repositoryに相当する                                                                                    |
| `google_artifact_registry_repository_iam_member.*`  | runtime=`reader`、Cloud Build／deploy=`writer`  | runtimeはimage pullだけ、build／deploy主体はpushできるよう最小権限を分離する                                                                                |
| `google_service_account.runtime`                    | `agentsview-runtime`                            | Cloud Run containerが実行時に使うidentity。Secret Managerを読むがdeployはしない。ECS task roleに近い                                                        |
| `google_secret_manager_secret.pg_url`               | secret containerのみ                            | CockroachDB read-only URLの入れ物。値／versionはTerraformへ入れず別taskで追加する                                                                           |
| `google_secret_manager_secret.config`               | secret containerのみ                            | `/etc/agentsview/config.toml`としてmountするAgentsView configの入れ物                                                                                       |
| `google_secret_manager_secret_iam_member.runtime_*` | `secretAccessor`                                | runtimeだけがDB URL／configを読めるようにする                                                                                                               |
| `cockroach_cluster.agentsview`                      | GCP、Basic、`us-west2`、10 GiB／5,000万RU limit | AgentsView用CockroachDB cluster本体。persistent dataを持つためdelete protectionを有効にする                                                                 |
| `cockroach_database.agentsview`                     | database名`agentsview`                          | app schemaを格納するlogical database                                                                                                                        |
| `cockroach_sql_user.owner`                          | owner password                                  | schema bootstrap／migration専用user                                                                                                                         |
| `cockroach_sql_user.push`                           | push password                                   | 各PCからsessionを送るuser。app viewerとは分離する                                                                                                           |
| `cockroach_sql_user.read`                           | read password                                   | Cloud Run viewer用user。後続SQLでSELECTだけを付与する                                                                                                       |
| `google_cloud_run_v2_service_iam_member.public`     | `allUsers` + `roles/run.invoker`                | Cloud Run URLへの未認証到達を許可する。AgentsView自身のbearer認証は別途維持する。clrndはIAMを扱わないため、この1件だけCloud Run側に残す                     |

**deploy用service accountとGitHub Workload Identity連携もこの表にない。** GitHub ActionsからTerraformやCloud Run deployを行っていない（`.github/workflows/`に残るのはAtuinのFly.io deployだけ）ため、`agentsview-deploy` service account、そのproject IAM、`secretVersionAdder`、Workload Identity Pool／Providerはいずれも使われていなかった。使わないidentityを置くと権限の棚卸し対象が増えるだけなので削除した。build・deploy・secret登録はoperator自身の認証情報（`gcloud auth login`）で実行する。将来CIから実行する場合はWIFごと作り直す。

**Cloud Run Service本体(`google_cloud_run_v2_service.agentsview`)はこの表にない。** 2.0.2のとおりclrndが所有するため、Terraformコードから削除した。表に残る`google_cloud_run_v2_service_iam_member.public`だけはCloud Run resourceを参照せず、service名と`local.region`を直接指定するので、Terraform stateはCloud Run Serviceに依存しない。

Cloud Run service名はmanifest・`clrnd.yml`・infraリポジトリのTerraformの3箇所で一致している必要がある。image URIとSecret Managerのversionはclrnd manifest側で解決するため、Terraform変数としては扱わない。Cloud Run URLはTerraform outputではなく`clrnd status`または`gcloud run services describe`から取得する。

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

したがって採用した分離は、**infraリポジトリのTerraformがAPI、Artifact Registry、runtime service account、Secret Manager、CockroachDBを管理し、clrndがCloud Run Service／Revision／trafficを管理する**形である。Cloud Run Serviceを空の「cluster」としてTerraformで先に作り、後から別toolが同じService templateを管理する構成にはしない。同じresourceをTerraformとclrndの両方が所有すると、次回`terraform apply`がclrndのdeployを差し戻す競合を起こす。

#### 2.0.2 `clrnd`によるdeploy分離（採用済み）

[`masasuzu/clrnd`](https://github.com/masasuzu/clrnd)をv0.5.0でpinして採用し、Cloud Run Serviceのownershipをclrndへ移した。TerraformコードからCloud Run Service resourceを削除済みで、**同じresourceを2つのtoolが所有する状態は作らない**。

| 所有者                         | 対象                                                                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Terraform（`infra`リポジトリ） | Google Cloud API有効化、Artifact Registry、runtime service account、Secret Manager container／IAM、CockroachDB、Cloud Run invoker IAM |
| clrnd（このリポジトリ）        | Cloud Run Service定義（image、CPU／memory、concurrency、timeout、scaling、環境変数、Secret Manager参照）、Revision、traffic、rollback |

ecspressoとの対応は`verify`／`diff`／`deploy`／`rollback`がほぼそのまま対応する。deploy後はrevisionがReadyになるまで待ち、rollout失敗時はnon-zeroで終了するのでCIでも使える。

mise taskは次を追加した。いずれもrepository rootでも、chezmoi適用後の`~/.config/agentsview`だけがある環境でも動作する。

| task                            | 内容                                                                     |
| ------------------------------- | ------------------------------------------------------------------------ |
| `agentsview:cloudrun:build`     | commitでtagを固定してArtifact Registryへimageをbuild                     |
| `agentsview:cloudrun:verify`    | manifestのschema検証と、service account／secret version／imageの実在確認 |
| `agentsview:cloudrun:render`    | templateを展開したmanifestを表示（APIへ接続しない）                      |
| `agentsview:cloudrun:diff`      | live serviceとmanifestの差分                                             |
| `agentsview:cloudrun:deploy`    | build → verify → deploy → rollout待ち                                    |
| `agentsview:cloudrun:status`    | Ready状態、traffic split、URL                                            |
| `agentsview:cloudrun:revisions` | revision一覧とtraffic share                                              |
| `agentsview:cloudrun:refresh`   | 定義を変えずに新revisionを作る（containerの再起動）                      |
| `agentsview:cloudrun:rollback`  | 直前のrevisionへtrafficを戻す                                            |

共通処理（project／region／service名の解決、image URIの組み立て、secret versionのpin、Cloud Build、clrnd実行）はhidden taskの`agentsview:cloudrun:_lib`が持つ。このtaskは関数定義を標準出力へ出すだけで、各taskが先頭で`eval "$(mise run agentsview:cloudrun:_lib)"`して読み込む。設定の解決は1箇所にしかない。

この形にしているのは、**miseがtaskへ渡した追加引数をscript末尾へ文字列として連結する**ためである。`"$@"`は常に空になり、子taskへ引数を渡す方式は成立しない。

```console
$ mise run t -- --projects resume     # run = 'printf "ARGS>"; printf " [%s]" "$@"'
ARGS> []--projects resume
```

そのため引数は`usage` fieldで受け取る。miseはshell quote済みの1行を`usage_args`に入れるので、`eval "set -- ${usage_args:-}"`で元のargvへ戻す。空白や引用符を含む引数も保持される。tera の`{{arg()}}`でも同じことはできるが、mise 2027.5.0で削除予定の警告が出るため使わない。

採用にあたって前提にした制約は次のとおり。

- **IAMはclrnd管理外。** `allUsers`のinvoker bindingはinfraリポジトリのTerraformに残す。clrndが作るserviceは常にprivateなので、初回は「clrnd deployでserviceを作る → infraリポジトリでTerraform applyしてinvoker bindingを付ける」の順序になる。
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
| 同`maxScale`                                                            | `2`                                                                        | 旧`scaling.max_instance_count`。無料枠を超える暴走を防ぐ                                         |
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

#### 2.1 初回provisioningの流れ

state bucketの作成、`terraform init`／`plan`／target applyによる基盤構築、CockroachDB service accountのAPI key発行はすべてinfraリポジトリのrunbookに従う。このdotfilesリポジトリ側で行うのは、基盤ができたあとのimage buildとCloud Run deployだけである。

```sh
# 1. infraリポジトリ側でGoogle Cloud API／Artifact Registry／runtime service account／
#    Secret Manager container／CockroachDB cluster・database・SQL userをapplyする
#    （Cloud Run invoker bindingはclrndがserviceを作ったあとに回す。手順は次項）

# 2. このリポジトリで最初のimageをbuild
mise run agentsview:cloudrun:build

# 3. CockroachDBのread-only URLとAgentsView configをSecret Managerへ登録する
#    （初回だけplaceholder URLを使い、service作成後に実URLへ更新する）
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
export AGENTSVIEW_CLOUD_RUN_URL='https://invalid.example'
fnox exec -- mise run agentsview:cloudrun:secrets

# 4. clrndからCloud Run Serviceを作る（Terraformはこの時点でServiceを作らない）
mise run agentsview:cloudrun:verify
mise run agentsview:cloudrun:deploy

# 5. infraリポジトリ側でCloud Run invoker binding（allUsers）をapplyし、serviceを公開する

# 6. 実URLを取得してconfig secretを更新し、新revisionへ反映する
export AGENTSVIEW_CLOUD_RUN_URL=$(gcloud run services describe ryo-agentsview \
  --project="$GCP_PROJECT_ID" --region="$GCP_REGION" --format='value(status.url)')
fnox exec -- mise run agentsview:cloudrun:secrets
AGENTSVIEW_SKIP_BUILD=1 mise run agentsview:cloudrun:deploy
```

Cloud Runのmin 0／max 2、1 vCPU／512 MiBは`mise run agentsview:cloudrun:diff`と`clrnd status`で確認する。CockroachDB clusterが`Basic`でReadyになっていること、SQL Users一覧などはCockroachDB Consoleかinfraリポジトリのoutputで確認する。

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

このrepositoryには現時点でCloud Run用GitHub Actions workflowを含めていない。CIへ載せる場合は`mise run agentsview:cloudrun:deploy -- --auto-approve`を実行する形になる（taskへ渡した引数はそのまま`clrnd deploy`へ渡る）。image tagはGitHub Actionsが渡す`GITHUB_SHA`から組み立てられるので、workflow側でimage URIを組み立てる必要はない。

このときsecret versionの解決に注意する。taskは既定で最新のENABLED versionをSecret Managerから引くが、それには`secretmanager.versions.list`が要る。CI用のidentityへ`secretVersionAdder`だけを与えた場合、versionを追加できても一覧できない。次のどちらかを選ぶ。

- secret登録stepが返したversion番号を`AGENTSVIEW_PG_URL_SECRET_VERSION`／`AGENTSVIEW_CONFIG_SECRET_VERSION`としてdeploy stepへ渡す（追加の権限が不要で、deployするversionをCI側が確定できる）。
- 2つのsecretに対して`roles/secretmanager.viewer`を追加し、taskに引かせる。metadataのみのroleなのでsecret値は読めない。

権限不足のまま実行した場合、taskはgcloudのerrorに続けてこの2択を表示して停止する。

**現時点ではdeploy用service accountもWorkload Identity連携もTerraformに存在しない。** CIから実行していないためである（2節参照）。CIへ載せるときは、deploy service account、そのproject IAM、Workload Identity Pool／Provider、state bucketへの`roles/storage.objectAdmin`をinfraリポジトリ側でまとめて作り直す。service-account key JSONは作らずGitHub OIDC／WIFを使う。

### 3. CockroachDB schemaをbootstrapしてlocalからpush

**方針: local archiveからpushして作る。** AgentsViewのlocal SQLite archiveが各PCのsource of truthであり、CockroachDBはそこからの派生である。したがって他のDBからdump／restoreするのではなく、各PCから`agentsview pg push`で入れ直す。

#### 3.1 小さいprojectでbootstrap

`AGENTSVIEW_MIGRATION_PROJECTS`には、Google Cloud等のproject名ではなく`agentsview projects --format json`に表示される既存のAgentsView projectから、最初に試すsession数の少ないものを1つ指定する。任意の`small-project`という名前を新規作成する意味ではない。候補一覧と選び方は作業5の手順を参照する。

```sh
export AGENTSVIEW_MIGRATION_PROJECTS='<agentsview projectsで確認した実在名>'
fnox exec -- mise run agentsview:cockroach:push:remote -- --projects "$AGENTSVIEW_MIGRATION_PROJECTS"
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
AGENTSVIEW_NO_DAEMON=1 fnox exec -- mise run agentsview:cockroach:push:remote -- --projects '<project>'
```

#### 3.3 内容を照合

```sh
fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'
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

AgentsViewの同期元はlocal databaseではなく、各PCにあるsession fileとAgentsViewのlocal SQLite indexである。`agentsview pg push`は、local sessionを同期してからshared databaseへupsertする**一方向同期**であり、shared databaseからlocal SQLite／session fileへ戻す`pg pull` commandはない。

CockroachDBはPostgreSQL wire protocolで接続でき、AgentsView 0.38.1はCockroachDBをshared databaseとして扱える。このrepositoryでは次の経路を採用する。

```text
各PCのsession file + local SQLite
    │
    │ agentsview pg push（public TLS、push role）
    ▼
CockroachDB Cloud Basic
    │                                │
    │ SELECTのみ（read role）        │ psql（data-only／column INSERT、push role）
    ▼                                ▼
Cloud Run上のagentsview pg serve     local CockroachDB（single-nodeのcontainer）
                                     │
                                     │ agentsview pg serve（mise run agentsview:serve）
                                     ▼
                                     手元のviewer／SQL
```

差分pushは各PCからCockroachDBのTLS endpointへ直接送る。proxyは介さない。

```sh
# 接続とwatermarkを確認
fnox exec -- sh -c 'AGENTSVIEW_PG_URL="$AGENTSVIEW_COCKROACH_PUSH_PG_URL" AGENTSVIEW_PG_SCHEMA=agentsview agentsview pg status'

# まず1 projectだけ
fnox exec -- mise run agentsview:cockroach:push:remote -- --projects '<project>'

# 差分を全projectへ反映
fnox exec -- mise run agentsview:cockroach:push:remote

# schema resetや内容修復後に限り全件を再送
fnox exec -- mise run agentsview:cockroach:push:remote -- --full --no-vectors
```

`agentsview:cockroach:push:remote` taskは常に`--no-vectors`を追加し、CockroachDBに送る対象をsession contentへ限定する。AgentsViewはDB vendorだけを見てvector phaseを自動停止しないため、taskを介さず直接実行するときも`--no-vectors`または`push_vectors=false`を必ず指定する。incremental watermarkは接続target／project filterごとにlocal保存される。初回CockroachDB pushは必ず小さいprojectで確認してから広げる。

#### 「pull」の代わりに何を使うか

| 目的                                      | 方法                                                                                                                                   |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| 別PCから同じsessionを閲覧する             | localへpullせず、Cloud Runのread-only viewerでCockroachDBを読む                                                                        |
| 新しいPCのlocal AgentsViewへsessionを戻す | AgentsViewの`pg pull`ではできない。元のagent session directoryのbackup／同期機能で復元してから再indexする                              |
| remoteのdataをlocalで参照する             | `agentsview:cockroach:merge`でremoteのrowをlocal CockroachDBへmergeし、`agentsview:serve`で読む                                        |
| CockroachDB障害に備える                   | `agentsview:cockroach:merge`でdataをlocal CockroachDBへmergeし、`agentsview:cockroach:dump:local`で保存する。自動replicaとはみなさない |
| localでSQL分析する                        | `localdb.sh sql`でlocal CockroachDBへ接続する（taskは置いていない）。本番へ直接繋ぐ場合はread-only roleを使い、双方向同期はしない      |

`agentsview pg pull`が無い以上、remoteのdataをlocalで扱う経路は「dumpして取り込む」しかない。localもCockroachDBにしているのは、この取り込みでengine差を跨がないようにするためである。dumpはdata-only／column INSERTでexportし、現在のAgentsViewがlocal CockroachDBへ作ったschemaへ、不足rowだけをmergeする。schema DDL・権限・sequenceはdumpから持ち込まない（schemaは常にAgentsViewのmigrationが作る）。

#### local CockroachDBの位置づけ

local CockroachDB（`dot_config/agentsview/compose.yaml`の`cockroach` service）はCockroachDBの自動pull先ではない。日常運用は、各PCのsession sourceからCockroachDBへ直接pushし、Cloud Runからreadする。localを使うのは、remote dataの取り込み・backup・手元での閲覧のときだけである。

```sh
# remoteのdataをlocalへ取り込む（dump → merge）
fnox exec -- mise run agentsview:cockroach:merge

# remoteへ接続せず、現在のlocal CockroachDBだけをdump（統合backupはmergeのあとにこれ）
mise run agentsview:cockroach:dump:local

# 手元のdumpを選んでlocalへmergeする（remote／localどちらのdumpでもよい）
bash ~/.config/agentsview/scripts/localdb.sh restore

# 取り込んだ内容をlocalのviewerで見る
mise run agentsview:serve
```

CockroachDB側にだけ存在するrowはlocalへ追加するが、同じprimary keyがlocalにある場合は`ON CONFLICT DO NOTHING`でlocalを維持する。このdumpは完全な双方向同期やreplicaではなく、閲覧・disaster recovery用の統合snapshotである。

importはINSERTを一定件数ごとのtransactionへ分けて流す。CockroachDBは1 transactionで書ける量に上限があり、dump全体を1 transactionにすると大きなbackupで失敗するためである。件数は`AGENTSVIEW_IMPORT_CHUNK_ROWS`（既定500）で変えられる。途中で失敗した場合、そこまでのchunkはcommit済みで残るが、すべてのINSERTが`ON CONFLICT DO NOTHING`なので、原因を直して同じfileを再実行すればよい。

取り込みの前に、localのidentity列（`GENERATED ALWAYS AS IDENTITY`）を`ALTER COLUMN ... SET GENERATED BY DEFAULT`で緩める。そのままでは明示idのINSERTが`cannot insert into column "id"`で止まり、`OVERRIDING SYSTEM VALUE`はCockroachDBが解釈しないためである。緩めたまま戻さない。localは鏡であり、AgentsView自身のINSERTはidを指定しないので`BY DEFAULT`でも挙動は変わらない（remoteのschemaには触らない）。このALTERが通らないengine、またはidentity列を列挙できない場合は、1行も取り込まずに中止する。緩めるのはdumpを読み切って形を確認したあとなので、受け付けないdumpでschemaが変わることはない。

取り込みの前に、同じfilterで読み切るだけのpassを1度走らせる。dumpが途中で切れている場合、filterの出力をそのままpsqlへ繋ぐと、切れていると分かる時点では手前のchunkが既にcommit済みになってしまうためである。この検証passはDBへ触らないので、壊れたdumpでは1行も書き込まれない。

#### dumpの作り方（`pg_dump`を使わない理由）

`pg_dump`はCockroachDBをsupportしない（[cockroachdb/cockroach#20296](https://github.com/cockroachdb/cockroach/issues/20296)）。`--schema`を渡すと`pg_dump`はschemaを絞るために次のqueryを送るが、CockroachDBは修飾付きのcollation名を解釈できず`at or near ".": syntax error`になる。

```text
WHERE n.nspname OPERATOR(pg_catalog.~) '^(agentsview)$' COLLATE pg_catalog.default
```

この`COLLATE pg_catalog.default`は、`pg_dump` 12以降がserver versionを12以上と見たときに必ず付ける（PostgreSQLの`src/fe_utils/string_utils.c`）。optionでは外せないため、remote／localのどちらのdumpでも`pg_dump`は使えない。

代わりに、行の組み立てはserver側に任せる。`dot_config/agentsview/dump-inserts.sql`が`information_schema`と`quote_ident`／`quote_literal`から「INSERT文を返すSELECT」を作り、`psql`の`\gexec`で実行する。同じfileをremote（`agentsview:cockroach:dump:remote`）とlocal（`agentsview:cockroach:dump:local`）の両方が読むので、出力の形も一致する。

- 列名を明示するので、AgentsViewが列を増やしても古いdumpをそのまま取り込める。
- 値は`col::text`を文字列literalにしたもので、挿入先の列型へcoerceされる（`pg_dump --column-inserts`と同じ往復）。
- tableの順はforeign keyに従い、参照される側を先に出す。辺は`pg_catalog.pg_constraint`から取る。PostgreSQLの`information_schema.table_constraints`はSELECT以外の権限を持つtableしか返さないため、read-only roleでdumpすると辺が見えないからである。自己参照と循環はtableの順序では解けないので、その分はbest effortである。
- 生成列（`GENERATED ALWAYS AS ... STORED`）は列一覧から外す。値を指定したINSERTは`cannot insert a non-DEFAULT value`でrestoreが止まるためである。外した結果dumpできる列が1つも残らないtable（全列が生成列、列が無い）があれば、dumpは`has no dumpable column`で止まる。markerはschemaのtableを数えるので、黙って落とすとrowだけ失われたdumpが成功扱いになる。
- identity列（`GENERATED ALWAYS AS IDENTITY`）にも値を入れる。AgentsViewの`id`はこの形で、idは他tableから参照されうるため採番し直すわけにはいかない。SQL標準の`OVERRIDING SYSTEM VALUE`は**付けない**。CockroachDBが解釈せず`at or near "overriding": syntax error`になるためである。代わりに取り込み側が、取り込み前にlocalのidentity列を`BY DEFAULT`へ緩める（下記）。
- `psql`には`FETCH_COUNT`を渡してcursorで受け取る。これが無いと生成したINSERT文を全件client memoryへ溜めるため、session本文を含む大きなtableでpsqlが落ちる。件数は`AGENTSVIEW_DUMP_FETCH_ROWS`（既定1000）で変えられ、`0`はcursorを使わない指定である（cursorを扱えないengineに当たったときの逃げ道）。psqlが一度に持つ量は「件数×1行の大きさ」なので、session本文が極端に大きいschemaでは件数を下げる（PostgreSQL 16で183MBのtableを流したときのpsqlのmaxRSSは、`0`で192MiB、`1000`で100MiB、`200`で27MiBだった）。
- dumpの進捗は`AGENTSVIEW_DUMP_PROGRESS_SECONDS`（既定15秒、`0`で無効＝完了行も出さない、指定できるのは0.1秒以上）ごとにstderrへ出る。`psql`は書き出し中なにも言わないため、経過時間・行数・書き出したbyte数を別threadで報告する。`0 lines`のままなら、dumpの行をまだ1つも受け取っていない。進捗は`psql`の接続と並行して動くので、DNS・TCP・TLS・最初のqueryのどこで待っていても`0 lines`になる。接続とTLSの成否は`psql`のstderrで見る。取り込み側は`AGENTSVIEW_IMPORT_PROGRESS_ROWS`（既定2000件、`0`で無効）ごとに件数を出す。
- remote dumpはsession単位の差分にできる。`sessions`は起点より後に更新されたrow、`session_id`を持つtable（`messages`・`tool_calls`・`tool_result_events`・`usage_events`・`secret_findings`）はその範囲のsessionに属するrowだけを出す。それ以外のtable（`model_pricing`・`sync_metadata`・identity snapshot系）は全件で、AgentsViewでは合計1万行弱なので絞らない。取り込みが`ON CONFLICT DO NOTHING`である以上、localに既にあるrowを送っても捨てられるだけなので、差分にしても結果は変わらない。
- 差分をsession単位にしているのは、`tool_calls`のように時刻列を持たないtableがあり、再parseで古い`timestamp`のrowが後から増えることもあるためである。親が入れば子は必ず揃い、foreign keyの順序も崩れない。
- 起点は**machineごと**に決める。`agentsview:cockroach:merge`が`localdb.sh since`を呼び、localが持っている各machineの`max(sessions.updated_at)`から`AGENTSVIEW_DUMP_SINCE_OVERLAP`（既定`7 days`）だけ戻した時刻の並びを受け取って、`AGENTSVIEW_DUMP_SINCE_BY_MACHINE`として渡す。形は`('mac', '2026-09-06 12:00:00+00'), ('mini', '2026-08-25 09:00:00+00')`である。戻すのは、machine間の時計ずれと、少し前に更新されたsessionが後から現れるぶんを吸収するためである。localがまだ空なら全件になる。
- machineごとに分けるのは、起点が1つだと取りこぼすからである。毎日pushしている自分のmachineの更新がlocalの`max`になるので、起点を1つにすると別machineのそれより古いsessionは毎回「起点より古い」と判定され、永久に送られない。machineごとなら、localに1行も無いmachineは起点を持たず全件の対象になり、localが遅れているmachineはそのmachineの遅れた起点が使われる。
- 同じmachineの、localの最後の更新より古いままのremote sessionは送られない。そこまで取り直すには`AGENTSVIEW_DUMP_SINCE=all`を使う。
- 並びは文字列ではなくSQLとして（`VALUES`の中身として）remoteへ渡る。machine名のescapeはlocal DBの`quote_literal`が行い、名前に改行やtabを含むmachineは並びから外す（起点を持たないので全件の対象になる。取りこぼす側には倒れない）。`agentsview:cockroach:dump:remote`は`psql`へ渡す前に、その出力らしい形かを文字種で確かめ、外れていれば全件dumpへ倒す。
- `agentsview:cockroach:dump:remote`を単体で実行した場合は全件である（backupを作る用途）。人が指定する`AGENTSVIEW_DUMP_SINCE`には`all`（全件）、`30d`（今から30日前）、時刻の文字列を渡せる。こちらを指定した場合は単一の起点として扱われ、machineごとの起点より優先される。
- dump fileは所有者だけが読める（0600）。dumpにはsession本文が入るためである。`umask`は新しく作るfileにしか効かないので、既にあるpathへ書く場合に備えて、dumpを作るtaskが書く前に`chmod`し、bytesを書く`dump-progress`も開いたdescriptorへ`fchmod`する。
- schema DDLは持ち出さない。schemaは常に現在のAgentsViewが作る。

dumpの最後には完了markerが付く。

```text
-- agentsview-dump-complete tables=2
```

schema名を間違えた場合や、roleにtableのSELECT権限が無い場合、`information_schema`が権限でfilterされるため、生成側はerrorではなく「行が無い」という結果になる。markerが無い（途中で切れた）、あるいは`tables=0`のdumpは、`agentsview:cockroach:dump:remote`とimport filter（`dot_config/agentsview/scripts/batch-insert-dump.py`）の両方がerrorにして、空のbackupを残さない。

markerを持たないdumpのうち、`SET`や`setval`のような非INSERT statementを含むものは、以前のplain `pg_dump`形式のbackupとみなして取り込む（新しいdumpの出力はINSERTだけなので区別できる）。この経路ではtable数の確認ができないため、filterは注意書きを出す。

ただし受け入れるのは`--column-inserts`で作ったdump（dataがINSERTで書かれているもの）だけである。`pg_dump`の既定は`COPY ... FROM stdin`でdataを書き、そのdataはSQL statementではないので、このfilterのparserからは「非INSERT statement」にしか見えない。そのまま通すと0行を取り込んで成功したように見えるため、`COPY ... FROM stdin`を見つけた時点でerrorにして止める（`--column-inserts`で作り直すよう表示する）。

markerより後にSQLがあるdump、markerが2つあるdumpはerrorにする。dumpを連結した場合に、どこまでが完全なdumpなのか分からないままrowを取り込んでしまうためである。markerの後のcommentと空行は許す。

dump周りのregressionは`mise run test:agentsview`で走る（`dot_config/agentsview/tests/`）。取り込みの経路はfilter1つなので、statement分割・切り詰めの検出・marker・旧形式の受け入れを入力と期待のtableで押さえてある（`batch-insert-dump_test.py`）。remote URIをURLと`.pgpass`へ分ける側も、passwordがURLへ残らないこと・`sslrootcert`のpathを別fileへ出すこと・`system`を渡さないことを同じ形で確かめる（`prepare-dump-auth_test.py`）。

`ON CONFLICT DO NOTHING`が付いていないINSERT（旧形式のbackupにありうる）は、filterが付け直してから流す。VALUESの閉じ括弧で終わるstatementにだけ付けるので、既にconflict句があるものは触らない。既存句の判定は改行やcommentを跨いで行う（`ON\nCONFLICT`や`ON /* c */ CONFLICT`もSQLとしては正しい）。付ける位置は最後の閉じ括弧の直後で、末尾のcommentはそのまま後ろに残す（末尾へ付けると句と`;`が行commentの中に入る）。形が読めずに付けられなかった場合は、件数を警告に出す（そのdumpは再実行でduplicate keyになりうる）。

生成dumpのINSERTは末尾が必ず`ON CONFLICT DO NOTHING;`なので、その形は末尾だけを見て素通しする。この判定を入れないと、statement全体をmaskした文字列をさらに2度大文字化して走査することになる（PostgreSQL 16で32MiBの値を1行流したとき、1.54秒から0.30秒に下がった）。peakのmemoryは変わらない。そちらを決めているのは、literal／commentをmaskした並びをstatementと同じ長さで持つparserの作り（1 statement分で、dumpの大きさには比例しない）である。

#### localをCockroachDBに揃える理由と制約

| 項目       | local（`compose.yaml`）                            | remote（CockroachDB Cloud Basic）         |
| ---------- | -------------------------------------------------- | ----------------------------------------- |
| engine     | `cockroachdb/cockroach`のsingle-node               | Basic cluster（複数node）                 |
| 認証       | `--insecure`（TLSなし・passwordなし、`root`接続）  | `sslmode=verify-full`＋role別password     |
| port       | `127.0.0.1:26257`（DB consoleは`127.0.0.1:18080`） | 公開SQL endpointの`26257`                 |
| schema作成 | `agentsview pg push`（`root`）                     | `agentsview pg push`（`agentsview_push`） |
| vector     | 使わない（`--no-vectors`）                         | 使わない（`--no-vectors`）                |

localをPostgreSQLにしていると、取り込みのたびにDDL・sequence・型・transaction semanticsの差を迂回する必要があり、「remoteで動くがlocalで再現できない」状態が生まれる。engineを揃えると、AgentsViewのmigrationとqueryがlocalでも本番と同じcode pathを通り、remoteのdumpをそのまま取り込める。

代償として、localでもpgvectorが無くなる。`agentsview:cockroach:push:local`は常に`--no-vectors`を付け、semantic／hybrid searchは`501 Not Available`になる（remoteと同じ制約）。vector searchをlocalで試したい場合だけ、別途PostgreSQLを立てて`AGENTSVIEW_PG_URL`を手で指定する。

versionは`compose.yaml`の`image` tagで固定し、renovateが更新する。Basic clusterは自動upgradeされるため、localと厳密に一致はしない。差が問題になったときは両者を見比べる。

```sh
# local側のversion（machineごとのsession数も出る）
mise run agentsview:cockroach:status

# remote側のversion
fnox exec -- sh -c 'psql "$AGENTSVIEW_COCKROACH_READ_PG_URL" -Atc "SELECT version()"'
```

#### 切り替え後の確認

localのengineが変わるため、各PCで初回だけ次を順に確認する。上から順に実行し、失敗したところで止める。

1. `mise run agentsview:cockroach:push:local` — containerがhealthyになって`agentsview` databaseができ、AgentsViewのmigrationがCockroachDB上でschemaとtableを作る（PostgreSQL専用のindexやvectorを要求して失敗しないこと）。containerの起動はどのtaskでも自動なので、起動だけのtaskは置いていない
2. `mise run agentsview:cockroach:status` — engine versionと、machineごとのsession数が出る
3. `fnox exec -- mise run agentsview:cockroach:merge` — remoteのrowが取り込まれ、tableごとの増分が出る。続けてもう一度実行すると増分が`+0 rows`になる（冪等）
4. `mise run agentsview:cockroach:dump:local` → `bash ~/.config/agentsview/scripts/localdb.sh restore` — 作ったdumpを選び直して取り込めること（`+0 rows`になる）
5. `mise run agentsview:serve` — localのviewerでsession一覧とdetailが見える。semantic／hybrid searchは`501 Not Available`で正しい

1でcontainerが即`exited (1)`になる場合は、taskが自動で出すcontainer logを読む。CockroachDB imageのentrypointは`start-single-node`に渡せるflagを制限しており、`--listen-addr`のhostが`127.0.0.1`／`localhost`以外だとそこで止まる。

sequence補正はrestore／importの中で自動的に走るので、taskは置いていない。単体で実行しても副作用はない（sequenceを持たないschemaでは何もしない）。

```sh
bash ~/.config/agentsview/scripts/localdb.sh repair-sequences
```

### 5. Cloud Run secretとserviceを作成

初回はCloud Run URLがまだないため、config作成用に一時URLを指定する。ServiceはclrndがKnative manifestから作る。

```sh
export GCP_PROJECT_ID='<project-id>'
export GCP_REGION='us-west2'
export GCP_RUNTIME_SERVICE_ACCOUNT="agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
export AGENTSVIEW_CLOUD_RUN_URL='https://invalid.example'

fnox exec -- mise run agentsview:cloudrun:secrets
mise run agentsview:cloudrun:deploy
```

clrndが作るserviceはprivateなので、infraリポジトリ側でTerraformの`allUsers`のinvoker bindingをapplyする（2回目以降は差分なし）。

実URLを取得し、config secretを更新して新revisionを作る。

```sh
export AGENTSVIEW_CLOUD_RUN_URL=$(
  gcloud run services describe ryo-agentsview \
    --project="$GCP_PROJECT_ID" --region="$GCP_REGION" \
    --format='value(status.url)'
)
fnox exec -- mise run agentsview:cloudrun:secrets
AGENTSVIEW_SKIP_BUILD=1 mise run agentsview:cloudrun:deploy
```

Cloud Runでは次のようにsecretを注入する。どちらもmanifestには参照だけを書き、値はSecret Managerに残る。

- `AGENTSVIEW_PG_URL`: `agentsview-pg-url`のnumeric versionを環境変数として参照
- `/etc/agentsview/config.toml`: `agentsview-config-toml`のnumeric versionをread-only secret volumeとしてmountし、起動時に`$AGENTSVIEW_DATA_DIR`へcopyする（data dirは書き込み可能でなければならない）

versionは`latest`ではなく番号で固定する。Cloud Runはsecret参照をinstance起動時に解決するため、`latest`では同じrevisionのinstance同士が別の値を読み、rollbackしても当時の値を再現できない。deploy scriptが最新のENABLED versionを引いてrevisionへ焼き込むので、**新versionを追加しただけでは動作中のrevisionは切り替わらない。** 反映するのは`deploy`であり、`refresh`（liveの定義をそのまま再適用する）ではない。

infraリポジトリが管理するTerraformのinvoker bindingはCloud Run URLへの到達だけを許可する。AgentsView自身の`require_auth=true`とbearer tokenは維持する。

### 6. Cloud Runを検証

```sh
mise run agentsview:cloudrun:status

url=$(gcloud run services describe ryo-agentsview \
  --project="$GCP_PROJECT_ID" --region="$GCP_REGION" \
  --format='value(status.url)')

curl -i "$url/api/v1/sessions"                    # 401を期待
fnox exec -- sh -c 'curl -fsS -H "Authorization: Bearer $AGENTSVIEW_AUTH_TOKEN" \
  "'"$url"'/api/v1/sessions" >/dev/null'
curl -I "$url"                                    # UI応答を確認
```

`clrnd status`はReady条件、latest ready revision、traffic split、URLを表示する。`mise run agentsview:cloudrun:diff`が空であれば、live serviceとmanifestが一致している。

Google Cloud Consoleで次も確認する。

- `min instances = 0`、`max instances = 2`
- memory 512 MiB、CPU 1、request-based billing
- runtime service accountが`agentsview-runtime`
- secretの値がlogへ出ていない
- CockroachDB RU、storage、connection数が無料枠内

## 運用: インフラ設定を変更したあとの適用手順

**この構成に自動適用は無い。** `.github/workflows/`に残るのはAtuinのFly.io deployだけで、Cloud RunもTerraformもCIからは触らない。したがってこのdotfilesリポジトリのPRをmainへmergeしても、Google Cloud側は何も変わらない。**mergeは「変更が承認された」だけを意味し、適用はoperatorが手で行う。** `terraform/agentsview`はこのリポジトリには無い。基盤のTerraform変更は[`ryo246912/infra`](https://github.com/ryo246912/infra)リポジトリ側のPRで管理し、適用手順もそちらのrunbookに従う。

適用は変更したfileによって経路が違う。まず次で判断する。

| 変更したfile                                  | 適用に必要なこと                                                                  |
| --------------------------------------------- | --------------------------------------------------------------------------------- |
| `dot_config/agentsview/cloudrun-service.yaml` | `chezmoi apply` → `agentsview:cloudrun:deploy`（新revisionが作られる）            |
| `dot_config/agentsview/Dockerfile`            | 同上。image tagが変わるため**再buildが要る**（`AGENTSVIEW_SKIP_BUILD`は使えない） |
| `dot_config/agentsview/clrnd.yml`             | `chezmoi apply` のみ（次回のclrnd実行から反映）                                   |
| `dot_config/mise/tasks/agentsview.toml`       | `chezmoi apply` のみ                                                              |
| `dot_config/mise/config.toml`（tool version） | `chezmoi apply` → `mise install`                                                  |
| infraリポジトリの`*.tf`                       | infraリポジトリ側で`terraform plan` → 内容確認 → `terraform apply`                |

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

このリポジトリにTerraformコードは無い。基盤の変更は[`ryo246912/infra`](https://github.com/ryo246912/infra)リポジトリ側のPRで行い、`terraform plan`／`apply`もそちらのrunbookに従って実行する。**planに`destroy`が含まれていたら、その1件ずつを説明できるまでapplyしない。** とくにCloud Run serviceがdestroy対象に出た場合は、clrndが所有するserviceをTerraformが消そうとしている可能性が高い。そのままapplyしてはいけない。

`tftui`（`mise`でinstall済み）を使うとplanの中身をtree表示で追える。infraリポジトリ側で次を実行する。

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

infraリポジトリのTerraformとこのリポジトリのmanifestを両方変える場合、**権限を足す変更はinfraリポジトリのTerraform applyが先、権限を外す変更はCloud Run側が先**である。runtime service accountに新しいsecretへのaccessorを足してからそのsecretを参照するmanifestをdeployしないと、revisionは起動時にsecretを解決できずに失敗する。逆に参照をやめる場合は、先にmanifestから外してからIAMを削る。

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
