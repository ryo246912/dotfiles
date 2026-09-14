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

# cockroach_sql_user.{owner,push,read}はpasswordを意図的に持たない。
# 理由と実際のpassword設定方法はterraform/agentsview/cockroach_sql_users.tfの
# コメントを参照。
