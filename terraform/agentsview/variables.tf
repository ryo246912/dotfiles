variable "gcp_project_id" {
  description = "Google Cloud project that owns AgentsView resources."
  type        = string
}

# The image URI and the Secret Manager versions the service reads live in the
# clrnd manifest, not here. Terraform only needs the service name to attach the
# public invoker binding.
variable "cloud_run_service_name" {
  description = "Cloud Run service name. Must match metadata.name in the clrnd manifest."
  type        = string
  default     = "ryo-agentsview"
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to impersonate the deploy service account."
  type        = string
  default     = "ryo246912/dotfiles"
}

variable "github_wif_pool_id" {
  description = "Project-wide Workload Identity Pool ID used by GitHub Actions."
  type        = string
  default     = "github"
}

variable "cockroach_cluster_name" {
  description = "CockroachDB Cloud Basic cluster name."
  type        = string
  default     = "ryo-agentsview"
}

variable "cockroach_database_name" {
  description = "Database containing the AgentsView schema."
  type        = string
  default     = "agentsview"
}

variable "cockroach_owner_password" {
  description = "Password for the migration owner. Stored as a sensitive value in Terraform state."
  type        = string
  sensitive   = true
}

variable "cockroach_push_password" {
  description = "Password for local pg push clients. Stored as a sensitive value in Terraform state."
  type        = string
  sensitive   = true
}

variable "cockroach_read_password" {
  description = "Password for the Cloud Run read-only viewer. Stored as a sensitive value in Terraform state."
  type        = string
  sensitive   = true
}
