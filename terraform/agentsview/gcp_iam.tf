# Cloud Runのrevisionが名乗るidentity。Secret Managerの2つのsecretを読み、
# Artifact Registryからimageをpullできる。deployはできない。
resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = "agentsview-runtime"
  display_name = "AgentsView Cloud Run runtime"

  depends_on = [google_project_service.required]
}

# GitHub ActionsがCloud Runへdeployするためのidentity。
#
# service account keyのJSONは作らない。GitHubのOIDC tokenをWorkload Identity
# Federationで交換し、短命なaccess tokenだけをworkflowへ渡す。repositoryへ置く
# secretはprovider名・service account email・project IDの3つで、いずれも鍵ではない。
#
# .github/workflows/deploy-agentsview.yaml がこのidentityを使う。

resource "google_service_account" "deploy" {
  project      = var.gcp_project_id
  account_id   = "agentsview-deploy"
  display_name = "AgentsView GitHub Actions deploy"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.gcp_project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "GitHub ActionsのOIDC tokenを受け入れるpool"

  depends_on = [google_project_service.required]
}

# attribute_conditionはtoken交換そのものを絞る。repositoryとbranchを両方見るため、
# fork・pull request・他branchからのworkflowはaccess tokenを取得できない。
# `attribute.repository`はSA側のprincipalSet bindingが参照する。
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions OIDC"

  attribute_condition = "assertion.repository == '${local.github_repository}' && assertion.ref == 'refs/heads/${local.github_deploy_ref}' && assertion.ref_type == 'branch'"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "deploy_workload_identity" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repository}"
}

# clrnd deployが必要とするのは run.services.get／update／create。roles/run.developer
# がその範囲で、IAM policyは触れない（公開用のinvoker bindingはTerraformが持つ）。
resource "google_project_iam_member" "deploy_run" {
  project = var.gcp_project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# Cloud Runはrevisionが名乗るservice accountに対してactAsを要求する。deploy
# identityへ与えるのはruntime service accountに限った1件だけで、projectレベルの
# serviceAccountUserは与えない。
resource "google_service_account_iam_member" "deploy_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy.email}"
}

# `gcloud builds submit` でimageをbuildする。buildが走るidentityは
# gcp_artifact_registry.tf の local.cloud_build_service_accounts 側であり、
# ここで与えるのはbuildを投入する権限だけ。
resource "google_project_iam_member" "deploy_cloud_build" {
  project = var.gcp_project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# clrnd verifyはmanifestが指すimageの実在を artifactregistry.tags.get ／
# artifactregistry.dockerimages.get で確認する。deploy前の検証に必要。
resource "google_artifact_registry_repository_iam_member" "deploy_reader" {
  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.deploy.email}"
}

# deploy scriptはrevisionへ焼き込むsecret versionを解決するために
# secretmanager.versions.list を使う。roles/secretmanager.viewer はmetadataだけの
# roleなので、この identity はsecretの値を読めない（読めるのはruntimeだけ）。
resource "google_secret_manager_secret_iam_member" "deploy_pg_url_viewer" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.pg_url.secret_id
  role      = "roles/secretmanager.viewer"
  member    = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_secret_manager_secret_iam_member" "deploy_config_viewer" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.config.secret_id
  role      = "roles/secretmanager.viewer"
  member    = "serviceAccount:${google_service_account.deploy.email}"
}
