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
# mise dotfiles apply済みの ~/.config/agentsview を使う。
config_dir="${AGENTSVIEW_CONFIG_DIR:-config/agentsview}"
if [ ! -f "${config_dir}/clrnd.yml" ]; then
  config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/agentsview"
fi
if [ ! -f "${config_dir}/clrnd.yml" ]; then
  echo "clrnd.yml が見つかりません: ${config_dir}" >&2
  exit 1
fi

# apply済みの ~/.config/agentsview を使う場合、dotfiles source を更新しただけでは
# ここのmanifestは古いままである。image tagのdirty判定は AGENTSVIEW_IMAGE を明示
# すると走らないため、それに頼ると古いmanifestが黙ってdeployされる。manifestを
# 読むmodeでは必ず検査して止める。
# ["~/.config" = {source = "config", mode = "copy"}] なので、deploy先の
# ~/.config/agentsview のsourceは常に $DOTFILES_DIR/config/agentsview に決まる
# （chezmoi source-path 相当の動的解決は不要）。
dotfiles_source_dir() {
  dotfiles_dir="${DOTFILES_DIR:-$HOME/dotfiles}"
  [ -f "$dotfiles_dir/mise.toml" ] || return 1
  printf '%s' "$dotfiles_dir/config/agentsview"
}

check_config_current() {
  [ "${AGENTSVIEW_SKIP_CONFIG_CHECK:-0}" = "1" ] && return 0
  # source treeから直接実行している場合はapplyの概念がない。
  git -C "$config_dir" rev-parse --show-toplevel >/dev/null 2>&1 && return 0

  source_dir=$(dotfiles_source_dir) || return 0
  [ -d "$source_dir" ] || return 0

  pending=$(diff -rq "$source_dir" "$config_dir" 2>/dev/null || true)
  [ -z "$pending" ] && return 0

  echo "${config_dir} が ${source_dir} と一致していません:" >&2
  printf '%s\n' "$pending" >&2
  echo "mise bootstrap dotfiles apply を実行してから再度deployしてください。" >&2
  echo "（意図的に古いmanifestを使う場合のみ AGENTSVIEW_SKIP_CONFIG_CHECK=1）" >&2
  exit 1
}

# clrnd.ymlにproject IDを書かないため、projectとregionはここから解決させる。
export CLOUDSDK_CORE_PROJECT="$GCP_PROJECT_ID"
export CLOUDSDK_RUN_REGION="$region"

# manifestが must_env で読む値。未設定ならrender時にerrorになる。
export GCP_RUNTIME_SERVICE_ACCOUNT="${GCP_RUNTIME_SERVICE_ACCOUNT:-agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com}"

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

  # commitはbuild contextを持つgit worktreeから取る。mise dotfiles apply済みの
  # ~/.config/agentsview から実行した場合、そこはworktreeではないので
  # DOTFILES_DIR側のpathを引く。
  source_dir=""
  if git -C "$config_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
    source_dir="$config_dir"
  else
    source_dir=$(dotfiles_source_dir) || true
  fi

  commit="${GITHUB_SHA:-}"
  if [ -z "$commit" ] && [ -n "$source_dir" ]; then
    commit=$(git -C "$source_dir" rev-parse HEAD 2>/dev/null || true)
  fi
  if [ -z "$commit" ]; then
    echo "commitを特定できません（DOTFILES_DIRもgit worktreeも見つかりません）。AGENTSVIEW_IMAGEを指定してください" >&2
    exit 1
  fi
  commit=$(printf '%s' "$commit" | cut -c1-12)

  # tagがbuildする内容を表さない状態を -dirty として残す。deployは止めない。
  # 1) source側に未commitの変更がある
  # 2) apply済みのbuild contextがDOTFILES_DIR側と一致していない
  dirty=""
  if [ -n "$source_dir" ]; then
    dirty=$(git -C "$source_dir" status --porcelain -- . 2>/dev/null || true)
  fi
  if [ -z "$dirty" ] && [ "$source_dir" != "$config_dir" ] && [ -n "$source_dir" ]; then
    dirty=$(diff -rq "$source_dir" "$config_dir" 2>/dev/null || true)
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

# version一覧には secretmanager.versions.list が要る。Terraformがdeploy service
# accountへ与えているのは secretVersionAdder だけなので、CIのようにその identity で
# 実行する場合はversionを追加できても一覧はできない。その構成では、secretを登録した
# 手順が返した番号をそのまま環境変数で渡す。
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
