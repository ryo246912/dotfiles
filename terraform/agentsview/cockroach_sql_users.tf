resource "cockroach_sql_user" "owner" {
  cluster_id          = cockroach_cluster.agentsview.id
  name                = "agentsview_owner"
  password_wo         = var.cockroach_owner_password
  password_wo_version = var.cockroach_password_version
}

resource "cockroach_sql_user" "push" {
  cluster_id          = cockroach_cluster.agentsview.id
  name                = "agentsview_push"
  password_wo         = var.cockroach_push_password
  password_wo_version = var.cockroach_password_version
}

resource "cockroach_sql_user" "read" {
  cluster_id          = cockroach_cluster.agentsview.id
  name                = "agentsview_read"
  password_wo         = var.cockroach_read_password
  password_wo_version = var.cockroach_password_version
}
