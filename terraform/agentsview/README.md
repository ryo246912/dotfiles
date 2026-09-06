# AgentsView infrastructure

This root manages the production CockroachDB Basic cluster, SQL users,
Artifact Registry, Secret Manager containers/IAM, runtime service account, and
Cloud Run service. Secret **versions** stay outside Terraform so connection URLs
and bearer tokens are not persisted in state. The CockroachDB provider's SQL
user resource only supports its sensitive `password` attribute, so the three SQL
user passwords are stored in the encrypted, access-controlled GCS state.

Do not download or commit state, and restrict access to the state bucket.

See [`../../docs/agentsview.md`](../../docs/agentsview.md)
for bootstrap, credentials, GitHub Actions, migration, and rollback steps.

Resources are split by provider and service: `gcp_*.tf` contains Google Cloud
APIs, Artifact Registry, Cloud Run, IAM, Secret Manager, and Workload Identity;
`cockroach_*.tf` contains the cluster, database, and SQL users. This is only a
file-layout change—Terraform resource addresses and state are unchanged.
