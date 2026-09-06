# AgentsView infrastructure

This root manages the production CockroachDB Basic cluster, SQL users, Artifact
Registry, Secret Manager containers/IAM, service accounts, GitHub Workload
Identity, and the Cloud Run public invoker binding. Secret **versions** stay
outside Terraform so connection URLs and bearer tokens are not persisted in
state.

The Cloud Run **service definition** is not managed here. `clrnd` owns it, from
`dot_config/agentsview/cloudrun-service.yaml`, the way ecspresso owns an ECS
service next to Terraform. One owner per resource: Terraform never reverts a
deploy, and a failed revision cannot force a Terraform replacement. The invoker
binding is the exception because clrnd does not manage IAM; it addresses the
service by name and region, so it depends on no Cloud Run state, and it can only
be applied after one `clrnd deploy` has created the service.

The CockroachDB provider's SQL user resource only supports its sensitive
`password` attribute, so the three SQL user passwords are stored in the
encrypted, access-controlled GCS state.

Do not download or commit state, and restrict access to the state bucket.

See [`../../docs/agentsview.md`](../../docs/agentsview.md)
for bootstrap, credentials, GitHub Actions, migration, and rollback steps.

Resources are split by provider and service: `gcp_*.tf` contains Google Cloud
APIs, Artifact Registry, Cloud Run IAM, IAM, Secret Manager, and Workload
Identity; `cockroach_*.tf` contains the cluster, database, and SQL users. This is
only a file-layout change—Terraform resource addresses and state are unchanged.
