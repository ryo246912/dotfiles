resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = "agentsview-runtime"
  display_name = "AgentsView Cloud Run runtime"
}

resource "google_service_account" "deploy" {
  project      = var.gcp_project_id
  account_id   = "agentsview-deploy"
  display_name = "AgentsView GitHub Actions deploy"
}

locals {
  deploy_project_roles = toset([
    "roles/artifactregistry.admin",
    "roles/cloudbuild.builds.editor",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
  ])
}

resource "google_project_iam_member" "deploy" {
  for_each = local.deploy_project_roles

  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_service_account_iam_member" "deploy_uses_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy.email}"
}
