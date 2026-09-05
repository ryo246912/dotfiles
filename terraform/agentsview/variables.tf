variable "gcp_project_id" {
  description = "Google Cloud project that owns AgentsView resources."
  type        = string
}

variable "gcp_region" {
  description = "Cloud Run and Artifact Registry region."
  type        = string
  default     = "us-west2"
}

variable "agentsview_image" {
  description = "Immutable Artifact Registry image URI deployed to Cloud Run."
  type        = string
}

variable "pg_url_secret_version" {
  description = "Numeric Secret Manager version containing the read-only CockroachDB URL."
  type        = string
  default     = "latest"
}

variable "config_secret_version" {
  description = "Numeric Secret Manager version containing the AgentsView config.toml."
  type        = string
  default     = "latest"
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name."
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

variable "cockroach_region" {
  description = "CockroachDB GCP region near Cloud Run."
  type        = string
  default     = "us-west2"
}

variable "cockroach_database_name" {
  description = "Database containing the AgentsView schema."
  type        = string
  default     = "agentsview"
}

variable "cockroach_owner_password" {
  description = "Write-only password for the migration owner."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "cockroach_push_password" {
  description = "Write-only password for local pg push clients."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "cockroach_read_password" {
  description = "Write-only password for the Cloud Run read-only viewer."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "cockroach_password_version" {
  description = "Increment together with all three password rotations."
  type        = number
  default     = 1
}
