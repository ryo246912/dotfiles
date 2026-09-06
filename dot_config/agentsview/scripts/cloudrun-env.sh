#!/usr/bin/env bash
# Shared environment for the AgentsView Cloud Run deployment scripts.
# Source this file; it is not meant to be executed on its own.
#
# Terraform owns the runtime service account, Artifact Registry, the Secret
# Manager containers and their IAM, and the allUsers invoker binding. clrnd owns
# the Cloud Run service definition, its revisions, and the traffic split.

: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"

AGENTSVIEW_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
AGENTSVIEW_CONFIG_DIR=$(cd -- "${AGENTSVIEW_SCRIPT_DIR}/.." && pwd)
# Both are fixed rather than overridable, because each is written down in more
# than one place: the region in clrnd.yml and Terraform's local.region, the name
# in the manifest's metadata.name, clrnd.yml, and local.cloud_run_service_name.
# An override here would build and query one service while clrnd deploys another.
AGENTSVIEW_CLOUD_RUN_REGION="us-west2"
AGENTSVIEW_CLOUD_RUN_SERVICE="ryo-agentsview"

# clrnd falls back to these when clrnd.yml does not set project/region, which is
# why no account identifier is committed to that file.
export CLOUDSDK_CORE_PROJECT="$GCP_PROJECT_ID"
export CLOUDSDK_RUN_REGION="$AGENTSVIEW_CLOUD_RUN_REGION"

# The manifest reads both of these through must_env, so an unset value fails at
# render time instead of deploying a half-configured revision.
export GCP_RUNTIME_SERVICE_ACCOUNT="${GCP_RUNTIME_SERVICE_ACCOUNT:-agentsview-runtime@${GCP_PROJECT_ID}.iam.gserviceaccount.com}"

if [ -z "${AGENTSVIEW_IMAGE:-}" ]; then
  # Default to the upstream version pinned in the Dockerfile so the deployed tag
  # cannot drift from the image that is built. CI sets AGENTSVIEW_IMAGE to an
  # immutable commit-SHA tag instead.
  agentsview_image_tag=$(sed -n 's#^FROM .*:\([^:[:space:]]*\)[[:space:]]*$#\1#p' \
    "${AGENTSVIEW_CONFIG_DIR}/Dockerfile" | head -n 1)
  : "${agentsview_image_tag:?Could not read an image tag from ${AGENTSVIEW_CONFIG_DIR}/Dockerfile}"
  AGENTSVIEW_IMAGE="${AGENTSVIEW_CLOUD_RUN_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/agentsview/agentsview:${agentsview_image_tag}"
fi
export AGENTSVIEW_IMAGE

# Secret versions are pinned to a number, never "latest". Cloud Run resolves a
# secret reference per instance at startup, so "latest" can hand two instances of
# the same revision different values while a version is being added, and a
# rollback would read today's value instead of the one the old revision ran with.
# The newest ENABLED version is resolved at render time and baked into the
# revision; set AGENTSVIEW_PG_URL_SECRET_VERSION / AGENTSVIEW_CONFIG_SECRET_VERSION
# to deploy an older one deliberately.
agentsview_newest_secret_version() {
  gcloud secrets versions list "$1" \
    --project="$GCP_PROJECT_ID" \
    --filter='state=ENABLED' \
    --sort-by='~createTime' \
    --limit=1 \
    --format='value(name)' | sed 's#.*/##'
}

# Secret Manager numbers versions from 1, so anything else - "latest" above all -
# is a mistake rather than a version.
agentsview_require_version_number() {
  case "$2" in
    '' | *[!0-9]* | 0*)
      echo "$1 must be a Secret Manager version number, got: $2" >&2
      exit 1
      ;;
  esac
}

# Only the subcommands that render the manifest need these, so the lookup stays
# out of the read-only paths (status, revisions, rollback).
agentsview_export_secret_versions() {
  if [ -z "${AGENTSVIEW_PG_URL_SECRET_VERSION:-}" ] || [ -z "${AGENTSVIEW_CONFIG_SECRET_VERSION:-}" ]; then
    command -v gcloud >/dev/null || {
      echo "Missing required command: gcloud (or set AGENTSVIEW_PG_URL_SECRET_VERSION and AGENTSVIEW_CONFIG_SECRET_VERSION)" >&2
      exit 1
    }
  fi

  if [ -z "${AGENTSVIEW_PG_URL_SECRET_VERSION:-}" ]; then
    AGENTSVIEW_PG_URL_SECRET_VERSION=$(agentsview_newest_secret_version agentsview-pg-url)
  fi
  if [ -z "${AGENTSVIEW_CONFIG_SECRET_VERSION:-}" ]; then
    AGENTSVIEW_CONFIG_SECRET_VERSION=$(agentsview_newest_secret_version agentsview-config-toml)
  fi

  : "${AGENTSVIEW_PG_URL_SECRET_VERSION:?No enabled version of agentsview-pg-url. Run: mise run agentsview:cloudrun:secrets}"
  : "${AGENTSVIEW_CONFIG_SECRET_VERSION:?No enabled version of agentsview-config-toml. Run: mise run agentsview:cloudrun:secrets}"

  # An explicitly set value goes into the manifest as written, so "latest" here
  # would quietly undo the pinning this function exists for.
  agentsview_require_version_number AGENTSVIEW_PG_URL_SECRET_VERSION "$AGENTSVIEW_PG_URL_SECRET_VERSION"
  agentsview_require_version_number AGENTSVIEW_CONFIG_SECRET_VERSION "$AGENTSVIEW_CONFIG_SECRET_VERSION"

  export AGENTSVIEW_PG_URL_SECRET_VERSION AGENTSVIEW_CONFIG_SECRET_VERSION
}
