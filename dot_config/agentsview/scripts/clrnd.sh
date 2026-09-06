#!/usr/bin/env bash
set -euo pipefail

# Run a clrnd subcommand against the AgentsView Cloud Run service with the
# manifest, config, and template environment it needs.
#
#   bash dot_config/agentsview/scripts/clrnd.sh diff
#   bash dot_config/agentsview/scripts/clrnd.sh deploy --auto-approve
#   bash dot_config/agentsview/scripts/clrnd.sh rollback

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=./cloudrun-env.sh
. "${script_dir}/cloudrun-env.sh"

for command in clrnd; do
  command -v "$command" >/dev/null || {
    echo "Missing required command: $command (run: mise install)" >&2
    exit 1
  }
done

# verify, render, diff and deploy expand the manifest, so they need the numeric
# secret versions. status, revisions, rollback and traffic read the live service
# and do not, which keeps a Secret Manager lookup off those paths.
case "${1:-}" in
  verify | render | diff | deploy)
    agentsview_export_secret_versions
    ;;
esac

exec clrnd "$@" --config "${AGENTSVIEW_CONFIG_DIR}/clrnd.yml"
