# AgentsView infrastructure

This root manages the production CockroachDB Basic cluster, SQL users,
Artifact Registry, Secret Manager containers/IAM, runtime service account, and
Cloud Run service. Secret **versions** stay outside Terraform so connection URLs
and bearer tokens are not persisted in state.

Terraform 1.11+ is required because CockroachDB SQL user passwords use the
write-only `password_wo` attribute.

See [`../../docs/agentsview-cloud-run-migration.md`](../../docs/agentsview-cloud-run-migration.md)
for bootstrap, credentials, GitHub Actions, migration, and rollback steps.

Resources are split by provider and service: `gcp_*.tf` contains Google Cloud
APIs, Artifact Registry, Cloud Run, IAM, Secret Manager, and Workload Identity;
`cockroach_*.tf` contains the cluster, database, and SQL users. This is only a
file-layout change—Terraform resource addresses and state are unchanged.
