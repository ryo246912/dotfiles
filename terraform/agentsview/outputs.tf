output "artifact_registry_repository" {
  value = google_artifact_registry_repository.agentsview.name
}

# service URLはclrnd（`clrnd status`）かgcloudから取る。Cloud Run serviceは
# Terraformの管理外だからである。名前とregionだけをここから出し、deploy scriptと
# Terraformが同じ場所を指していることを保証する。
output "cloud_run_service_name" {
  value = local.cloud_run_service_name
}

output "cloud_run_region" {
  value = local.region
}

output "cockroach_cluster_id" {
  value = cockroach_cluster.agentsview.id
}

output "cockroach_database" {
  value = cockroach_database.agentsview.name
}

output "cockroach_sql_host" {
  value = one(cockroach_cluster.agentsview.regions).sql_dns
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}

output "secret_names" {
  value = {
    config = google_secret_manager_secret.config.secret_id
    pg_url = google_secret_manager_secret.pg_url.secret_id
  }
}
