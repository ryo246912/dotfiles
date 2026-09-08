resource "google_artifact_registry_repository" "agentsview" {
  project       = var.gcp_project_id
  location      = local.region
  repository_id = "agentsview"
  description   = "AgentsView Cloud Run images"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

# Cloud Runのrevisionがimageをpullするために必要。
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

# `gcloud builds submit` が使うidentityは、projectの作成時期とpolicyによって
# 旧Cloud Build用とCompute Engine既定のどちらになるか変わる。どちらでもbuild結果を
# push できるよう両方へ権限を付ける。
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  for_each = local.cloud_build_service_accounts

  project    = var.gcp_project_id
  location   = google_artifact_registry_repository.agentsview.location
  repository = google_artifact_registry_repository.agentsview.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${each.value}"
}
