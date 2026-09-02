output "artifact_registry_repository" {
  value = google_artifact_registry_repository.agentsview.name
}

output "cloud_run_service_url" {
  value = google_cloud_run_v2_service.agentsview.uri
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

output "deploy_service_account" {
  value = google_service_account.deploy.email
}

output "github_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "secret_names" {
  value = {
    config = google_secret_manager_secret.config.secret_id
    pg_url = google_secret_manager_secret.pg_url.secret_id
  }
}
