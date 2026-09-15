resource "cockroach_database" "agentsview" {
  cluster_id = cockroach_cluster.agentsview.id
  name       = var.cockroach_database_name
}
