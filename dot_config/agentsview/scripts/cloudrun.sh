#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?GCP_PROJECT_IDを設定してください}"

mode="${1:?deploy／verify／diff などのmodeを指定してください}"
shift

# region と service 名は固定。clrnd.yml、manifestの metadata.name、Terraformの
# local.region ／ local.cloud_run_service_name と一致している必要があり、ここだけ
# 上書きできるとbuild先・IAM付与先・deploy先がずれる。
region="us-west2"
service="ryo-agentsview"

# repository rootから実行した場合はsource treeのmanifestを、それ以外では
# chezmoi apply済みの ~/.config/agentsview を使う。
config_dir="${AGENTSVIEW_CONFIG_DIR:-dot_config/agentsview}"
if [ ! -f "${config_dir}/clrnd.yml" ]; then
  config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/agentsview"
fi
if [ ! -f "${config_dir}/clrnd.yml" ]; then
  echo "clrnd.yml が見つかりません: ${config_dir}" >&2
  exit 1
fi

# apply済みの ~/.config/agentsview を使う場合、chezmoi sourceを更新しただけでは
# ここのmanifestは古いままである。image tagのdirty判定は AGENTSVIEW_IMAGE を明示
# すると走らないため、それに頼ると古いmanifestが黙ってdeployされる。manifestを
# 読むmodeでは必ず検査して止める。
check_config_current() {
  [ "${AGENTSVIEW_SKIP_CONFIG_CHECK:-0}" = "1" ] && return 0
  # source treeから直接実行している場合はapplyの概念がない。
  git -C "$config_dir" rev-parse --show-toplevel >/dev/null 2>&1 && return 0
  command -v chezmoi >/dev/null || return 0

  pending=$(chezmoi status "$config_dir" 2>/dev/null || true)
  [ -z "$pending" ] && return 0

  echo "${config_dir} がchezmoi sourceと一致していません:" >&2
  printf '%s\n' "$pending" >&2
  echo "chezmoi apply ${config_dir} を実行してから再度deployしてください。" >&2
  echo "（意図的に古いmanifestを使う場合のみ AGENTSVIEW_SKIP_CONFIG_CHECK=1）" >&2
  exit 1
}

# clrnd.ymlにproject IDを書かないため、projectとregionはここから解決させる。
export CLOUDSDK_CORE_PROJECT="$GCP_PROJECT_ID"
export CLOUDSDK_RUN_REGION="$region"

# manifestが must_env で読む値。未設定ならrender時にerrorになる。
export GCP_RUNTIME_SERVICE_ACCOUNT="${GCP_RUNTIME_SERVICE_ACCOUNT:-agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com}"

# Cloud Runはserviceへ2種類のURLを割り当てる。hash入りのnon-deterministic URLと、
# service名・project number・regionだけで決まるdeterministic URLである。後者は
# serviceを作る前から確定し、deleteして作り直しても同じ値へ戻るので、AgentsViewの
# config.tomlのpublic_urlはこちらへ固定する。Terraformの output cloud_run_url と
# 同じ値を、Terraform stateを読まずに組み立てる。
# exitではなくreturnで失敗を返す。この関数は $(...) で呼ばれるため、exitでは
# subshellが終わるだけで呼び出し元は止まらない。
project_number() {
  number="${GCP_PROJECT_NUMBER:-}"

  if [ -z "$number" ]; then
    command -v gcloud >/dev/null || {
      echo "gcloudが必要です（またはGCP_PROJECT_NUMBERを指定してください）" >&2
      return 1
    }
    number=$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)') || {
      echo "project numberを取得できません: ${GCP_PROJECT_ID}" >&2
      return 1
    }
  fi

  # GCP_PROJECT_NUMBERで渡された値もgcloudの出力と同じ検査にかける。数字以外が
  # 混じったままhost名へ入ると、URLとしては成立するのに誰も居ない先を指す。
  case "$number" in
    '' | *[!0-9]*)
      echo "project numberが数字ではありません: ${number}" >&2
      return 1
      ;;
  esac

  printf '%s' "$number"
}

# 上のURLを組み立てて標準出力へ出す。serviceの存在は問わない。
# project_numberを $(...) のままprintfの引数へ埋めると、失敗しても printf 自体は
# 成功するため set -e が働かず、"https://ryo-agentsview-.us-west2.run.app" のような
# URLをexit 0で出してしまう。一度変数へ受けて失敗を明示的に伝播させる。
deterministic_url() {
  number=$(project_number) || return 1
  printf 'https://%s-%s.%s.run.app' "$service" "$number" "$region"
}

