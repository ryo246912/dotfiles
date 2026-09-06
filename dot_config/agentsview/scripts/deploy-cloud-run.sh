#!/usr/bin/env bash
set -euo pipefail

# Build the pinned upstream image into Artifact Registry, then let clrnd apply
# the Cloud Run service definition. Terraform is not involved in an app deploy:
# it owns the surrounding project resources, clrnd owns the service.
#
# Set AGENTSVIEW_SKIP_BUILD=1 to redeploy a tag that was already built. Extra
# arguments are passed to `clrnd deploy` (CI needs --auto-approve).

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./cloudrun-env.sh
. "${script_dir}/cloudrun-env.sh"

for command in gcloud; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

if [ "${AGENTSVIEW_SKIP_BUILD:-0}" != "1" ]; then
  gcloud builds submit "$AGENTSVIEW_CONFIG_DIR" \
    --project="$GCP_PROJECT_ID" \
    --tag="$AGENTSVIEW_IMAGE"
fi

# verify checks the manifest locally and confirms the service account, secret
# versions, and image it references exist before anything is applied.
bash "${script_dir}/clrnd.sh" verify

# deploy shows the diff, waits for the new revision to serve, and exits non-zero
# when the rollout fails. Secret values stay in Secret Manager, so neither the
# diff nor the deploy output can leak them.
bash "${script_dir}/clrnd.sh" deploy "$@"

gcloud run services describe "$AGENTSVIEW_CLOUD_RUN_SERVICE" \
  --project="$GCP_PROJECT_ID" \
  --region="$AGENTSVIEW_CLOUD_RUN_REGION" \
  --format='value(status.url)'
