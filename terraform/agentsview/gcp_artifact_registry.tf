resource "google_artifact_registry_repository" "agentsview" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = "agentsview"
  description   = "AgentsView Cloud Run images"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

resource "google_artifact_registry_repository_iam_member" "runtime_reader" {
  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

locals {
  cloud_build_service_accounts = toset([
    "${data.google_project.current.number}@cloudbuild.gserviceaccount.com",
    "${data.google_project.current.number}-compute@developer.gserviceaccount.com",
  ])
}

# Google Cloud projects can use either the legacy Cloud Build identity or the
# Compute Engine default identity for builds, depending on project age/policy.
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  for_each = local.cloud_build_service_accounts

  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${each.value}"
}

resource "google_artifact_registry_repository_iam_member" "deploy_writer" {
  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deploy.email}"
}
