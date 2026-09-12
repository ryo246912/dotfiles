output "artifact_registry_repository" {
  value = google_artifact_registry_repository.agentsview.name
}

# Cloud Run serviceそのものはTerraformの管理外（clrndが所有する）なので、名前と
# regionだけをここから出し、deploy scriptとTerraformが同じ場所を指していることを
# 保証する。稼働中のrevisionやtraffic splitは `clrnd status` から見る。
output "cloud_run_service_name" {
  value = local.cloud_run_service_name
}

output "cloud_run_region" {
  value = local.region
}

# Cloud Runのdeterministic URL。service作成前から確定し、serviceを作り直しても
# 同じ値へ戻る。`agentsview:cloudrun:secrets` が書くconfig.tomlのpublic_urlは
# これと同じ値で、`mise run agentsview:cloudrun:url` もこれを組み立てる。
output "cloud_run_url" {
  value = local.cloud_run_url
}

output "gcp_project_number" {
  value = data.google_project.current.number
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

# GitHub repositoryのActions secretへ登録する値。どちらも鍵ではない。
# GCP_DEPLOY_SERVICE_ACCOUNT / GCP_WORKLOAD_IDENTITY_PROVIDER として使う。
output "github_actions_deploy_service_account" {
  value = google_service_account.deploy.email
}

output "github_actions_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}