# --check用。deterministic URLがliveなserviceのURLと一致するか確かめる。
# serviceが未作成のNOT_FOUNDだけは正常系として扱う。認証・権限・API無効といった
# 他のerrorまで握り潰すと、何も確認できていないのに確認済みとして通してしまう。
check_live_url() {
  expected="$1"
  err_file=$(mktemp)
  live=""
  status=0
  live=$(gcloud run services describe "$service" \
    --project="$GCP_PROJECT_ID" \
    --region="$region" \
    --format='value(status.url)' 2>"$err_file") || status=$?
  err=$(cat "$err_file")
  rm -f "$err_file"

  if [ "$status" -ne 0 ]; then
    case "$err" in
      *NOT_FOUND* | *"could not be found"* | *"does not exist"*)
        # serviceをまだ作っていない。突き合わせる相手が居ないだけなので通す。
        return 0
        ;;
    esac
    printf '%s\n' "$err" >&2
    echo "Cloud Run serviceの状態を確認できませんでした。--checkは失敗として扱います。" >&2
    return "$status"
  fi

  if [ -n "$live" ] && [ "$live" != "$expected" ]; then
    echo "警告: Cloud Runが報告するURLがdeterministic URLと一致しません" >&2
    echo "  live:          ${live}" >&2
    echo "  deterministic: ${expected}" >&2
    echo "どちらも同じserviceへ届くが、public_urlにはdeterministic URLを使うこと。" >&2
  fi
}

# imageのtagは commit で固定する。upstream versionだけをtagにすると同じtagを
# buildのたびに上書きすることになり、同じURIが時期によって別のartifactを指す。
# tagは <upstream version>-<commit> の形にして、Cloud Run consoleからAgentsView
# のversionとdotfilesのcommitの両方を辿れるようにする。
# imageを読むmode（build／verify／render／diff／deploy）でだけ解決する。
export_image() {
  if [ -n "${AGENTSVIEW_IMAGE:-}" ]; then
    export AGENTSVIEW_IMAGE
    return
  fi

  upstream_version=$(sed -n 's#^FROM .*:\([^:[:space:]]*\)[[:space:]]*$#\1#p' "${config_dir}/Dockerfile" | head -n 1)
  : "${upstream_version:?${config_dir}/Dockerfile からupstream versionを読み取れません}"

  # commitはbuild contextを持つgit worktreeから取る。chezmoi apply済みの
  # ~/.config/agentsview から実行した場合、そこはworktreeではないので
  # chezmoi source側のpathを引く。
  source_dir=""
  if git -C "$config_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    source_dir="$config_dir"
  elif command -v chezmoi >/dev/null; then
    source_dir=$(chezmoi source-path "$config_dir" 2>/dev/null || true)
  fi

  commit="${GITHUB_SHA:-}"
  if [ -z "$commit" ] && [ -n "$source_dir" ]; then
    commit=$(git -C "$source_dir" rev-parse HEAD 2>/dev/null || true)
  fi
  if [ -z "$commit" ]; then
    echo "commitを特定できません（chezmoi sourceもgit worktreeも見つかりません）。AGENTSVIEW_IMAGEを指定してください" >&2
    exit 1
  fi
  commit=$(printf '%s' "$commit" | cut -c1-12)

  # tagがbuildする内容を表さない状態を -dirty として残す。deployは止めない。
  # 1) source側に未commitの変更がある
  # 2) apply済みのbuild contextがchezmoi sourceと一致していない
  dirty=""
  if [ -n "$source_dir" ]; then
    dirty=$(git -C "$source_dir" status --porcelain -- . 2>/dev/null || true)
  fi
  if [ -z "$dirty" ] && [ "$source_dir" != "$config_dir" ] && command -v chezmoi >/dev/null; then
    dirty=$(chezmoi status "$config_dir" 2>/dev/null || true)
  fi
  if [ -n "$dirty" ]; then
    echo "警告: build contextがcommitと一致していません。tagへ -dirty を付けます" >&2
    commit="${commit}-dirty"
  fi

  export AGENTSVIEW_IMAGE="${region}-docker.pkg.dev/${GCP_PROJECT_ID}/agentsview/agentsview:${upstream_version}-${commit}"
}

newest_secret_version() {
  gcloud secrets versions list "$1" \
    --project="$GCP_PROJECT_ID" \
    --filter='state=ENABLED' \
    --sort-by='~createTime' \
    --limit=1 \
    --format='value(name)' | sed 's#.*/##'
}

# Secret Managerのversionは1から始まるので、それ以外（特に latest）は指定ミス。
require_version_number() {
  case "$2" in
    '' | *[!0-9]* | 0*)
      echo "$1 にはSecret Managerのversion番号を指定してください: $2" >&2
      exit 1
      ;;
  esac
}

