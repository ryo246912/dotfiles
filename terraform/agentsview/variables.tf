variable "gcp_project_id" {
  description = "AgentsViewのresourceを持つGoogle Cloud project。"
  type        = string
}

variable "cockroach_cluster_name" {
  description = "CockroachDB Cloud Basic clusterの名前。"
  type        = string
  default     = "ryo-agentsview"
}

variable "cockroach_database_name" {
  description = "AgentsView schemaを置くdatabase。"
  type        = string
  default     = "agentsview"
}

variable "cockroach_owner_password" {
  description = "migrationを行うowner roleのpassword。Terraform stateへsensitiveとして保存される。"
  type        = string
  sensitive   = true
}

variable "cockroach_push_password" {
  description = "各PCの pg push が使うroleのpassword。Terraform stateへsensitiveとして保存される。"
  type        = string
  sensitive   = true
}

variable "cockroach_read_password" {
  description = "Cloud Runのread-only viewerが使うroleのpassword。Terraform stateへsensitiveとして保存される。"
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "Cloud Runへdeployできるrepository。`owner/name`形式で、Workload Identity Federationのattribute conditionとprincipalSet bindingの両方で使う。"
  type        = string
  default     = "ryo246912/dotfiles"
}

variable "github_deploy_ref" {
  description = "deployを許可するbranch名。ここに一致するbranchのworkflowだけがaccess tokenを取得できる。"
  type        = string
  default     = "main"
}
