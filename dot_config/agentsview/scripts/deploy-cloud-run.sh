#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID}"
: "${GCP_RUNTIME_SERVICE_ACCOUNT:?Set GCP_RUNTIME_SERVICE_ACCOUNT}"

region="${GCP_REGION:-us-west2}"
service="${AGENTSVIEW_CLOUD_RUN_SERVICE:-ryo-agentsview}"
image="${region}-docker.pkg.dev/${GCP_PROJECT_ID}/agentsview/agentsview:0.38.1"

for command in gcloud; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

# Build from the pinned upstream image in Dockerfile, then deploy a bounded,
# scale-to-zero service. Secret values remain in Secret Manager and are never
# passed as literal command-line values.
gcloud builds submit dot_config/agentsview \
  --project="$GCP_PROJECT_ID" \
  --tag="$image"

gcloud run deploy "$service" \
  --project="$GCP_PROJECT_ID" \
  --region="$region" \
  --image="$image" \
  --service-account="$GCP_RUNTIME_SERVICE_ACCOUNT" \
  --env-vars-file=dot_config/agentsview/cloudrun.env.yaml \
  --update-secrets=AGENTSVIEW_PG_URL=agentsview-pg-url:latest,/data/config.toml=agentsview-config-toml:latest \
  --port=8080 \
  --cpu=1 \
  --memory=512Mi \
  --concurrency=20 \
  --min=0 \
  --max=2 \
  --timeout=60 \
  --cpu-throttling \
  --allow-unauthenticated \
  --quiet

gcloud run services describe "$service" \
  --project="$GCP_PROJECT_ID" \
  --region="$region" \
  --format='value(status.url)'