# version一覧には secretmanager.versions.list が要る。Terraformはdeploy service
# accountへ2つのsecretに限って roles/secretmanager.viewer を与えているので、CIでも
# 引ける（metadataだけのroleなので値は読めない）。この権限を持たないidentityで
# 実行する場合は、secretを登録した手順が返した番号をそのまま環境変数で渡す。
secret_version_lookup_failed() {
  echo "Secret Managerのversionを一覧できません。" >&2
  echo "identityに secretmanager.versions.list（例: roles/secretmanager.viewer）を付けるか、" >&2
  echo "AGENTSVIEW_PG_URL_SECRET_VERSION と AGENTSVIEW_CONFIG_SECRET_VERSION にversion番号を指定してください。" >&2
  exit 1
}

# Cloud Runはsecret参照をinstance起動時に解決するため、latestのままだと同じ
# revisionのinstance同士が別の値を読み、rollbackしても当時の値を再現できない。
# manifestをrenderするmodeでだけ最新のENABLED versionを引き、revisionへ焼き込む。
export_secret_versions() {
  if [ -z "${AGENTSVIEW_PG_URL_SECRET_VERSION:-}" ] || [ -z "${AGENTSVIEW_CONFIG_SECRET_VERSION:-}" ]; then
    command -v gcloud >/dev/null || {
      echo "gcloudが必要です（またはAGENTSVIEW_PG_URL_SECRET_VERSIONとAGENTSVIEW_CONFIG_SECRET_VERSIONを指定してください）" >&2
      exit 1
    }
  fi

  if [ -z "${AGENTSVIEW_PG_URL_SECRET_VERSION:-}" ]; then
    AGENTSVIEW_PG_URL_SECRET_VERSION=$(newest_secret_version agentsview-pg-url) || secret_version_lookup_failed
  fi
  if [ -z "${AGENTSVIEW_CONFIG_SECRET_VERSION:-}" ]; then
    AGENTSVIEW_CONFIG_SECRET_VERSION=$(newest_secret_version agentsview-config-toml) || secret_version_lookup_failed
  fi

  require_version_number AGENTSVIEW_PG_URL_SECRET_VERSION "$AGENTSVIEW_PG_URL_SECRET_VERSION"
  require_version_number AGENTSVIEW_CONFIG_SECRET_VERSION "$AGENTSVIEW_CONFIG_SECRET_VERSION"

  export AGENTSVIEW_PG_URL_SECRET_VERSION AGENTSVIEW_CONFIG_SECRET_VERSION
}

run_clrnd() {
  command -v clrnd >/dev/null || {
    echo "clrndが見つかりません。mise install を実行してください" >&2
    exit 1
  }
  clrnd "$@" --config "${config_dir}/clrnd.yml"
}

build_image() {
  command -v gcloud >/dev/null || {
    echo "gcloudが必要です" >&2
    exit 1
  }
  gcloud builds submit "$config_dir" \
    --project="$GCP_PROJECT_ID" \
    --tag="$AGENTSVIEW_IMAGE" >&2
}

case "$mode" in
  build)
    check_config_current
    export_image
    build_image
    printf '%s\n' "$AGENTSVIEW_IMAGE"
    ;;
  deploy)
    check_config_current
    export_image

    # verifyとdeployで同じversionをpinするため、ここで一度だけ解決する。
    # 別々に引くと、その間に追加されたversionが未検証のままdeployされる。
    export_secret_versions

    # AGENTSVIEW_SKIP_BUILD=1 でbuild済みtagの再deployだけを行う。
    if [ "${AGENTSVIEW_SKIP_BUILD:-0}" != "1" ]; then
      build_image
    fi

    # verifyはmanifestをlocalで検証し、参照するservice account、secret version、
    # imageの実在をAPIで確認する。
    run_clrnd verify

    # deployは差分を表示し、新revisionがReadyになるまで待ち、rollout失敗時に
    # non-zeroで終了する。secret値はSecret Managerに残るのでlogへ出ない。
    run_clrnd deploy "$@"

    gcloud run services describe "$service" \
      --project="$GCP_PROJECT_ID" \
      --region="$region" \
      --format='value(status.url)'
    ;;
  url)
    # serviceが存在しない段階でも動く。--checkを付けたときだけ、liveなserviceが
    # 報告するURLと突き合わせる。
    target=$(deterministic_url) || exit 1
    if [ "${1:-}" = "--check" ]; then
      check_live_url "$target"
    fi
    printf '%s\n' "$target"
    ;;
  verify | render | diff)
    check_config_current
    export_image
    export_secret_versions
    run_clrnd "$mode" "$@"
    ;;
  *)
    # status／revisions／rollback／traffic はmanifestをrenderしないため、
    # imageもsecret versionも解決しない（git管理外からも実行できる）。
    run_clrnd "$mode" "$@"
    ;;
esac
