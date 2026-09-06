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
AGENTSVIEW_CLOUD_RUN_REGION="${AGENTSVIEW_CLOUD_RUN_REGION:-us-west2}"
# Fixed, not configurable: clrnd requires metadata.name in the manifest, the
# service in clrnd.yml, and the deployed service to be the same name.
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
