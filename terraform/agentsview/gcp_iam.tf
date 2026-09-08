resource "google_service_account" "runtime" {
  project      = var.gcp_project_id
  account_id   = "agentsview-runtime"
  display_name = "AgentsView Cloud Run runtime"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "deploy" {
  project      = var.gcp_project_id
  account_id   = "agentsview-deploy"
  display_name = "AgentsView GitHub Actions deploy"

  depends_on = [google_project_service.required]
}

# IAM, WIF, API enablement, and project policy remain operator-managed. CI gets
# only the permissions required to start builds, update Cloud Run, and consume
# enabled services; it cannot rewrite project IAM or administer secrets.
locals {
  deploy_project_roles = toset([
    "roles/cloudbuild.builds.editor",
    "roles/run.admin",
    "roles/serviceusage.serviceUsageConsumer",
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
