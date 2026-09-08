# CockroachDB Cloudが作るSQL userは初期状態でadmin roleに属する。最小権限は
# providerでは表現できないため、作成後に `mise run agentsview:cockroach:configure-roles`
# でadminをREVOKEし、role別のGRANTを設定する。
resource "cockroach_sql_user" "owner" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = "agentsview_owner"
  password   = var.cockroach_owner_password
}

resource "cockroach_sql_user" "push" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = "agentsview_push"
  password   = var.cockroach_push_password
}

resource "cockroach_sql_user" "read" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = "agentsview_read"
  password   = var.cockroach_read_password
}
